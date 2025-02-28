// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/2_26_ERC2612/NFTMarketV2.sol";
import "../src/2_26_ERC2612/MyNFTV2.sol";
import "../src/2_19_NFTMarket/MyToken.sol";

contract NFTMarketV2Test is Test {
    NFTMarketV2 public market;
    MyNFTV2 public nft;
    MyToken public token;
    
    address public seller;
    address public buyer;
    uint256 private sellerPrivateKey;
    uint256 private buyerPrivateKey;
    
    uint256 public constant PRICE = 1 ether;
    uint256 public constant INITIAL_BALANCE = 10 ether;

    function setUp() public {
        // 部署合约
        token = new MyToken();
        nft = new MyNFTV2();
        market = new NFTMarketV2(address(token));
        
        // 设置测试账户
        sellerPrivateKey = 0x1234;
        buyerPrivateKey = 0x5678;
        seller = vm.addr(sellerPrivateKey);
        buyer = vm.addr(buyerPrivateKey);
        
        // 给买家代币
        token.transfer(buyer, INITIAL_BALANCE);
        
        // 给卖家铸造NFT
        nft.mintNFT(seller, "https://example.com/token/1");
    }

    function testListNFT() public {
        uint256 tokenId = 1;
        
        vm.startPrank(seller);
        // 授权市场合约
        nft.approve(address(market), tokenId);
        // 上架NFT
        market.list(address(nft), tokenId, PRICE);
        vm.stopPrank();
        
        // 验证上架信息
        (address nftContract, uint256 listedTokenId, uint256 price, address nftSeller) = market.listings(address(nft), tokenId);
        assertEq(nftContract, address(nft));
        assertEq(listedTokenId, tokenId);
        assertEq(price, PRICE);
        assertEq(nftSeller, seller);
    }

    function testCancelListing() public {
        uint256 tokenId = 1;
        
        // 先上架
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, PRICE);
        
        // 然后取消上架
        market.cancelListing(address(nft), tokenId);
        vm.stopPrank();
        
        // 验证上架信息已清除
        (,,,address nftSeller) = market.listings(address(nft), tokenId);
        assertEq(nftSeller, address(0));
    }

    function testBuyNFT() public {
        uint256 tokenId = 1;
        
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, PRICE);
        vm.stopPrank();
        
        // 买家授权并购买
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();
        
        // 验证NFT所有权已转移
        assertEq(nft.ownerOf(tokenId), buyer);
        // 验证代币已转移
        assertEq(token.balanceOf(seller), PRICE);
        // 验证上架信息已清除
        (,,,address nftSeller) = market.listings(address(nft), tokenId);
        assertEq(nftSeller, address(0));
    }

    function testPermitBuy() public {
        uint256 tokenId = 1;
        
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, PRICE);
        
        // 准备permit数据
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = nft.nonces(tokenId);
        
        // 构建permit签名数据
        bytes32 DOMAIN_SEPARATOR = nft.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                seller,
                address(market),  // 改为市场合约地址
                tokenId,
                nonce,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );
        
        // 卖家签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, hash);
        vm.stopPrank();
        
        // 买家购买
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        
        NFTMarketV2.PermitData memory permitData = NFTMarketV2.PermitData({
            owner: seller,
            spender: address(market),  // 改为市场合约地址
            tokenId: tokenId,
            nonce: nonce,
            deadline: deadline
        });
        
        market.permitBuy(
            address(nft),
            permitData,
            v,
            r,
            s
        );
        vm.stopPrank();
        
        // 验证NFT所有权已转移
        assertEq(nft.ownerOf(tokenId), buyer);
        // 验证代币已转移
        assertEq(token.balanceOf(seller), PRICE);
        // 验证上架信息已清除
        (,,,address nftSeller) = market.listings(address(nft), tokenId);
        assertEq(nftSeller, address(0));
    }
} 