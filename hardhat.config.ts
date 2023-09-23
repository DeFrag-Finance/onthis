import type { HardhatUserConfig } from 'hardhat/config';
import '@openzeppelin/hardhat-upgrades';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-docgen';

import {
  ENV,
  GWEI,
  getForkNetworkConfig,
  getHardhatNetworkConfig,
  getNetworkConfig,
} from './config';

const { OPTIMIZER, REPORT_GAS, FORKING_NETWORK, ETHERSCAN_API_KEY } = ENV;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.9',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    main: getNetworkConfig('main'),
    hardhat: {
      forking: {
        url: '',
      },
      saveDeployments: true,
      live: false,
      accounts: {
        mnemonic: process.env.MNEMONIC_PROD,
      },
    },
    localhost: getNetworkConfig('localhost'),
    // arbitrum: {
    //   url: '',
    //   accounts: [
    //     '',
    //   ],
    // },
  },
  gasReporter: {
    enabled: REPORT_GAS,
  },
  contractSizer: {
    runOnCompile: OPTIMIZER,
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  paths: {
    deploy: 'deploy/',
    deployments: 'deployments/',
  },
  docgen: {
    path: './docgen',
    clear: true,
    runOnCompile: false,
  },
};

export default config;
