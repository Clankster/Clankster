// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ClanksterMultiplierNFT is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    // Multiplier card structure
    struct MultiplierCard {
        uint256 multiplier;   
        uint256 expiryDate;     
        bool isActive;         
    }
    
    mapping(uint256 => MultiplierCard) public multiplierCards;
    mapping(address => uint256[]) public userActiveCards;
    
    event MultiplierCardMinted(address indexed user, uint256 tokenId, uint256 multiplier);
    event MultiplierCardExpired(uint256 tokenId);
    
    constructor() ERC721("Clankster Multiplier Card", "CLANKM") {}
    
    // Override transfer functions to make NFT soulbound
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        require(
            from == address(0) || to == address(0), 
            "Token is soulbound - cannot transfer"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    // Mint new multiplier card (only owner or authorized address)
    function mintMultiplierCard(
        address to,
        uint256 multiplier,
        uint256 durationInDays
    ) external onlyOwner nonReentrant returns (uint256) {
        require(multiplier == 2 || multiplier == 3 || multiplier == 5, "Invalid multiplier");
        require(durationInDays <= 30, "Duration cannot exceed 30 days");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        uint256 expiryDate = block.timestamp + (durationInDays * 1 days);
        
        multiplierCards[newTokenId] = MultiplierCard({
            multiplier: multiplier,
            expiryDate: expiryDate,
            isActive: true
        });
        
        // Mint the NFT
        _safeMint(to, newTokenId);
        
        userActiveCards[to].push(newTokenId);
        
        emit MultiplierCardMinted(to, newTokenId, multiplier);
        
        return newTokenId;
    }
    
    // Check if a card is still valid
    function isCardValid(uint256 tokenId) public view returns (bool) {
        MultiplierCard memory card = multiplierCards[tokenId];
        return card.isActive && block.timestamp <= card.expiryDate;
    }
    
    // Get user's highest active multiplier
    function getUserHighestMultiplier(address user) public view returns (uint256) {
        uint256 highestMultiplier = 1;
        
        uint256[] memory userCards = userActiveCards[user];
        for (uint256 i = 0; i < userCards.length; i++) {
            uint256 tokenId = userCards[i];
            if (isCardValid(tokenId)) {
                MultiplierCard memory card = multiplierCards[tokenId];
                if (card.multiplier > highestMultiplier) {
                    highestMultiplier = card.multiplier;
                }
            }
        }
        
        return highestMultiplier;
    }
    
    // Expire card (can be called by anyone, but only affects expired cards)
    function expireCard(uint256 tokenId) external {
        require(_exists(tokenId), "Card does not exist");
        MultiplierCard storage card = multiplierCards[tokenId];
        require(block.timestamp > card.expiryDate, "Card not yet expired");
        require(card.isActive, "Card already expired");
        
        card.isActive = false;
        emit MultiplierCardExpired(tokenId);
    }
    
    // Get all active multiplier cards for a user
    function getUserActiveMultipliers(address user) external view returns (
        uint256[] memory tokenIds,
        uint256[] memory multipliers,
        uint256[] memory expiryDates
    ) {
        uint256[] memory userCards = userActiveCards[user];
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < userCards.length; i++) {
            if (isCardValid(userCards[i])) {
                activeCount++;
            }
        }
        
        tokenIds = new uint256[](activeCount);
        multipliers = new uint256[](activeCount);
        expiryDates = new uint256[](activeCount);
        
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < userCards.length; i++) {
            uint256 tokenId = userCards[i];
            if (isCardValid(tokenId)) {
                MultiplierCard memory card = multiplierCards[tokenId];
                tokenIds[currentIndex] = tokenId;
                multipliers[currentIndex] = card.multiplier;
                expiryDates[currentIndex] = card.expiryDate;
                currentIndex++;
            }
        }
        
        return (tokenIds, multipliers, expiryDates);
    }
}