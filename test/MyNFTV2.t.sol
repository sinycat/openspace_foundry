// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/2_26_ERC2612/MyNFTV2.sol";

contract MyNFTV2Test is Test {
    MyNFTV2 public nft;
    address public owner;
    address public user;
    address public marketplace;
    uint256 private userPrivateKey;

    function setUp() public {
        // 部署NFT合约
        nft = new MyNFTV2();
        
        // 设置测试账户
        owner = address(this);
        userPrivateKey = 0x1234;  // 用户私钥
        user = vm.addr(userPrivateKey);  // 从私钥生成地址
        marketplace = address(0x999);
    }

    function testMintNFT() public {
        string memory uri = "https://example.com/token/1";
        uint256 tokenId = nft.mintNFT(user, uri);
        
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.tokenURI(tokenId), uri);
    }

    function testPermit() public {
        // 先铸造一个NFT给用户
        string memory uri = "https://example.com/token/1";
        uint256 tokenId = nft.mintNFT(user, uri);
        
        // 准备permit数据
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = nft.nonces(tokenId);
        
        // 构建permit签名数据
        bytes32 DOMAIN_SEPARATOR = nft.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                user,
                marketplace,
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
        
        // 使用用户私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
        
        // 切换到用户账户
        vm.startPrank(user);
        
        // 执行permit
        nft.permit(user, marketplace, tokenId, deadline, v, r, s);
        
        // 验证结果
        assertTrue(nft.isPermitted(tokenId));
        assertEq(nft.getPermitMarketplace(tokenId), marketplace);
        assertEq(nft.nonces(tokenId), 1);  // nonce应该增加
        assertEq(nft.getApproved(tokenId), marketplace);  // 应该被approve
        
        vm.stopPrank();
    }

    function testPermitExpired() public {
        // 先铸造一个NFT给用户
        string memory uri = "https://example.com/token/1";
        uint256 tokenId = nft.mintNFT(user, uri);
        
        // 设置当前时间
        vm.warp(100);  // 设置一个基准时间
        
        // 准备permit数据，设置已过期的deadline
        uint256 deadline = block.timestamp - 1;  // 确保是过期的
        uint256 nonce = nft.nonces(tokenId);
        
        // 构建permit签名数据
        bytes32 DOMAIN_SEPARATOR = nft.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                user,
                marketplace,
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
        
        // 使用用户私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
        
        // 切换到用户账户
        vm.startPrank(user);
        
        // 验证过期的permit应该失败
        vm.expectRevert("Permit: expired deadline");
        nft.permit(user, marketplace, tokenId, deadline, v, r, s);
        
        vm.stopPrank();
    }

    function testPermitInvalidSignature() public {
        string memory uri = "https://example.com/token/1";
        uint256 tokenId = nft.mintNFT(user, uri);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        // 使用错误的签名值
        uint8 v = 27;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);
        
        vm.startPrank(user);
        
        // 验证无效签名应该失败
        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignature()"));
        nft.permit(user, marketplace, tokenId, deadline, v, r, s);
        
        vm.stopPrank();
    }
}
