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
        // Multisig Owner Wallet Address
        address owner = 0x09234f69C3400216eB624326669B76bec3dB39C3;
        // Multisig Token 1 Wallet Address
        address adminOne = 0x4E9Ff90564C9D6B89d63197A0034c09A50e53190;
        // Multisig Token 2 Wallet Address
        address adminTwo = 0x08D8B7852a03e775BE9C0D2137A59E417A4B3e5B;
        // Multisig Token 3 Wallet Address
        address adminThree = 0x062f6869e5FC2f56f52a817eAd98c1d6576412F4;
        // Multisig Minter Wallet Address
        address minter = 0x09234f69C3400216eB624326669B76bec3dB39C3;

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
