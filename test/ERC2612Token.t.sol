// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MyERC2612} from "../src/2_26_ERC2612/ERC2612Token.sol";

contract ERC2612TokenTest is Test {
    MyERC2612 public token;
    address public owner;
    address public spender;
    uint256 public spenderPrivateKey;
    uint256 public ownerPrivateKey = 0xA11CE; // 定义 owner 的私钥
    
    error ERC2612ExpiredSignature(uint256 deadline);
    
    function setUp() public {
        // 创建测试账户
        spenderPrivateKey = 0xB0B;
        spender = vm.addr(spenderPrivateKey);
        owner = vm.addr(ownerPrivateKey);    // 使用这个私钥生成地址
        
        // 切换到 owner 账户后再部署合约
        vm.startPrank(owner);
        token = new MyERC2612();
        vm.stopPrank();
        
        // 设置初始时间戳
        vm.warp(10000);
    }

    function testInitialSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 * 10**18, "Initial supply should be 1M tokens");
        assertEq(token.balanceOf(owner), 1_000_000 * 10**18, "Owner should have all initial tokens");
    }

    function testPermit() public {
        uint256 amount = 1000 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(owner);

        // 构建permit签名数据
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );

        // 使用owner私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, permitHash);

        // 执行permit
        token.permit(owner, spender, amount, deadline, v, r, s);

        // 验证授权额度
        assertEq(token.allowance(owner, spender), amount, "Allowance not set correctly");
        assertEq(token.nonces(owner), 1, "Nonce should be incremented");
    }

    function test_RevertWhen_PermitExpired() public {
        uint256 amount = 1000 * 10**18;
        uint256 deadline = block.timestamp - 1 hours; // 已过期的deadline
        uint256 nonce = token.nonces(owner);

        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, permitHash);

        // 预期交易会因为deadline过期而失败
        vm.expectRevert(abi.encodeWithSelector(ERC2612ExpiredSignature.selector, deadline));
        token.permit(owner, spender, amount, deadline, v, r, s);
    }

    function testTransferAfterPermit() public {
        uint256 amount = 1000 * 10**18;
        
        // 先执行permit
        testPermit();
        
        // 切换到spender账户
        vm.startPrank(spender);
        
        // 使用transferFrom转移代币
        token.transferFrom(owner, spender, amount);
        
        // 验证余额变化
        assertEq(token.balanceOf(spender), amount, "Spender balance incorrect");
        assertEq(token.balanceOf(owner), 1_000_000 * 10**18 - amount, "Owner balance incorrect");
        
        vm.stopPrank();
    }
} 