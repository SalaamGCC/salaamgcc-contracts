// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SalaamGcc } from "../src/token/SalaamGcc.sol";

contract SalaamGccScript is Script {
    function test() public {}
    function run() public {
        // Retrieve deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = 0x094947f5F7439D6FBDe3228a099D59E52b79A715;
        address adminOne = 0xB75D71adFc8E5F7c58eA89c22C3B70BEA84A718d;
        address adminTwo = 0xfDcDF3cFa272c67C17824FC792C9fF798C98eDed;
        address adminThree = 0x094947f5F7439D6FBDe3228a099D59E52b79A715;
        address minter = 0x094947f5F7439D6FBDe3228a099D59E52b79A715;

        // Start broadcasting transactions using the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract (SalaamGcc)
        SalaamGcc implementation = new SalaamGcc();

        // Encode the initialization data
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [adminOne, adminTwo, adminThree],
            minter
        );

        // Deploy the proxy with the implementation address and initialization data
        TransparentUpgradeableProxy proxyContract = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            data
        );

        vm.stopBroadcast();

        console.log("Deployment successful!");
        console.log("Proxy Contract Address: ", address(proxyContract));
        console.log("Implementation Contract Address: ", address(implementation));
    }
}
