// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStakingPool {
    function totalLockedAmount() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function BOOST_WEIGHT() external view returns (uint256);
    function MAX_LOCK_DURATION() external view returns (uint256);
    function userInfo(
        address _user
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            uint256
        );
}
