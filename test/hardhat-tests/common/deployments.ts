import { ethers } from "hardhat";

export const deployAllUniswapContracts = async () => {
  let factoryContract = await deployFactoryContract();
  let WETHContract = await deployWETHContract();
  let routerContract = await deployRouterContract(factoryContract.address, WETHContract.address);

  return { factoryContract, routerContract, WETHContract };
};

export const deployFactoryContract = async () => {
  const Factory = await ethers.getContractFactory("UniswapV2Factory");
  let factoryContract = await Factory.deploy(ethers.constants.AddressZero);
  await factoryContract.deployed();
  return factoryContract;
};

export const deployRouterContract = async (_factoryAddress: string, _WETHAddress: string) => {
  const Router = await ethers.getContractFactory("UniswapV2Router02");
  let routerContract = await Router.deploy(_factoryAddress, _WETHAddress);
  await routerContract.deployed();
  return routerContract;
};

export const deployWETHContract = async () => {
  const WETH = await ethers.getContractFactory("WETH9");
  let wethContract = await WETH.deploy();
  await wethContract.deployed();
  return wethContract;
};
