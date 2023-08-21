// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/ILinearUnlock.sol";

contract LinearUnlock is Ownable, ILinearUnlock {
    /************************* Events **************************/
    // TODO, add appropriate events

    /******************** Config Variables *********************/
    using SafeMath for uint256;
    uint256 constant public SCALAR = 10 ** 6; // Acceptable level of precision for mathematics

    /******************** Public Variables *********************/
    address public tokenAddress; // Address of the ERC20 token
    uint256 public maxLockedTokens; // Maximum number of locked tokens (SCALED)
    uint256 public totalClaimedTokens; // Global total on how much has been claimed (SCALED)
    uint256 public startVestTimestamp; // Start of linear vesting schedule
    mapping(address => User) public users;

    /*********************** Constructor ************************/
    /**
     * @notice Unused, needed to deploy implementation
     */
    constructor(address _tokenAddress, uint256 _startVestTimestamp) {
        tokenAddress = _tokenAddress;
        startVestTimestamp = _startVestTimestamp;
    }

    /********************* Getter Functions *********************/
    /**
     * @notice Get the descaled amount of max locked tokens
     * @return uint256
     */
    function getLockedTokens() external view returns(uint256){
        return maxLockedTokens.div(SCALAR);
    }

    /**
     * @notice Get the descaled amount of claimed tokens
     * @return uint256
     */
    function getClaimedTokens() external view returns(uint256){
        return totalClaimedTokens.div(SCALAR);
    }

    /**
     * @notice Get the claimable amount of tokens for a user
     * @param _user User to be calculated
     * @return uint256
     */
    function getUserClaimable(address _user) external view returns (uint256){
        return _getUserClaimable(_user);
    }

    /********************* Setter Functions *********************/
    /**
     * @notice Allows users to claim their rightful amounts over their vesting schedule
     */
    function claim() external {
        require(block.timestamp > startVestTimestamp, "Cannot start before vest begins");
        require(block.timestamp > users[msg.sender].lastClaimedTimestamp, "Cannot claim in the same block");
        
        uint256 claimable = _getUserClaimable(msg.sender);

        totalClaimedTokens += claimable;
        users[msg.sender].claimed += claimable;
        users[msg.sender].lastClaimedTimestamp = block.timestamp;

        // Descaling is always done at the end to ensure maximum precision
        (bool success, ) = tokenAddress.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, claimable.div(SCALAR)));
        require(success, "Unable to transfer tokens");   
    }

    /**
     * @notice Adds users to the token vesting, users can have unique claimable amounts and length of unlock time
     * @param _users Users to be included in the token vesting
     */
    function addUsers(User[] memory _users) external onlyOwner {
        _addUsers(_users);
    }

    /**
     * @notice LOGIC - Adds users to the token vesting, users can have unique claimable amounts and length of unlock time
     * @param _users Users to be included in the token vesting
     */
    function _addUsers(User[] memory _users) internal {
        uint256 tokensToLock = 0;
        for (uint256 i = 0; i < _users.length; i++) {
            if (users[_users[i].userAddress].userAddress != _users[i].userAddress) {
                users[_users[i].userAddress] = _users[i];
                users[_users[i].userAddress].claimed = 0;
                users[_users[i].userAddress].claimable = _users[i].claimable.mul(SCALAR);
                users[_users[i].userAddress].lastClaimedTimestamp = 0;
                tokensToLock += _users[i].claimable; 
            } else {
                revert("A user already exists");
            }
        }

        // Requires the appropriate amount of tokens to be added to the token pool
        _lockTokens(tokensToLock);
    }

    /**
     * @notice Locks tokens into the claimable pool
     * @param _amount Amount of tokens to be locked
     */
    function _lockTokens(uint256 _amount) internal {
        maxLockedTokens += _amount.mul(SCALAR); // Applies scalar for precision
        (bool transferSuccess, ) = tokenAddress.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _amount));
        require(transferSuccess, "Cannot transfer ERC20");
    }

    /**
     * @notice Logic for calculating number of claimable tokens for the user
     * @param _user User address
     */
    function _getUserClaimable(address _user) internal view returns(uint256){
        uint256 currentTimestamp = block.timestamp > users[_user].endVestTimestamp ? users[_user].endVestTimestamp : block.timestamp;
        uint256 claimableNumerator = currentTimestamp.sub(startVestTimestamp);
        uint256 claimableDenominator = users[_user].endVestTimestamp.sub(startVestTimestamp);
        uint256 claimable = (users[_user].claimable.mul(claimableNumerator).div(claimableDenominator)).sub(users[_user].claimed);

        /* Checking for dust */
        uint256 remainingTokens = maxLockedTokens.sub(totalClaimedTokens);
        if(claimable > remainingTokens){
            claimable = remainingTokens;
        }

        return claimable;
    }
}
