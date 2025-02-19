// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// 创建测试用的代币合约
contract TestERC20 is ERC20 {
    constructor() ERC20("Test Token", "TT") {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// 创建测试用的NFT合约
contract TestERC721 is ERC721 {
    uint256 private _tokenIds;
    
    constructor() ERC721("Test NFT", "TNFT") {}
    
    function mint(address to) public returns (uint256) {
        uint256 newTokenId = ++_tokenIds;
        _mint(to, newTokenId);
        return newTokenId;
    }
}

contract NFTMarketTest is Test {
    NFTMarket public nftMarket;
    TestERC20 public paymentToken;
    TestERC721 public nftContract;
    
    address owner;
    address seller;
    address buyer;
    
    uint256 constant NFT_ID = 1;
    uint256 constant INITIAL_BALANCE = 10000 ether;
    
    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        
        // 部署合约
        paymentToken = new TestERC20();
        nftContract = new TestERC721();
        nftMarket = new NFTMarket(address(paymentToken));
        
        // 铸造NFT给seller
        nftContract.mint(seller);
        
        // 给买家铸造代币
        paymentToken.mint(buyer, INITIAL_BALANCE);
        
        // 设置授权
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(nftMarket), true);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), type(uint256).max);
        vm.stopPrank();
    }
    
    function test_ListNFT() public {
        uint256 price = 100 ether;
        
        vm.startPrank(seller);
        nftMarket.listNFT(address(nftContract), NFT_ID, price);
        
        (address listedSeller, uint256 listedPrice) = nftMarket.listings(address(nftContract), NFT_ID);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        vm.stopPrank();
    }
    
    function test_ListNFT_RevertIfPriceZero() public {
        vm.startPrank(seller);
        vm.expectRevert(NFTMarket.PriceMustBeAboveZero.selector);
        nftMarket.listNFT(address(nftContract), NFT_ID, 0);
        vm.stopPrank();
    }
    
    function test_ListNFT_RevertIfNotOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert(NFTMarket.NotOwner.selector);
        nftMarket.listNFT(address(nftContract), NFT_ID, 100 ether);
        vm.stopPrank();
    }
    
    function test_BuyNFT() public {
        uint256 price = 100 ether;
        
        // 上架NFT
        vm.prank(seller);
        nftMarket.listNFT(address(nftContract), NFT_ID, price);
        
        // 购买NFT
        vm.prank(buyer);
        nftMarket.buyNFT(address(nftContract), NFT_ID);
        
        // 验证NFT所有权转移
        assertEq(nftContract.ownerOf(NFT_ID), buyer);
        // 验证代币转移
        assertEq(paymentToken.balanceOf(seller), price);
        assertEq(paymentToken.balanceOf(buyer), INITIAL_BALANCE - price);
    }
    
    function test_BuyNFT_RevertIfBuyOwnNFT() public {
        uint256 price = 100 ether;
        
        vm.prank(seller);
        nftMarket.listNFT(address(nftContract), NFT_ID, price);
        
        vm.prank(seller);
        vm.expectRevert(NFTMarket.CannotBuyOwnNFT.selector);
        nftMarket.buyNFT(address(nftContract), NFT_ID);
    }
    
    function test_BuyNFT_RevertIfNotListed() public {
        vm.prank(buyer);
        vm.expectRevert(NFTMarket.NotListed.selector);
        nftMarket.buyNFT(address(nftContract), NFT_ID);
    }
    
    function testFuzz_ListAndBuyNFT(uint256 price) public {
        // 限制价格范围在 0.01-10000 token
        price = bound(price, 0.01 ether, 10000 ether);
        
        // 确保买家有足够的代币
        paymentToken.mint(buyer, price);
        
        vm.prank(seller);
        nftMarket.listNFT(address(nftContract), NFT_ID, price);
        
        vm.prank(buyer);
        nftMarket.buyNFT(address(nftContract), NFT_ID);
        
        assertEq(nftContract.ownerOf(NFT_ID), buyer);
        assertEq(paymentToken.balanceOf(seller), price);
    }
    
    function testInvariant_NoTokenBalance() public {
        // 验证市场合约没有代币余额
        assertEq(paymentToken.balanceOf(address(nftMarket)), 0);
        
        uint256 price = 100 ether;
        
        // 上架和购买NFT
        vm.prank(seller);
        nftMarket.listNFT(address(nftContract), NFT_ID, price);
        
        vm.prank(buyer);
        nftMarket.buyNFT(address(nftContract), NFT_ID);
        
        // 再次验证市场合约没有代币余额
        assertEq(paymentToken.balanceOf(address(nftMarket)), 0);
    }
}