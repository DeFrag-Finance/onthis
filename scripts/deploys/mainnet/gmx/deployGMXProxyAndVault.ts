/* eslint-disable */
import { ethers, upgrades } from 'hardhat';
import * as hre from 'hardhat';
import { L2GmxVault__factory } from '../../../../typechain-types';

const func = async () => {
  const { deployer } = await hre.getNamedAccounts();
  const owner = await hre.ethers.getSigner(deployer);

  const L2GmxProxy = await ethers.getContractFactory('L2GmxProxy', owner);
  const L2GmxProxyContract = await upgrades.deployProxy(L2GmxProxy);
  await L2GmxProxyContract.deployed();

  console.log('L2GmxProxy deployed to:', L2GmxProxyContract.address);

  const L2GmxVault = await ethers.getContractFactory('L2GmxVault', owner);
  const L2GmxVaultContract = await upgrades.deployProxy(L2GmxVault);
  await L2GmxVaultContract.deployed();

  console.log('L2GmxVaultContract deployed to:', L2GmxVaultContract.address);

  const L2GmxVaultDeployedContract = new ethers.Contract(
    L2GmxVaultContract.address,
    L2GmxVault__factory.abi,
    owner,
  );

  await L2GmxVaultDeployedContract.connect(owner).setDeployedProxy(
    L2GmxProxyContract.address,
  );
  console.log('proxy setted');
};

func();
