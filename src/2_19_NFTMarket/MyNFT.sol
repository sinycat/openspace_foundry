// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// 相同部署 https://sepolia.etherscan.io/address/0x9acf0d0dcf0419fe2592b756626acede483b0e3a
contract MyNFT is ERC721URIStorage {
    uint256 private _tokenIds = 1;  // 从1开始的计数器

    constructor() ERC721("MyNFT", "MNFT") {}

    function mintNFT(address recipient, string memory tokenURI) public returns (uint256) {
        uint256 newItemId = _tokenIds++;
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }
}