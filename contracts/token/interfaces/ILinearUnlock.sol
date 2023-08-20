
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILinearUnlock {
    struct User {
        address userAddress; // Purely for ensuring the mapping is to the right address
        uint256 claimed; // How much the user has already claimed (SCALED)
        uint256 claimable; // How much the user is entitled to claim over the vesting period (SCALED)
        uint256 lastClaimedTimestamp; // The last time the user has claimed
        uint256 endVestTimestamp; // End of vesting timestamp, allows for users to have various length vest schedules
    }
}