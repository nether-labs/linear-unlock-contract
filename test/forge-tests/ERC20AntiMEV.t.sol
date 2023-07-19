// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Utils} from "./Utils.sol";
import "../../contracts/ERC20AntiMEV.sol";

contract CounterTest is Test {
    Utils internal utils;

    address payable[] internal users;
    address internal owner;
    address internal ammPool;
    address internal victim;
    address internal attacker;
    address internal bystanderBuyer;
    address internal bystanderSeller;

    ERC20AntiMEV public erc20;

    function setUp() public {
        utils = new Utils();
        users = utils.createUsers(6);
        owner = users[0];
        vm.label(owner, "Owner");
        ammPool = users[1];
        vm.label(ammPool, "AMM Pool");
        victim = users[2];
        vm.label(victim, "Victim");
        attacker = users[3];
        vm.label(attacker, "Attacker");
        bystanderBuyer = users[4];
        vm.label(bystanderBuyer, "Bystander Buyer");
        bystanderSeller = users[5];
        vm.label(bystanderSeller, "Bystander Seller");

        vm.prank(owner);
        erc20 = new ERC20AntiMEV(10000, "token");
        skip(1);
    }

    function testBasicBuySandwichBlock() public {
        // Initial Setup and excusing the amm pool and sending the pool initial liquidity
        vm.startPrank(owner);
        erc20.setExcused(ammPool, true);
        erc20.transfer(ammPool, 10000);

        //Setting the stage; bystander seller already has tokens, vict
        vm.startPrank(ammPool);
        erc20.transfer(bystanderSeller, 100);

        //Skip timestamp ahead
        skip(1);

        //Set caller to amm pool
        vm.startPrank(ammPool);
        erc20.transfer(attacker, 100); //Attackers frontrun transaction
        erc20.transfer(victim, 100); //Victims buy transaction

        //Set caller to attacker
        vm.startPrank(attacker);
        vm.expectRevert(); //Expect this to revert
        erc20.transfer(ammPool, 100); //Attacker sells to complete sandwich

        //Set caller to random bystander who wants to sell in the same block
        vm.startPrank(bystanderSeller);
        erc20.transfer(ammPool, 100); //Bystander sells in same block

        //Set caller to amm pool
        vm.startPrank(ammPool);
        erc20.transfer(bystanderBuyer, 100); //Bystander 2 buys in the same block

        vm.stopPrank();
    }

    function testBasicSellSandwichBlock() public {
        // Initial Setup and excusing the amm pool and sending the pool initial liquidity
        vm.startPrank(owner);
        erc20.setExcused(ammPool, true);
        erc20.transfer(ammPool, 10000);

        //Setting the stage; bystander seller, vitcim and attacker already have tokens, vict
        vm.startPrank(ammPool);
        erc20.transfer(bystanderSeller, 100);
        erc20.transfer(victim, 100);
        erc20.transfer(attacker, 100);

        //Skip timestamp ahead
        skip(1);

        //Set caller to attacker
        vm.startPrank(attacker);
        erc20.transfer(ammPool, 100); //Attackers frontrun transaction sell
        //Set caller to victim
        vm.startPrank(victim);
        erc20.transfer(ammPool, 100); //Victims sell transaction
        //Set caller to amm pool
        vm.startPrank(ammPool);
        vm.expectRevert(); //Expect this to revert
        erc20.transfer(attacker, 100); //Attacker buys to complete sandwich

        //Set caller to random bystander who wants to sell in the same block
        vm.startPrank(bystanderSeller);
        erc20.transfer(ammPool, 100); //Bystander sells in same block

        //Set caller to amm pool
        vm.startPrank(ammPool);
        erc20.transfer(bystanderBuyer, 100); //Bystander 2 buys in the same block

        vm.stopPrank();
    }
}
