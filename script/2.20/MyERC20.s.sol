// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import {MyERC20} from "../src/MyERC20.sol";


contract MyERC20Script is Script {
    MyERC20 public myERC20;

    function setUp() public { }

    function run() public {

        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey); 

        MyERC20 myerc20 = new MyERC20("MyERC20", "METT");
        vm.stopBroadcast(); 

        console.log("Counter deployed to:", address(myerc20));
        console.log("Total supply:", myerc20.totalSupply());
        console.log("Deployer:", msg.sender);
    }
}