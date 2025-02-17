// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { SalaamGcc } from "../src/token/SalaamGcc.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BaseTest is Test {
    SalaamGcc public sampleToken;
    address public owner;
    address public minter;
    address public adminOne;
    address public adminTwo;
    address public adminThree;
    address public nonAdmin;

    error EnforcedPause();

    function test() public virtual {}

    function setUp() public virtual {
        owner = address(0x1);
        minter = address(0x2);
        adminOne = address(0x3);
        adminTwo = address(0x4);
        adminThree = address(0x5);
        nonAdmin = address(0x6);

        vm.startPrank(owner);
        SalaamGcc implementation = new SalaamGcc();
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [adminOne, adminTwo, adminThree],
            minter
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementation), owner, data);
        sampleToken = SalaamGcc(address(proxy));
        vm.label(address(sampleToken), "sampleToken");
        vm.stopPrank();

        vm.prank(minter);
        sampleToken.mint(owner, 20000 ether);
    }
}
