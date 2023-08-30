// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Utils} from "./Utils.sol";
import "../../../contracts//ERC20AntiMEV/ERC20AntiMEV.sol";
import "../../../contracts/uniswap/uniswap-core/UniswapV2Factory.sol";
import "../../../contracts/uniswap/uniswap-periphery/UniswapV2Router02.sol";
import "../../../contracts/uniswap/uniswap-periphery/test/WETH9.sol";

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
    WETH9 public weth;
    UniswapV2Factory public uniswapFactory;
    UniswapV2Router02 public uniswapRouter;

    function setUp() public {
        utils = new Utils();
        uniswapFactory = new UniswapV2Factory(address(0));
        weth = new WETH9();
        uniswapRouter = new UniswapV2Router02(address(uniswapFactory), address(weth));

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
        erc20 = new ERC20AntiMEV(1000000 ether, "token");
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

    function testUniswapBuySandwich() public {
        /* Setup for this set of buy tests */
        vm.startPrank(owner);
        erc20.approve(address(uniswapRouter), 1000000 ether);
        uniswapRouter.addLiquidityETH{value: 100 ether}(address(erc20), 100000 ether, 0, 0, owner, 1 ether);
        erc20.setExcused(address(uniswapFactory.getPair(address(weth), address(erc20))), true);
        skip(1);
        erc20.transfer(bystanderSeller, 1 ether);
        skip(1);

        /******** BEGIN ATTACK ********/
        address[] memory t = new address[](2);

        // 1: Attacker has seen victim with high slippage in the mempool, sent the transaction of ETH for tokens with increased gas
        vm.startPrank(attacker);
        t[0] = address(weth);
        t[1] = address(erc20);
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(0, t, attacker, 1 ether);

        // 2: Unassuming victims ETH for tokens transaction continues, receives less tokens as a result
        vm.startPrank(victim);
        t[0] = address(weth);
        t[1] = address(erc20);
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(0, t, victim, 1 ether);
        
        // 3: Attacker sells their tokens for ETH and receives some measure of profit
        vm.startPrank(attacker);
        erc20.approve(address(uniswapRouter), 1000000 ether);
        t[0] = address(erc20);
        t[1] = address(weth);
        vm.expectRevert(); //Expect this to revert
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, t, attacker, 1 ether);

        /* Others interacting in the pool to test contract integrity - Ignore */
        vm.startPrank(bystanderSeller);
        erc20.approve(address(uniswapRouter), 1000000 ether);
        t[0] = address(erc20);
        t[1] = address(weth);
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, t, bystanderSeller, 1 ether);

        vm.startPrank(bystanderBuyer);
        t[0] = address(weth);
        t[1] = address(erc20);
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(0, t, bystanderBuyer, 1 ether);
    
        vm.stopPrank();
    }

    function testUniswapSellSandwich() public {
        /* Setup for this set of sell tests */
        vm.startPrank(owner);
        erc20.approve(address(uniswapRouter), 1000000 ether);
        uniswapRouter.addLiquidityETH{value: 100 ether}(address(erc20), 100000 ether, 0, 0, owner, 1 ether);
        erc20.setExcused(address(uniswapFactory.getPair(address(weth), address(erc20))), true);
        erc20.setExcused(owner, true);
        skip(1);
        erc20.transfer(bystanderSeller, 1 ether);
        erc20.transfer(attacker, 1 ether);
        erc20.transfer(victim, 1 ether);
        skip(1);

        /******** BEGIN ATTACK ********/
        address[] memory t = new address[](2);

        // 1: Attacker has seen victim with high slippage in the mempool, sent the transaction of ETH for tokens with increased gas
        vm.startPrank(attacker);
        erc20.approve(address(uniswapRouter), 1000000 ether);
        t[0] = address(erc20);
        t[1] = address(weth);
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, t, attacker, 1 ether);

        // 2: Unassuming victims tokens for ETH transaction continues, receives less tokens as a result
        vm.startPrank(victim);
        erc20.approve(address(uniswapRouter), 1000000 ether);
        t[0] = address(erc20);
        t[1] = address(weth);
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, t, victim, 1 ether);

        // 3: Attacker sells their ETH for tokens and receives some measure of profit
        vm.startPrank(attacker);
        t[0] = address(weth);
        t[1] = address(erc20);
        vm.expectRevert(); //Expect this to revert
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(0, t, attacker, 1 ether);

        /* Others interacting in the pool to test contract integrity - Ignore */
        vm.startPrank(bystanderSeller);
        erc20.approve(address(uniswapRouter), 1000000 ether);
        t[0] = address(erc20);
        t[1] = address(weth);
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, t, bystanderSeller, 1 ether);

        vm.startPrank(bystanderBuyer);
        t[0] = address(weth);
        t[1] = address(erc20);
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(0, t, bystanderBuyer, 1 ether);

        vm.stopPrank();
    }
}
