// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MyNFTV2 is ERC721, ERC721URIStorage {
    using ECDSA for bytes32;

    uint256 private _tokenIds = 1;  // 从1开始的计数器

    // 用于记录每个token的nonce
    mapping(uint256 => uint256) private _nonces;
    
    // 白名单映射：tokenId => spender(marketplace address)
    mapping(uint256 => address) public permitWhitelist;
    
    // 事件：记录白名单添加
    event WhitelistAdded(uint256 indexed tokenId, address indexed spender);

    // EIP712相关
    bytes32 public immutable DOMAIN_SEPARATOR;
    
    // 类型哈希常量
    bytes32 private constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)"
    );

    constructor() ERC721("MyNFT", "MNFT") {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("MyNFT")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    // function DOMAIN_SEPARATOR() external view returns (bytes32) {
    //     return DOMAIN_SEPARATOR;
    // }

    function mintNFT(address recipient, string memory uri) public returns (uint256) {
        uint256 newItemId = _tokenIds++;
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, uri);
        return newItemId;
    }

    /**
     * @dev 返回指定tokenId的当前nonce
     */
    function nonces(uint256 tokenId) public view returns (uint256) {
        return _nonces[tokenId];
    }

    /**
     * @dev 通过签名授权NFT并添加到白名单
     */
    function permit(
        address owner,
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit: expired deadline");
        require(owner == ownerOf(tokenId), "Permit: owner not match");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                tokenId,
                _nonces[tokenId],
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
        
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Permit: invalid signature");

        _nonces[tokenId]++;
        approve(spender, tokenId);
        
        permitWhitelist[tokenId] = spender;
        emit WhitelistAdded(tokenId, spender);
    }

    /**
     * @dev 查询指定tokenId的授权市场地址
     * @return address 返回授权的市场地址，如果未授权返回零地址
     */
    function getPermitMarketplace(uint256 tokenId) public view returns (address) {
        return permitWhitelist[tokenId];
    }

    /**
     * @dev 检查指定的tokenId是否已经授权
     * @return bool 如果已授权返回true，否则返回false
     */
    function isPermitted(uint256 tokenId) public view returns (bool) {
        return permitWhitelist[tokenId] != address(0);
    }


    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}