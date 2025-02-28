// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MyERC2612} from "../src/2_26_ERC2612/ERC2612Token.sol";
import {TokenBank} from "../src/2_26_ERC2612/TokenBankV2.sol";

contract TokenBankV2Test is Test {
    MyERC2612 public token;
    TokenBank public bank;
    
    address public owner;
    address public user;
    uint256 public userPrivateKey;
    
    // 测试前的设置
    function setUp() public {
        // 创建测试账户
        userPrivateKey = 0xA11CE;
        user = vm.addr(userPrivateKey);
        owner = address(this);
        
        // 部署合约
        vm.startPrank(owner);  // 确保以 owner 身份部署代币合约
        token = new MyERC2612();
        bank = new TokenBank(address(token));
        vm.stopPrank();
        
        // 给测试用户转一些代币
        token.transfer(user, 1000 * 10**18);
    }
    
    // 测试permit存款功能
    function testPermitDeposit() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 1. 先执行 permit
        {
            uint256 nonce = token.nonces(user);
            bytes32 permitHash = _getPermitHash(
                user,
                address(bank),
                depositAmount,
                nonce,
                deadline
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);
            
            vm.startPrank(user);
            token.permit(user, address(bank), depositAmount, deadline, v, r, s);
        }
        
        // 2. 然后执行 permitDeposit
        {
            uint256 newNonce = token.nonces(user);
            bytes32 newPermitHash = _getPermitHash(
                user,
                address(bank),
                depositAmount,
                newNonce,
                deadline
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, newPermitHash);
            
            uint256 initialUserBalance = token.balanceOf(user);
            uint256 initialBankBalance = token.balanceOf(address(bank));
            
            TokenBank.PermitData memory permitData = TokenBank.PermitData({
                owner: user,
                spender: address(bank),
                value: depositAmount,
                deadline: deadline,
                nonce: newNonce
            });
            
            bank.permitDeposit(permitData, v, r, s);
            
            assertEq(token.balanceOf(user), initialUserBalance - depositAmount);
            assertEq(token.balanceOf(address(bank)), initialBankBalance + depositAmount);
            assertEq(bank.balances(user), depositAmount);
        }
        
        vm.stopPrank();
    }
    
    // 辅助函数，用于生成 permit hash
    function _getPermitHash(
        address ownerAddress,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        ownerAddress,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
    }
    
    // 测试提款功能
    function testWithdraw() public {
        // 先存款
        testPermitDeposit();
        
        uint256 withdrawAmount = 50 * 10**18;
        
        // 切换到用户账户
        vm.startPrank(user);
        
        // 记录初始余额
        uint256 initialUserBalance = token.balanceOf(user);
        uint256 initialBankBalance = token.balanceOf(address(bank));
        uint256 initialBankRecordedBalance = bank.balances(user);
        
        // 执行提款
        bank.withdraw(withdrawAmount);
        
        // 验证余额变化
        assertEq(token.balanceOf(user), initialUserBalance + withdrawAmount, "User balance not increased correctly");
        assertEq(token.balanceOf(address(bank)), initialBankBalance - withdrawAmount, "Bank balance not decreased correctly");
        assertEq(bank.balances(user), initialBankRecordedBalance - withdrawAmount, "Bank recorded balance not decreased correctly");
        
        vm.stopPrank();
    }
    
    // 测试提款金额超过余额的情况
    function test_RevertWhen_WithdrawInsufficientBalance() public {
        // 先存款
        testPermitDeposit();
        
        vm.startPrank(user);
        // 尝试提取超过存款金额的代币
        vm.expectRevert("Insufficient balance");
        bank.withdraw(150 * 10**18);
        vm.stopPrank();
    }
}
