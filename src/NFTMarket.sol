// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract NFTMarket is Context {
    IERC20 public erc20Token;
    mapping(uint256 => Listing) public listings;

    struct Listing {
        address seller;
        uint256 price;
        bool isListed;
    }

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    constructor(address _erc20Token) {
        erc20Token = IERC20(_erc20Token);
    }

    function listNFT(address _nftContract, uint256 _tokenId, uint256 _price) external {
        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId) == _msgSender(), "You are not the owner of this NFT");
        require(!listings[_tokenId].isListed, "NFT is already listed");
        nft.transferFrom(_msgSender(), address(this), _tokenId);

        listings[_tokenId] = Listing({
            seller: _msgSender(),
            price: _price,
            isListed: true
        });

        emit NFTListed(_tokenId, _msgSender(), _price);
    }

    function buyNFT(address _nftContract, uint256 _tokenId) external {
        Listing storage listing = listings[_tokenId];
        require(listing.isListed, "NFT is not listed");
        require(_msgSender() != listing.seller, "You cannot buy your own NFT");

        erc20Token.transferFrom(_msgSender(), listing.seller, listing.price);
        IERC721(_nftContract).transferFrom(address(this), _msgSender(), _tokenId);

        listing.isListed = false;
        emit NFTSold(_tokenId, listing.seller, _msgSender(), listing.price);
    }
}