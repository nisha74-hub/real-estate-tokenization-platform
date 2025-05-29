// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RealEstateTokenization is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter privat
    bool public isPaused
    struct Pro
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

    // Events
    event PropertyTokenized(uint256 indexed tokenId, string propertyAddress, uint256 totalValue, uint256 totalShares, uint256 pricePerShare);
    event SharesPurchased(uint256 indexed tokenId, address indexed investor, uint256 shares, uint256 totalCost);
    event SharesTransferred(uint256 indexed tokenId, address indexed from, address indexed to, uint256 shares);
    event PropertyDeactivated(uint256 indexed tokenId);
    event SharesWithdrawn(uint256 indexed tokenId, address indexed owner, uint256 shares);
    event MetadataUpdated(uint256 indexed tokenId, string newURI);
    event Paused();
    event Unpaused();

    modifier notPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    constructor() ERC721("RealEstateTokens", "RET") {}

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

    function purchaseShares(uint256 _tokenId, uint256 _shares) external payable nonReentrant notPaused {
        Property storage prop = properties[_tokenId];

        require(_exists(_tokenId), "Property does not exist");
        require(prop.isActive, "Property not active");
        require(_shares > 0 && _shares <= prop.availableShares, "Invalid share count");

        uint256 totalCost = _shares * prop.pricePerShare;
        require(msg.value >= totalCost, "Insufficient payment");

        prop.availableShares -= _shares;

        if (shareOwnership[_tokenId][msg.sender].shares == 0) {
            propertyInvestors[_tokenId].push(msg.sender);
            shareOwnership[_tokenId][msg.sender] = ShareOwnership(_shares, totalCost, block.timestamp);
        } else {
            ShareOwnership storage ownership = shareOwnership[_tokenId][msg.sender];
            ownership.shares += _shares;
            ownership.purchasePrice += totalCost;
        }

        payable(prop.propertyOwner).transfer(totalCost);

        // Refund excess ETH
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit SharesPurchased(_tokenId, msg.sender, _shares, totalCost);
    }

    function transferShares(uint256 _tokenId, address _to, uint256 _shares) external notPaused {
        require(_exists(_tokenId), "Property does not exist");
        require(_to != address(0) && _to != msg.sender, "Invalid recipient");
        require(_shares > 0, "Shares must be greater than 0");
        require(shareOwnership[_tokenId][msg.sender].shares >= _shares, "Insufficient shares");

        shareOwnership[_tokenId][msg.sender].shares -= _shares;

        if (shareOwnership[_tokenId][_to].shares == 0) {
            propertyInvestors[_tokenId].push(_to);
            shareOwnership[_tokenId][_to] = ShareOwnership(_shares, _shares * properties[_tokenId].pricePerShare, block.timestamp);
        } else {
            shareOwnership[_tokenId][_to].shares += _shares;
        }

        if (shareOwnership[_tokenId][msg.sender].shares == 0) {
            _removeInvestor(_tokenId, msg.sender);
        }

        emit SharesTransferred(_tokenId, msg.sender, _to, _shares);
    }

    function deactivateProperty(uint256 _tokenId) external onlyOwner {
        require(_exists(_tokenId), "Property does not exist");
        properties[_tokenId].isActive = false;
        emit PropertyDeactivated(_tokenId);
    }

    function withdrawUnsoldShares(uint256 _tokenId) external onlyOwner nonReentrant {
        Property storage prop = properties[_tokenId];
        require(_exists(_tokenId), "Property does not exist");
        require(!prop.isActive, "Property still active");
        require(prop.availableShares > 0, "No unsold shares");

        uint256 unsold = prop.availableShares;
        prop.availableShares = 0;

        emit SharesWithdrawn(_tokenId, msg.sender, unsold);
    }

    function updateMetadataURI(uint256 _tokenId, string memory _newURI) external onlyOwner {
        require(_exists(_tokenId), "Property does not exist");
        properties[_tokenId].metadataURI = _newURI;
        emit MetadataUpdated(_tokenId, _newURI);
    }

    function pause() external onlyOwner {
        isPaused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        isPaused = false;
        emit Unpaused();
    }

    // View Functions
    function getProperty(uint256 _tokenId) external view returns (Property memory) {
        require(_exists(_tokenId), "Property does not exist");
        return properties[_tokenId];
    }

    function getShareOwnership(uint256 _tokenId, address _investor) external view returns (ShareOwnership memory) {
        require(_exists(_tokenId), "Property does not exist");
        return shareOwnership[_tokenId][_investor];
    }

    function getInvestorShares(uint256 _tokenId, address _investor) external view returns (uint256) {
        require(_exists(_tokenId), "Property does not exist");
        return shareOwnership[_tokenId][_investor].shares;
    }

    function getPropertyInvestors(uint256 _tokenId) external view returns (address[] memory) {
        require(_exists(_tokenId), "Property does not exist");
        return propertyInvestors[_tokenId];
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Property does not exist");
        return properties[_tokenId].metadataURI;
    }

    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

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
}
