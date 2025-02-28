// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

// 继承ERC20Permit合约，实现ERC2612标准
// 主要是离线签名制度
contract MyERC2612 is ERC20Permit {
    constructor() ERC20("MyERC2612", "M2612") ERC20Permit("MyERC2612") {
        // 铸造100万枚代币给合约创建者
        _mint(msg.sender, 1_000_000 * 10**decimals());
    }
}
