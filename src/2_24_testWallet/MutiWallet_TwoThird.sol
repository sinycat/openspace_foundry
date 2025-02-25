// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 引入 OpenZeppelin 的 IERC20 接口
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MultiSigWallet {
    // 多签持有者列表，固定为 3 个
    address[3] public owners;
    // 签名门槛，固定为 2
    uint public constant required = 2;
    // 交易结构体
    struct Transaction {
        address to;          // 目标地址
        uint value;         // 转账金额（ETH）
        bytes data;         // 调用数据
        bool executed;      // 是否已执行
        uint confirmCount;  // 当前确认数
    }
    // 交易列表
    Transaction[] public transactions;
    // 确认状态映射: transactionId => owner => bool
    mapping(uint => mapping(address => bool)) public confirmations;
    // 判断地址是否为 owner 的映射
    mapping(address => bool) public isOwner;

    // 事件
    event Deposit(address indexed sender, uint amount);
    event DepositToken(address indexed token, address indexed sender, uint amount);
    event SubmitTransaction(uint indexed transactionId, address indexed owner, address to, uint value, bytes data);
    event ConfirmTransaction(uint indexed transactionId, address indexed owner);
    event ExecuteTransaction(uint indexed transactionId);
    
    // 修饰符：仅限多签持有者
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    
    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }
    
    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }
    
    modifier notConfirmed(uint _txId) {
        require(!confirmations[_txId][msg.sender], "Transaction already confirmed");
        _;
    }

    // 构造函数：初始化 3 个多签持有者，门槛固定为 2
    constructor(address[3] memory _owners) {
        require(_owners[0] != address(0) && _owners[1] != address(0) && _owners[2] != address(0), "Invalid owner");
        require(_owners[0] != _owners[1] && _owners[1] != _owners[2] && _owners[0] != _owners[2], "Owners must be unique");

        for (uint i = 0; i < 3; i++) {
            isOwner[_owners[i]] = true;
            owners[i] = _owners[i];
        }
    }

    // 接收 ETH 存款
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // 存入 ERC20 代币
    function depositToken(address _token, uint _amount) external {
        require(_token != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater than 0");
        
        IERC20 token = IERC20(_token);
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        emit DepositToken(_token, msg.sender, _amount);
    }

    // 提交新交易提案
    function submitTransaction(address _to, uint _value, bytes memory _data) 
        public 
        onlyOwner 
        returns (uint transactionId) 
    {
        transactionId = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmCount: 0
        }));
        emit SubmitTransaction(transactionId, msg.sender, _to, _value, _data);
        return transactionId;
    }

    // 确认交易
    function confirmTransaction(uint _txId) 
        public 
        onlyOwner 
        txExists(_txId) 
        notExecuted(_txId) 
        notConfirmed(_txId) 
    {
        confirmations[_txId][msg.sender] = true;
        transactions[_txId].confirmCount++;
        emit ConfirmTransaction(_txId, msg.sender);
    }

    // 执行交易（改进版本：调用成功后再标记）
    function executeTransaction(uint _txId) 
        public 
        txExists(_txId) 
        notExecuted(_txId) 
    {
        Transaction storage txn = transactions[_txId];
        require(txn.confirmCount >= required, "Not enough confirmations");
        
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");
        
        txn.executed = true;
        emit ExecuteTransaction(_txId);
    }

    // 获取交易详情
    function getTransaction(uint _txId) 
        public 
        view 
        returns (address to, uint value, bytes memory data, bool executed, uint confirmCount) 
    {
        Transaction memory txn = transactions[_txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmCount);
    }

    // 获取 owner 列表
    function getOwners() public view returns (address[3] memory) {
        return owners;
    }

    // 查询合约中 ERC20 代币余额
    function getTokenBalance(address _token) public view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }
}