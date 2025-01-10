  import { HardhatUserConfig } from "hardhat/config";
  import "@nomicfoundation/hardhat-toolbox";

  const endpointUrl="https://ethereum-sepolia-rpc.publicnode.com";
  const privateKey="d8bddd81698dab201dea327df7ad9b9a1579827d9ae4eda67bccafe93bea7151";

  const config: HardhatUserConfig = {
    solidity: "0.8.22",
    networks: {
      mainnet: {
        url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
        chainId: 1,
        gasPrice: 20000000000,
        accounts: [privateKey]
      },
      sepolia: {
        url: endpointUrl,
        chainId: 11155111,
        accounts: [privateKey]
      }
    },
    etherscan: {
      apiKey: {
        sepolia: 'YGR1IJIVHSZ52FS124GAMT63Y5QWRJPGAE'
      }
    }
  };

  export default config;
