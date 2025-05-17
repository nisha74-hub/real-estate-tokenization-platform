// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RealEstateTokenization is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct Property {
        uint256 tokenId;
        string propertyAddress;
        uint256 totalValue;
        uint256 totalShares;
        uint256 availableShares;
        uint256 pricePerShare;
        string metadataURI;
        bool isActive;
        address propertyOwner;
    }

    struct ShareOwnership {
        uint256 shares;
        uint256 purchasePrice;
        uint256 purchaseDate;
    }

    mapping(uint256 => Property) public properties;
    mapping(uint256 => mapping(address => ShareOwnership)) public shareOwnership;
    mapping(uint256 => address[]) public propertyInvestors;

    event PropertyTokenized(
        uint256 indexed tokenId,
        string propertyAddress,
        uint256 totalValue,
        uint256 totalShares,
        uint256 pricePerShare
    );

    event SharesPurchased(
        uint256 indexed tokenId,
        address indexed investor,
        uint256 shares,
        uint256 totalCost
    );

    event SharesTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 shares
    );

    constructor() ERC721("RealEstateTokens", "RET") {}

    /**
     * @dev Tokenizes a real estate property by creating an NFT and dividing it into shares
     * @param _propertyAddress Physical address of the property
     * @param _totalValue Total valuation of the property in wei
     * @param _totalShares Total number of shares to divide the property into
     * @param _metadataURI IPFS URI containing property metadata
     */
    function tokenizeProperty(
        string memory _propertyAddress,
        uint256 _totalValue,
        uint256 _totalShares,
        string memory _metadataURI
    ) external onlyOwner returns (uint256) {
        require(_totalValue > 0, "Property value must be greater than 0");
        require(_totalShares > 0, "Total shares must be greater than 0");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");

        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();

        _safeMint(msg.sender, newTokenId);

        uint256 pricePerShare = _totalValue / _totalShares;

        properties[newTokenId] = Property({
            tokenId: newTokenId,
            propertyAddress: _propertyAddress,
            totalValue: _totalValue,
            totalShares: _totalShares,
            availableShares: _totalShares,
            pricePerShare: pricePerShare,
            metadataURI: _metadataURI,
            isActive: true,
            propertyOwner: msg.sender
        });

        emit PropertyTokenized(newTokenId, _propertyAddress, _totalValue, _totalShares, pricePerShare);

        return newTokenId;
    }

    /**
     * @dev Allows investors to purchase shares of a tokenized property
     * @param _tokenId Token ID of the property
     * @param _shares Number of shares to purchase
     */
    function purchaseShares(uint256 _tokenId, uint256 _shares) external payable nonReentrant {
        require(_exists(_tokenId), "Property does not exist");
        require(properties[_tokenId].isActive, "Property is not active");
        require(_shares > 0, "Shares must be greater than 0");
        require(_shares <= properties[_tokenId].availableShares, "Not enough shares available");

        uint256 totalCost = _shares * properties[_tokenId].pricePerShare;
        require(msg.value >= totalCost, "Insufficient payment");

        // Update property shares
        properties[_tokenId].availableShares -= _shares;

        // Update or create share ownership record
        if (shareOwnership[_tokenId][msg.sender].shares == 0) {
            propertyInvestors[_tokenId].push(msg.sender);
            shareOwnership[_tokenId][msg.sender] = ShareOwnership({
                shares: _shares,
                purchasePrice: totalCost,
                purchaseDate: block.timestamp
            });
        } else {
            shareOwnership[_tokenId][msg.sender].shares += _shares;
            shareOwnership[_tokenId][msg.sender].purchasePrice += totalCost;
        }

        // Transfer payment to property owner
        payable(properties[_tokenId].propertyOwner).transfer(totalCost);

        // Refund excess payment
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit SharesPurchased(_tokenId, msg.sender, _shares, totalCost);
    }

    /**
     * @dev Transfers shares between investors
     * @param _tokenId Token ID of the property
     * @param _to Address to transfer shares to
     * @param _shares Number of shares to transfer
     */
    function transferShares(
        uint256 _tokenId,
        address _to,
        uint256 _shares
    ) external {
        require(_exists(_tokenId), "Property does not exist");
        require(_to != address(0), "Cannot transfer to zero address");
        require(_to != msg.sender, "Cannot transfer to yourself");
        require(_shares > 0, "Shares must be greater than 0");
        require(shareOwnership[_tokenId][msg.sender].shares >= _shares, "Insufficient shares");

        // Update sender's shares
        shareOwnership[_tokenId][msg.sender].shares -= _shares;

        // Update receiver's shares
        if (shareOwnership[_tokenId][_to].shares == 0) {
            propertyInvestors[_tokenId].push(_to);
            shareOwnership[_tokenId][_to] = ShareOwnership({
                shares: _shares,
                purchasePrice: _shares * properties[_tokenId].pricePerShare,
                purchaseDate: block.timestamp
            });
        } else {
            shareOwnership[_tokenId][_to].shares += _shares;
        }

        // Remove sender from investors list if they have no more shares
        if (shareOwnership[_tokenId][msg.sender].shares == 0) {
            _removeInvestor(_tokenId, msg.sender);
        }

        emit SharesTransferred(_tokenId, msg.sender, _to, _shares);
    }

    /**
     * @dev Gets property information
     * @param _tokenId Token ID of the property
     */
    function getProperty(uint256 _tokenId) external view returns (Property memory) {
        require(_exists(_tokenId), "Property does not exist");
        return properties[_tokenId];
    }

    /**
     * @dev Gets share ownership information for an investor
     * @param _tokenId Token ID of the property
     * @param _investor Address of the investor
     */
    function getShareOwnership(uint256 _tokenId, address _investor) 
        external 
        view 
        returns (ShareOwnership memory) 
    {
        require(_exists(_tokenId), "Property does not exist");
        return shareOwnership[_tokenId][_investor];
    }

    /**
     * @dev Gets all investors for a property
     * @param _tokenId Token ID of the property
     */
    function getPropertyInvestors(uint256 _tokenId) external view returns (address[] memory) {
        require(_exists(_tokenId), "Property does not exist");
        return propertyInvestors[_tokenId];
    }

    /**
     * @dev Returns the token URI for metadata
     * @param _tokenId Token ID of the property
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Property does not exist");
        return properties[_tokenId].metadataURI;
    }

    /**
     * @dev Internal function to remove an investor from the investors array
     * @param _tokenId Token ID of the property
     * @param _investor Address of the investor to remove
     */
    function _removeInvestor(uint256 _tokenId, address _investor) internal {
        address[] storage investors = propertyInvestors[_tokenId];
        for (uint256 i = 0; i < investors.length; i++) {
            if (investors[i] == _investor) {
                investors[i] = investors[investors.length - 1];
                investors.pop();
                break;
            }
        }
    }

    /**
     * @dev Gets the current token ID counter
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }
}
