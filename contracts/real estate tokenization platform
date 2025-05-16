// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RealEstateToken
 * @dev A smart contract for tokenizing real estate assets
 */
contract RealEstateToken is ERC20, Ownable {
    struct Property {
        string propertyId;
        string location;
        uint256 totalValue;
        uint256 totalTokens;
        bool isListed;
    }

    mapping(string => Property) public properties;
    string[] public propertyIds;

    event PropertyTokenized(string propertyId, string location, uint256 totalValue, uint256 totalTokens);
    event TokensPurchased(address buyer, string propertyId, uint256 amount);

    /**
     * @dev Constructor initializes the contract with a name and symbol
     */
    constructor() ERC20("Real Estate Token", "RET") Ownable(msg.sender) {}

    /**
     * @dev Tokenize a new property
     * @param propertyId Unique identifier for the property
     * @param location Geographic location of the property
     * @param totalValue Total value of the property in wei
     * @param totalTokens Total number of tokens to represent the property
     */
    function tokenizeProperty(
        string memory propertyId,
        string memory location,
        uint256 totalValue,
        uint256 totalTokens
    ) external onlyOwner {
        require(bytes(propertyId).length > 0, "Property ID cannot be empty");
        require(bytes(properties[propertyId].propertyId).length == 0, "Property already tokenized");
        require(totalValue > 0, "Property value must be greater than zero");
        require(totalTokens > 0, "Number of tokens must be greater than zero");

        properties[propertyId] = Property({
            propertyId: propertyId,
            location: location,
            totalValue: totalValue,
            totalTokens: totalTokens,
            isListed: true
        });

        propertyIds.push(propertyId);

        // Mint tokens to contract owner
        _mint(owner(), totalTokens);

        emit PropertyTokenized(propertyId, location, totalValue, totalTokens);
    }

    /**
     * @dev Purchase tokens for a specific property
     * @param propertyId ID of the property to purchase tokens for
     * @param amount Number of tokens to purchase
     */
    function purchaseTokens(string memory propertyId, uint256 amount) external payable {
        Property storage property = properties[propertyId];
        require(bytes(property.propertyId).length > 0, "Property does not exist");
        require(property.isListed, "Property is not listed for sale");
        
        uint256 tokenPrice = property.totalValue / property.totalTokens;
        uint256 requiredPayment = tokenPrice * amount;
        
        require(msg.value >= requiredPayment, "Insufficient payment");
        require(balanceOf(owner()) >= amount, "Not enough tokens available");

        // Transfer tokens from owner to buyer
        _transfer(owner(), msg.sender, amount);
        
        // Refund excess payment if any
        if (msg.value > requiredPayment) {
            payable(msg.sender).transfer(msg.value - requiredPayment);
        }

        emit TokensPurchased(msg.sender, propertyId, amount);
    }

    /**
     * @dev Get all tokenized properties
     * @return array of property IDs
     */
    function getAllProperties() external view returns (string[] memory) {
        return propertyIds;
    }

    /**
     * @dev Withdraw funds from the contract
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance");
        payable(owner()).transfer(amount);
    }
}
