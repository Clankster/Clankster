// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IClanksterMultiplierNFT {
    function getUserHighestMultiplier(address user) external view returns (uint256);
    function getMonthlyNFTHolders(uint256 monthId) external view returns (address[] memory);
}

contract ClanksterAirdrop is Ownable, ReentrancyGuard {
    IERC20 public clanksterToken;
    IClanksterMultiplierNFT public multiplierNFT;
    
    uint256 public currentMonthId;
    
    // Percentage splits (out of 100)
    uint256 public constant NFT_HOLDERS_SHARE = 40; // 40% to NFT holders
    uint256 public constant LOYALTY_SHARE = 60; // 60% to loyal holders
    
    struct MonthData {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 totalPenalties;
        bool penaltiesDistributed;
        uint256 nftHoldersAmount;
        uint256 loyaltyAmount;
        uint256 totalLoyalHolders;
    }
    
    struct HolderData {
        uint256 startBalance;
        uint256 endBalance;
        bool hasClaimed;
        bool isLoyal;
        uint256 penaltyAmount;
        uint256 baseReward;
        uint256 loyaltyReward;
    }
    
    mapping(uint256 => MonthData) public monthData;
    mapping(address => mapping(uint256 => HolderData)) public holderData;
    
    event SnapshotTaken(uint256 monthId, uint256 timestamp, string snapshotType);
    event RewardClaimed(
        address indexed holder, 
        uint256 monthId, 
        uint256 baseAmount,
        uint256 loyaltyAmount
    );
    event PenaltyApplied(address indexed holder, uint256 monthId, uint256 amount);
    event PenaltiesDistributed(
        uint256 monthId, 
        uint256 totalAmount, 
        uint256 nftHoldersAmount, 
        uint256 loyaltyAmount
    );
    
    constructor(
        address _clanksterToken, 
        address _multiplierNFT
    ) {
        clanksterToken = IERC20(_clanksterToken);
        multiplierNFT = IClanksterMultiplierNFT(_multiplierNFT);
    }
    
    function endMonth() external onlyOwner {
        require(monthData[currentMonthId].startTimestamp > 0, "Month not started");
        require(monthData[currentMonthId].endTimestamp == 0, "Month already ended");
        
        MonthData storage month = monthData[currentMonthId];
        month.endTimestamp = block.timestamp;
        
        // Calculate loyal holders count
        address[] memory holders = getMonthHolders(currentMonthId);
        uint256 loyalCount = 0;
        
        for (uint256 i = 0; i < holders.length; i++) {
            HolderData storage data = holderData[holders[i]][currentMonthId];
            if (data.endBalance >= data.startBalance) {
                data.isLoyal = true;
                loyalCount++;
            }
        }
        
        month.totalLoyalHolders = loyalCount;
        month.loyaltyAmount = (month.totalPenalties * LOYALTY_SHARE) / 100;
        month.nftHoldersAmount = (month.totalPenalties * NFT_HOLDERS_SHARE) / 100;
        
        emit SnapshotTaken(currentMonthId, block.timestamp, "END");
    }
    
    function calculateRewards(address holder, uint256 monthId) public view returns (
        uint256 baseReward,
        uint256 loyaltyReward
    ) {
        HolderData memory data = holderData[holder][monthId];
        MonthData memory month = monthData[monthId];
        
        // Calculate base reward
        if (data.endBalance >= data.startBalance) {
            baseReward = (data.startBalance + data.endBalance) / 2;
            uint256 multiplier = multiplierNFT.getUserHighestMultiplier(holder);
            baseReward = baseReward * multiplier;
        }
        
        // Calculate loyalty reward if eligible
        if (data.isLoyal && month.totalLoyalHolders > 0) {
            loyaltyReward = month.loyaltyAmount / month.totalLoyalHolders;
        }
        
        return (baseReward, loyaltyReward);
    }
    
    function claimReward(uint256 monthId) external nonReentrant {
        MonthData storage month = monthData[monthId];
        HolderData storage data = holderData[msg.sender][monthId];
        
        require(month.endTimestamp > 0, "Month not ended");
        require(!data.hasClaimed, "Already claimed");
        
        (uint256 baseReward, uint256 loyaltyReward) = calculateRewards(msg.sender, monthId);
        require(baseReward > 0 || loyaltyReward > 0, "No rewards available");
        
        uint256 totalReward = baseReward + loyaltyReward;
        data.hasClaimed = true;
        data.baseReward = baseReward;
        data.loyaltyReward = loyaltyReward;
        
        require(clanksterToken.transfer(msg.sender, totalReward), "Reward transfer failed");
        
        emit RewardClaimed(msg.sender, monthId, baseReward, loyaltyReward);
    }
    
    function getMonthHolders(uint256 monthId) internal view returns (address[] memory) {
        // track holders during month
    }
}