// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 增加 tokensReceived 函数，用于接收带回调的 Token 转账
// 可存多种代币
// 导入 ERC20 接口
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

// 添加 Token 接收者接口
interface ITokenReceiver {
    function tokensReceived(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract TokenBank is ITokenReceiver {
    // 记录每个用户在每个代币合约中的存款余额
    mapping(address => mapping(address => uint256)) public balances;
    
    // 存款事件
    event Deposit(address indexed user, address indexed token, uint256 amount);
    // 提款事件
    event Withdrawal(address indexed user, address indexed token, uint256 amount);
    
    // 实现 tokensReceived 接口，用于接收带回调的 Token 转账
    function tokensReceived(
        address /* operator */,  // 使用注释标记未使用的参数
        address from,
        uint256 amount,
        bytes calldata /* data */  // 使用注释标记未使用的参数
    ) external override returns (bool) {
        // 更新用户在该代币的存款余额
        balances[from][msg.sender] += amount;
        
        // 触发存款事件
        emit Deposit(from, msg.sender, amount);
        
        return true;
    }
    
    // 原有存款函数保持不变，用于普通 ERC20 存款
    function deposit(address _tokenAddress, uint256 _amount) external {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater than 0");
        
        IERC20 token = IERC20(_tokenAddress);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(token.transferFrom(msg.sender, address(this), _amount), "transferFrom failed");
        
        balances[msg.sender][_tokenAddress] += _amount;
        emit Deposit(msg.sender, _tokenAddress, _amount);
    }
    
    // 提款函数
    function withdraw(address _tokenAddress, uint256 _amount) external {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender][_tokenAddress] >= _amount, "withdraw Insufficient balance");
        
        IERC20 token = IERC20(_tokenAddress);
        balances[msg.sender][_tokenAddress] -= _amount;
        require(token.transfer(msg.sender, _amount), "withdraw failed");
        
        emit Withdrawal(msg.sender, _tokenAddress, _amount);
    }
    
    // 查询用户在特定代币合约中的存款余额
    function getBalance(address _user, address _tokenAddress) external view returns (uint256) {
        return balances[_user][_tokenAddress];
    }
    
    // 查询合约中特定代币的总量
    function getTotalBalance(address _tokenAddress) external view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress);
        return token.balanceOf(address(this));
    }
}