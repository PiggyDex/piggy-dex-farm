// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPiggy} from "./IPiggy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPiggyDexV2Farm {
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

    function initialize(
        IPiggy _nativeToken,
        uint256 _TOKEN_PER_BLOCK,
        address _devAddr,
        IERC20 _firstLpToken,
        IERC20 _rewardToken,
        uint256 _rewardPerBlock
    ) external;

    function getBoostMultiplier(
        address _user,
        uint256 _pid
    ) external view returns (uint256);

    function add(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        IERC20 _lpToken,
        uint256 _allocPoint,
        bool _withUpdate
    ) external;

    function supply(
        uint256 _pid,
        uint256 _supplyAmount,
        bool _withUpdate
    ) external;

    function update(
        uint256 _pid,
        uint256 _rewardPerBlock,
        uint256 _allocPoint,
        bool _withUpdate
    ) external;

    function pendingReward(
        uint256 _pid,
        address _user
    ) external view returns (uint256);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external returns (PoolInfo memory pool);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function updateBoostMultiplier(
        address _user,
        uint256 _pid,
        uint256 _newMultiplier
    ) external;

    function emergencyWithdraw(uint256 _pid) external;

    function pendingCake(
        uint256 _pid,
        address _user
    ) external view returns (uint256);

    function userInfo(
        uint256 _pid,
        address _user
    ) external view returns (uint256, uint256, uint256);

    function poolInfo(
        uint256 _pid
    )
        external
        view
        returns (
            IERC20 rewardToken,
            uint256 rewardPerBlock,
            uint256 totalReward,
            IERC20 lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 totalBoostedShare,
            uint256 accRewardPerShare
        );
}
