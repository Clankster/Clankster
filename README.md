# Deploy a Smart Contract with Hardhat

# deploy
npx hardhat run --network sepolia scripts/deploy.ts (0x8A41B72fa3FfDD52FD0FdB5823116Abcc96467B2)

# verify
npx hardhat verify --contract contracts/MyToken.sol:MyToken --network sepolia 0x8A41B72fa3FfDD52FD0FdB5823116Abcc96467B2 1000000000000000000000000 