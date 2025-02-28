// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 相同部署 https://sepolia.etherscan.io/address/0x41c9cd4b90ed940c29269b2ea133a41d556fa8c7
interface ITokenReceiver {
    function tokensReceived(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function transferWithCallback(
        address operator,
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf(operator) >= amount, "Insufficient balance");

        // 先执行转账
        _transfer(operator, to, amount);

        // 调用接收方的回调
        bool success = ITokenReceiver(to).tokensReceived(
            operator, // operator
            to, // from
            amount,
            data
        );
        require(success, "Callback failed");

        return true;
    }
}
