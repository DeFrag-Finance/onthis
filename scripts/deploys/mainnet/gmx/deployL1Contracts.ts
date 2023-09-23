/* eslint-disable */
import { ethers, upgrades } from 'hardhat';
import * as hre from 'hardhat';
import { L2GmxVault__factory } from '../../../../typechain-types';

const func = async () => {
  const { deployer } = await hre.getNamedAccounts();
  const owner = await hre.ethers.getSigner(deployer);

  const L1CloseAllGmxPositions = await ethers.getContractFactory('L1CloseAllGmxPositions', owner);
  const L1CloseAllGmxPositionsContract = await upgrades.deployProxy(L1CloseAllGmxPositions);
  await L1CloseAllGmxPositionsContract.deployed();
  console.log('L1CloseAllGmxPositionsContract:',L1CloseAllGmxPositionsContract);

  const L1OpenGmxLong = await ethers.getContractFactory('L1OpenGmxLong', owner);
  const L1OpenGmxLongContract = await upgrades.deployProxy(L1OpenGmxLong);
  await L1OpenGmxLongContract.deployed();
  console.log('L1OpenGmxLongContract:',L1OpenGmxLongContract);

  const L1OpenGmxShort = await ethers.getContractFactory('L1OpenGmxShort', owner);
  const L1OpenGmxShorContractt = await upgrades.deployProxy(L1OpenGmxShort);
  await L1OpenGmxShorContractt.deployed();
  console.log('L1OpenGmxShorContractt:',L1OpenGmxShorContractt);
};

func();
