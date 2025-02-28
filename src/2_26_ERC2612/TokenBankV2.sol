// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// 使用ERC2612标准进行存款和提款
// permitDeposit方法 离线签名存款
contract TokenBank is ReentrancyGuard, Ownable {
    // 使用两个接口来访问同一个合约
    IERC20Permit public immutable tokenPermit;
    IERC20 public immutable token;

    // 用户存款余额映射
    mapping(address => uint256) public balances;

    // 总存款量
    uint256 public totalDeposits;

    // 事件声明
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // 定义Permit结构体来组织签名数据
    struct PermitData {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "Token address cannot be zero");
        tokenPermit = IERC20Permit(_token);
        token = IERC20(_token);
    }

    /**
     * @notice 使用已签名的EIP2612 permit数据进行存款
     * @param data permit相关的数据
     * @param v 签名的v值
     * @param r 签名的r值
     * @param s 签名的s值
     */
    function permitDeposit(
        PermitData calldata data,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        require(data.value > 0, "Amount must be greater than 0");
        require(block.timestamp <= data.deadline, "Permit expired");
        require(data.spender == address(this), "Invalid spender");
        require(data.nonce == tokenPermit.nonces(data.owner), "Invalid nonce");

        // 验证签名
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                tokenPermit.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        data.owner,
                        data.spender,
                        data.value,
                        data.nonce,
                        data.deadline
                    )
                )
            )
        );

        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0) && signer == data.owner, "Invalid signature");

        // 验证通过后执行转账
        require(token.transferFrom(data.owner, address(this), data.value), "Transfer failed");

        // 更新余额
        balances[data.owner] += data.value;
        totalDeposits += data.value;

        emit Deposit(data.owner, data.value);
    }

    /**
     * @notice 提取代币
     * @param _amount 提取金额
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // 更新用户余额和总存款
        balances[msg.sender] -= _amount;
        totalDeposits -= _amount;

        // 转移代币给用户
        require(token.transfer(msg.sender, _amount), "Transfer failed");

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice 查询用户余额
     * @param _user 用户地址
     */
    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }
}
