// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../2_19_NFTMarket/MyToken.sol";
import "./MyNFTV2.sol";  // 导入支持permit的NFT合约

/**
 * @title NFTMarketV2
 * @dev NFT市场合约，支持普通授权和离线签名授权两种方式购买NFT
 * 继承了ReentrancyGuard防止重入攻击，实现了IERC721Receiver接口以接收NFT
 */
contract NFTMarketV2 is ReentrancyGuard, IERC721Receiver, ITokenReceiver {
    // 支付代币合约
    MyToken public immutable paymentToken;

    // NFT上架信息结构
    struct Listing {
        address nftContract;    // NFT合约地址
        uint256 tokenId;       // NFT的tokenId
        uint256 price;         // 价格
        address seller;        // 卖家地址
    }

    // 双重映射：NFT合约地址 => (tokenId => 上架信息)
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 事件声明
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address seller, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address seller, address buyer, uint256 price);
    event ListingCanceled(address indexed nftContract, uint256 indexed tokenId, address seller);

    constructor(address _paymentToken) {
        paymentToken = MyToken(_paymentToken);
    }

    /**
     * @dev 上架NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的tokenId
     * @param price 售价
     */
    function list(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the owner");
        
        require(listings[nftContract][tokenId].seller == address(0), "Already listed");
        
        // 检查NFT是否已授权给市场合约
        require(
            IERC721(nftContract).getApproved(tokenId) == address(this) ||
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)),
            "NFT not approved for marketplace"
        );
        
        listings[nftContract][tokenId] = Listing(nftContract, tokenId, price, msg.sender);
        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    /**
     * @dev 取消NFT上架
     * @param nftContract NFT合约地址
     * @param tokenId NFT的tokenId
     */
    function cancelListing(address nftContract, uint256 tokenId) external {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.seller != address(0), "Not listed");
        require(listing.seller == msg.sender, "Not the seller");
        
        delete listings[nftContract][tokenId];
        emit ListingCanceled(nftContract, tokenId, msg.sender);
    }

    /**
     * @dev 通过普通授权购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的tokenId
     */
    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.seller != address(0), "NFT not listed");
        require(listing.seller != msg.sender, "Cannot buy own NFT");
        
        // 使用transferWithCallback进行支付，触发回调进行NFT转移
        bool success = paymentToken.transferWithCallback(
            msg.sender,
            address(this),
            listing.price,
            abi.encode(nftContract, tokenId)
        );
        require(success, "Token transfer failed");
    }

    // 定义Permit结构体来组织签名数据
    struct PermitData {
        address owner;
        address spender;
        uint256 tokenId;
        uint256 nonce;
        uint256 deadline;
    }

    /**
     * @dev 通过离线签名授权购买NFT
     * @param nftContract NFT合约地址
     * @param data permit相关的数据
     * @param v 签名的v值
     * @param r 签名的r值
     * @param s 签名的s值
     */
    function permitBuy(
        address nftContract,
        PermitData calldata data,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        // 从listings中获取NFT信息
        Listing memory listing = listings[nftContract][data.tokenId];
        require(listing.seller != address(0), "NFT not listed");
        require(listing.seller == data.owner, "Not the seller");
        
        // 获取NFT合约实例
        MyNFTV2 nft = MyNFTV2(nftContract);
        
        require(block.timestamp <= data.deadline, "Permit expired");
        require(data.spender == address(this), "Invalid spender");  // spender必须是市场合约地址
        require(nft.nonces(data.tokenId) == data.nonce, "Invalid nonce");

        // 验证签名
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                nft.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                        data.owner,
                        data.spender,
                        data.tokenId,
                        data.nonce,
                        data.deadline
                    )
                )
            )
        );

        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0) && signer == data.owner, "Invalid signature");

        // 使用transferWithCallback进行支付，触发回调进行NFT转移
        bool success = paymentToken.transferWithCallback(
            msg.sender,
            address(this),
            listing.price,
            abi.encode(nftContract, data.tokenId)
        );
        require(success, "Token transfer failed");
    }

    /**
     * @dev 代币转账回调函数，处理NFT转移
     * @param operator 买家地址
     * @param amount 支付金额
     * @param data 编码的NFT信息
     * @return bool 是否处理成功
     */
    function tokensReceived(
        address operator,
        address /*from*/,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(msg.sender == address(paymentToken), "Invalid token");
        
        // 解码NFT信息
        (address nftContract, uint256 tokenId) = abi.decode(data, (address, uint256));
        
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.seller != address(0), "NFT not listed");
        require(listing.price == amount, "Incorrect payment amount");
        require(listing.seller != operator, "Cannot buy own NFT");

        // 清除上架信息
        delete listings[nftContract][tokenId];
        // 转移代币给卖家
        paymentToken.transfer(listing.seller, amount);
        // 转移NFT给买家
        IERC721(nftContract).transferFrom(listing.seller, operator, tokenId);
        
        emit NFTSold(nftContract, tokenId, listing.seller, operator, amount);
        return true;
    }

    /**
     * @dev 实现IERC721Receiver接口，使合约能够接收NFT
     */
    function onERC721Received(      
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}