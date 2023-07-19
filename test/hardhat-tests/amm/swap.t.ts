/**
 * @description TODO
 * *** IT IS RECOMMENDED TO ONLY USE THIS FILE ON A TESTNET, THIS FILE IS PRONE TO LARGE SCALE CHANGES
 * WITH NO NOTICE***
 */

/* TODO Use node modules for uniswap + openzepplin */

import { ethers } from "hardhat";
import * as deployments from "../common/deployments";

describe("Swap Test", () => {
  let erc20Contract, uniswapContracts: any;

  it("Should deploy the ERC20 + Uniswap", async () => {
    try {
      const ERC20 = await ethers.getContractFactory("ERC20AntiMEV");
      erc20Contract = await ERC20.deploy(BigInt(10e18), "TEST");
      uniswapContracts = await deployments.deployAllUniswapContracts();
    } catch (err) {
      throw err;
    }
  });

  it("Should run a approve from the main member to the router for pair creation", async () => {
    await erc20Contract.approve(uniswapContracts.routerContract.address, ethers.constants.MaxUint256);
  });

  it("Should initialise the LP pool and test transfer", async () => {
    try {
      const members = await ethers.getSigners();

      console.log(erc20Contract.address);
      console.log(BigInt(1e18));
  
      await uniswapContracts.routerContract.addLiquidityETH(
        erc20Contract.address,
        BigInt(1e18),
        0,
        0,
        members[0].address,
        ethers.constants.MaxUint256,
        {value: BigInt(1e18)}
      );

      await erc20Contract.transfer("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", BigInt(1e18));
    } catch (err) {
      throw err;
    }
  });
});
