// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Utils} from "./Utils.sol";
import "../../../contracts/ERC20AntiMEV/ERC20AntiMEV.sol";
import "../../../contracts/token/LinearUnlock.sol";
import "../../../contracts/token/interfaces/ILinearUnlock.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LinearUnlockTest is Test, ILinearUnlock {
    using SafeMath for uint256;

    Utils internal utils;

    address payable[] internal users;
    address internal owner;

    ERC20AntiMEV public erc20;
    LinearUnlock public linearUnlock;

    function setUp() public {
        utils = new Utils();
        users = utils.createUsers(10);
        owner = users[0];
        vm.label(owner, "Owner");
        vm.prank(owner);
    }

    function testBasicLifecycle() public {
        vm.startPrank(owner);
        erc20 = new ERC20AntiMEV(10 ether, "token");
        skip(1);

        User[] memory testUsers = new User[](10);

        for (uint256 i = 0; i < users.length; i++) {
            User memory testUser;
            testUser.userAddress = users[i];
            testUser.claimed = 0;
            testUser.claimable = 1 ether;
            testUser.lastClaimedTimestamp = 0;
            testUser.endVestTimestamp = block.timestamp + 10;
            testUsers[i] = testUser;
        }

        linearUnlock = new LinearUnlock(address(erc20), block.timestamp);
        erc20.setExcused(address(linearUnlock), true);
        erc20.approve(address(linearUnlock), 10 ether);
        linearUnlock.addUsers(testUsers);

        uint256 balanceAfter = erc20.balanceOf(address(linearUnlock));
        assertEq(10 ether, balanceAfter);
        skip(10);

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            linearUnlock.claim();
            uint256 balance = erc20.balanceOf(address(users[i]));
            (,,uint256 claimable,,) = linearUnlock.users(address(users[i]));
            assertEq(claimable.div(linearUnlock.SCALAR()), balance);
        }

        uint256 balanceUnlocker = erc20.balanceOf(address(linearUnlock));
        assertEq(0, balanceUnlocker);
        vm.stopPrank();
    }
}
