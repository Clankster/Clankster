// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../nft/ClanksterMultiplierNFT.sol";

contract ClanksterAirdrop is Ownable, ReentrancyGuard {
    IERC20 public clanksterToken;

    // Snapshot timestamps
    uint256 public startSnapshot;
    uint256 public endSnapshot;

    // Minimum holding requirement (1 million tokens)
    uint256 public constant MIN_HOLDING = 1_000_000 * 1e18;
    address public multiplierNFTAddress;

    // Holder data structure
    struct HolderData {
        uint256 startBalance;
        uint256 endBalance;
        bool hasClaimed;
        uint256 penaltyRate;
    }

    mapping(address => HolderData) public holderData;

    event SnapshotTaken(uint256 timestamp, string snapshotType);
    event RewardClaimed(address indexed holder, uint256 amount);
    event PenaltyApplied(address indexed holder, uint256 penaltyRate);

    constructor(address _clanksterToken) {
        clanksterToken = IERC20(_clanksterToken);
    }

    // Take start snapshot (1st of month)
    function takeStartSnapshot() external onlyOwner {
        startSnapshot = block.timestamp;
        emit SnapshotTaken(startSnapshot, "START");
    }

    // Take end snapshot (30th of month)
    function takeEndSnapshot() external onlyOwner {
        endSnapshot = block.timestamp;
        emit SnapshotTaken(endSnapshot, "END");
    }

    // Record holder balances
    function recordHolderBalance(address holder) external {
        uint256 balance = clanksterToken.balanceOf(holder);

        if (block.timestamp == startSnapshot) {
            holderData[holder].startBalance = balance;
        } else if (block.timestamp == endSnapshot) {
            holderData[holder].endBalance = balance;
        }

        if (holderData[holder].endBalance < holderData[holder].startBalance) {
            if (holderData[holder].startBalance >= MIN_HOLDING) {
                holderData[holder].penaltyRate = 50;
            }
            else {
                holderData[holder].penaltyRate = 70;
            }
            emit PenaltyApplied(holder, holderData[holder].penaltyRate);
        }
    }

    // Calculate reward amount
    function calculateReward(address holder) public view returns (uint256) {
        HolderData memory data = holderData[holder];
        if (data.startBalance < MIN_HOLDING || data.endBalance < MIN_HOLDING) {
            return 0;
        }
        uint256 baseReward = (data.startBalance + data.endBalance) / 2;

        if (data.penaltyRate > 0) {
            baseReward = (baseReward * (100 - data.penaltyRate)) / 100;
        }


        uint256 multiplier = ClanksterMultiplierNFT(multiplierNFTAddress)
            .getUserHighestMultiplier(holder);

        return baseReward * multiplier;
    }

    // Claim reward
    function claimReward() external nonReentrant {
        require(block.timestamp > endSnapshot, "Snapshot period not ended");
        require(!holderData[msg.sender].hasClaimed, "Already claimed");

        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No reward available");

        holderData[msg.sender].hasClaimed = true;
        require(clanksterToken.transfer(msg.sender, reward), "Transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }
}
