// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPiggy} from "../interfaces/IPiggy.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PiggyDexV2Farm is OwnableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` Used to calculate the correct amount of rewards. See explanation below.
    ///
    /// We do some fancy math here. Basically, any point in time, the amount of Reward Tokens
    /// entitled to a user but is pending to be distributed is:
    ///
    ///   pending reward = (user share * pool.accCakePerShare) - user.rewardDebt
    ///
    ///   Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    ///   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
    ///   2. User receives the pending reward sent to his/her address.
    ///   3. User's `amount` gets updated. Pool's `totalBoostedShare` gets updated.
    ///   4. User's `rewardDebt` gets updated.
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
        uint256 boostMultiplier; // User's boost multiplier.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 rewardToken; // Address of reward token contract.
        uint256 rewardPerBlock; // Reward tokens per block.
        uint256 totalReward; // Total reward tokens.
        IERC20 lpToken; // Address of lp token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool
        uint256 lastRewardBlock; // Last block number that reward distribution occurs.
        uint256 totalBoostedShare;
        uint256 accRewardPerShare; // Accumulated reward per share.
    }

    IPiggy public nativeToken;
    uint256 public TOKEN_PER_BLOCK;
    uint256 constant ACC_REWARD_PRECISION = 1e18;
    /// @notice Basic boost factor, none boosted user's boost factor
    uint256 public constant BOOST_PRECISION = 100 * 1e10;
    uint256 public constant MAX_BOOST_PRECISION = 200 * 1e10;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // dev address
    address public devAddr;
    // reward claimable
    bool public claimable;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdateWorkingSupply(
        address indexed user,
        uint256 indexed pid,
        uint256 workingSupply
    );

    address public boostContract;

    modifier onlyBoostContract() {
        require(
            boostContract == msg.sender,
            "Ownable: caller is not the boost contract"
        );
        _;
    }

    function initialize(
        IPiggy _nativeToken,
        uint256 _TOKEN_PER_BLOCK,
        address _devAddr,
        IERC20 _firstLpToken,
        IERC20 _rewardToken,
        uint256 _rewardPerBlock
    ) external initializer {
        nativeToken = _nativeToken;
        TOKEN_PER_BLOCK = _TOKEN_PER_BLOCK;
        devAddr = _devAddr;
        claimable = true;
        poolInfo.push(
            PoolInfo({
                rewardToken: _rewardToken,
                rewardPerBlock: _rewardPerBlock,
                totalReward: 0,
                lpToken: _firstLpToken,
                allocPoint: 1000,
                lastRewardBlock: block.number,
                totalBoostedShare: 0,
                accRewardPerShare: 0
            })
        );
        __Ownable_init(msg.sender);
        totalAllocPoint = 1000;
    }

    /// @notice Get user boost multiplier for specific pool id.
    /// @param _user The user address.
    /// @param _pid The pool id.
    function getBoostMultiplier(
        address _user,
        uint256 _pid
    ) public view returns (uint256) {
        uint256 multiplier = userInfo[_pid][_user].boostMultiplier;
        return multiplier > BOOST_PRECISION ? multiplier : BOOST_PRECISION;
    }

    function add(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        IERC20 _lpToken,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner {
        require(_lpToken.balanceOf(address(this)) >= 0, "None ERC20 tokens");
        require(
            address(_lpToken) != address(nativeToken),
            "LP Token cannot be native token of Piggy"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint += _allocPoint;
        poolInfo.push(
            PoolInfo({
                rewardToken: _rewardToken,
                rewardPerBlock: _rewardPerBlock,
                totalReward: 0,
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: block.number,
                totalBoostedShare: 0,
                accRewardPerShare: 0
            })
        );
    }

    function supply(
        uint256 _pid,
        uint256 _supplyAmount,
        bool _withUpdate
    ) external {
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfo[_pid];
        pool.totalReward += _supplyAmount;
    }

    function update(
        uint256 _pid,
        uint256 _rewardPerBlock,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint -= poolInfo[_pid].allocPoint;
        poolInfo[_pid].rewardPerBlock = _rewardPerBlock;
        poolInfo[_pid].allocPoint = _allocPoint;
        totalAllocPoint += _allocPoint;
    }

    function pendingReward(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.totalBoostedShare;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 tokenReward;
            if (address(pool.rewardToken) != address(nativeToken)) {
                tokenReward = multiplier * pool.rewardPerBlock;
                if (tokenReward > pool.totalReward) {
                    tokenReward = pool.totalReward;
                }
            } else {
                tokenReward =
                    (multiplier * TOKEN_PER_BLOCK * pool.allocPoint) /
                    totalAllocPoint;
            }
            accRewardPerShare =
                accRewardPerShare +
                ((tokenReward * ACC_REWARD_PRECISION) / lpSupply);
        }
        uint256 boostedAmount = (user.amount *
            (getBoostMultiplier(_user, _pid))) / BOOST_PRECISION;
        return
            (boostedAmount * accRewardPerShare) /
            ACC_REWARD_PRECISION -
            user.rewardDebt;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo memory pool = poolInfo[pid];
            if (pool.allocPoint != 0) {
                updatePool(pid);
            }
        }
    }

    /// @notice Update reward variables for the given pool.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 _pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[_pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = pool.totalBoostedShare;
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 tokenReward;
            if (address(pool.rewardToken) != address(nativeToken)) {
                tokenReward = multiplier * pool.rewardPerBlock;
                if (tokenReward > pool.totalReward) {
                    tokenReward = pool.totalReward;
                }
                pool.totalReward -= tokenReward;
            } else {
                tokenReward =
                    (multiplier * TOKEN_PER_BLOCK * pool.allocPoint) /
                    totalAllocPoint;
            }

            pool.accRewardPerShare =
                pool.accRewardPerShare +
                ((tokenReward * ACC_REWARD_PRECISION) / lpSupply);
            pool.lastRewardBlock = block.number;
            poolInfo[_pid] = pool;
        }
    }

    /// @notice Settles, distribute the pending CAKE rewards for given user.
    /// @param _user The user address for settling rewards.
    /// @param _pid The pool id.
    /// @param _boostMultiplier The user boost multiplier in specific pool id.
    function settlePendingReward(
        address _user,
        uint256 _pid,
        uint256 _boostMultiplier
    ) internal {
        UserInfo memory user = userInfo[_pid][_user];
        PoolInfo storage pool = poolInfo[_pid];

        uint256 boostedAmount = (user.amount * _boostMultiplier) /
            BOOST_PRECISION;

        uint256 accReward = (boostedAmount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        uint256 pending = accReward - user.rewardDebt;
        pool.rewardToken.safeTransfer(_user, pending);
    }

    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 multiplier = getBoostMultiplier(msg.sender, _pid);
        if (user.amount > 0) {
            settlePendingReward(msg.sender, _pid, multiplier);
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            user.amount += _amount;
            pool.totalBoostedShare =
                pool.totalBoostedShare +
                ((_amount * multiplier) / BOOST_PRECISION);
        }
        user.rewardDebt =
            (((user.amount * multiplier) / BOOST_PRECISION) *
                pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        poolInfo[_pid] = pool;
    }

    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: insufficient balance");
        uint256 multiplier = getBoostMultiplier(msg.sender, _pid);
        settlePendingReward(msg.sender, _pid, multiplier);
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.safeTransfer(msg.sender, _amount);
        }
        user.rewardDebt =
            (((user.amount * multiplier) / BOOST_PRECISION) *
                pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;
        poolInfo[_pid].totalBoostedShare =
            poolInfo[_pid].totalBoostedShare -
            ((_amount * multiplier) / BOOST_PRECISION);
    }

    function updateBoostMultiplier(
        address _user,
        uint256 _pid,
        uint256 _newMultiplier
    ) external onlyBoostContract nonReentrant {
        require(
            _user != address(0),
            "MasterChefV2: The user address must be valid"
        );
        require(
            _newMultiplier >= BOOST_PRECISION &&
                _newMultiplier <= MAX_BOOST_PRECISION,
            "MasterChefV2: Invalid new boost multiplier"
        );

        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][_user];

        uint256 prevMultiplier = getBoostMultiplier(_user, _pid);
        settlePendingReward(_user, _pid, prevMultiplier);

        user.rewardDebt =
            (((user.amount * (_newMultiplier)) / (BOOST_PRECISION)) *
                (pool.accRewardPerShare)) /
            (ACC_REWARD_PRECISION);
        pool.totalBoostedShare =
            pool.totalBoostedShare -
            ((user.amount * (prevMultiplier)) / (BOOST_PRECISION)) +
            ((user.amount * (_newMultiplier)) / (BOOST_PRECISION));
        poolInfo[_pid] = pool;
        userInfo[_pid][_user].boostMultiplier = _newMultiplier;
    }

    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        uint256 boostedAmount = amount *
            (getBoostMultiplier(msg.sender, _pid)) *
            BOOST_PRECISION;
        pool.totalBoostedShare = pool.totalBoostedShare > boostedAmount
            ? pool.totalBoostedShare - boostedAmount
            : 0;

        // Note: transfer can fail or succeed if `amount` is zero.
        pool.lpToken.safeTransfer(msg.sender, amount);
    }

    function changeTokenPerBlock(uint256 _newTokenPerBlock) external onlyOwner {
        TOKEN_PER_BLOCK = _newTokenPerBlock;
    }

    function getAllPoolsLength() external view returns (uint256) {
        return poolInfo.length;
    }
}
