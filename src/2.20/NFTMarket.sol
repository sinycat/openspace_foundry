// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
    
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMarket is ReentrancyGuard {
    IERC20 public immutable paymentToken;
    
    struct Listing {
        address seller;
        uint256 price;
    }
    
    // NFT合约地址 => NFT ID => Listing信息
    mapping(address => mapping(uint256 => Listing)) public listings;
    
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address seller, address indexed buyer, uint256 price);
    
    error PriceMustBeAboveZero();
    error NotOwner();
    error NotApproved();
    error AlreadyListed();
    error NotListed();
    error PriceNotMet(uint256 expected, uint256 actual);
    error CannotBuyOwnNFT();
    
    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
    }
    
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        if (price == 0) revert PriceMustBeAboveZero();
        
        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (!nft.isApprovedForAll(msg.sender, address(this)) && 
            nft.getApproved(tokenId) != address(this)) revert NotApproved();
        if (listings[nftContract][tokenId].price > 0) revert AlreadyListed();
        
        listings[nftContract][tokenId] = Listing(msg.sender, price);
        
        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }
    
    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        if (listing.price == 0) revert NotListed();
        if (listing.seller == msg.sender) revert CannotBuyOwnNFT();
        
        delete listings[nftContract][tokenId];
        
        if (!paymentToken.transferFrom(msg.sender, listing.seller, listing.price)) {
            revert PriceNotMet(listing.price, 0);
        }
        
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);
        
        emit NFTSold(nftContract, tokenId, listing.seller, msg.sender, listing.price);
    }
}