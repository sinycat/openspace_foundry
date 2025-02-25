// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    // 多签持有者列表
    address[] public owners;
    // 签名门槛 通过人数
    uint public required;
    // 交易结构体
    struct Transaction {
        address to; // 目标地址
        uint value; // 转账金额
        bytes data; // 调用数据
        bool executed; // 是否已执行
        uint confirmCount; // 当前确认数
    }
    // 交易列表
    Transaction[] public transactions;
    // 确认状态映射: transactionId => owner => bool
    mapping(uint => mapping(address => bool)) public confirmations;
    // 判断地址是否为owner的映射
    mapping(address => bool) public isOwner;

    // 事件
    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(
        uint indexed transactionId,
        address indexed owner,
        address to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(uint indexed transactionId, address indexed owner);
    event ExecuteTransaction(uint indexed transactionId);

    // 修饰符：仅限多签持有者
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    // 修饰符：验证交易是否存在
    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }

    // 修饰符：交易未执行
    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    // 修饰符：未确认过
    modifier notConfirmed(uint _txId) {
        require(
            !confirmations[_txId][msg.sender],
            "Transaction already confirmed"
        );
        _;
    }

    // 构造函数：初始化多签持有者和签名门槛
    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "Owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "Invalid required number of owners"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    // 接收ETH存款
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // 提交新交易提案
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner returns (uint transactionId) {
        transactionId = transactions.length;
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmCount: 0
            })
        );
        emit SubmitTransaction(transactionId, msg.sender, _to, _value, _data);
        return transactionId;
    }

    // 确认交易
    function confirmTransaction(
        uint _txId
    ) public onlyOwner txExists(_txId) notExecuted(_txId) notConfirmed(_txId) {
        confirmations[_txId][msg.sender] = true;
        transactions[_txId].confirmCount++;
        emit ConfirmTransaction(_txId, msg.sender);
    }

    // 执行交易
    function executeTransaction(
        uint _txId
    ) public txExists(_txId) notExecuted(_txId) {
        Transaction storage txn = transactions[_txId];
        require(txn.confirmCount >= required, "Not enough confirmations");

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");

        txn.executed = true; // 移到调用成功后
        emit ExecuteTransaction(_txId);
    }

    // 获取交易详情
    function getTransaction(
        uint _txId
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint confirmCount
        )
    {
        Transaction memory txn = transactions[_txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmCount);
    }

    // 获取owner列表
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // 撤销确认
    function revokeConfirmation(
        uint _txId
    ) public onlyOwner txExists(_txId) notExecuted(_txId) {
        require(confirmations[_txId][msg.sender], "Transaction not confirmed");
        confirmations[_txId][msg.sender] = false;
        transactions[_txId].confirmCount--;
    }

    // 获取交易的确认状态
    function isConfirmed(
        uint _txId,
        address _owner
    ) public view returns (bool) {
        return confirmations[_txId][_owner];
    }
}
