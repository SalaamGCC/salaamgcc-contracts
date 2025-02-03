// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { SalaamGcc } from "../../src/token/SalaamGcc.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SalaamGccTest is Test {
    SalaamGcc private token;
    address private owner;
    address private minter;
    address private adminOne;
    address private adminTwo;
    address private adminThree;
    address private nonAdmin;

    function setUp() public {
        owner = address(0x1);
        minter = address(0x2);
        adminOne = address(0x3);
        adminTwo = address(0x4);
        adminThree = address(0x5);
        nonAdmin = address(0x6);

        vm.prank(owner);
        SalaamGcc implementation = new SalaamGcc();
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [adminOne, adminTwo, adminThree],
            minter
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementation), owner, data);
        token = SalaamGcc(address(proxy));
        vm.label(address(token), "token");
    }

    function testInitialization() public view {
        assertEq(token.owner(), owner);
        assertTrue(token.hasRole(token.ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), adminOne));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), adminTwo));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), adminThree));
    }

    function testMintingByMinter() public {
        uint256 amount = 1000 ether;
        vm.prank(minter);
        token.mint(owner, amount);
        assertEq(token.balanceOf(owner), amount);
    }

    function testChangeMinterByOwner() public {
        address newMinter = address(0x7);
        vm.prank(owner);
        token.setMinter(newMinter);
        vm.prank(newMinter);
        token.mint(owner, 1000 ether);
        assertEq(token.balanceOf(owner), 1000 ether);
    }

    function testChangeMinterWithInvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        token.setMinter(address(0));
    }

    function testPauseAndUnpauseByAdmin() public {
        vm.prank(adminOne);
        token.pause();
        vm.expectRevert(SalaamGcc.ContractPaused.selector);
        vm.prank(minter);
        token.mint(owner, 1000 ether);
        vm.prank(adminOne);
        token.unpause();
        vm.prank(minter);
        token.mint(owner, 1000 ether);
    }

    function testPausedTransfers() public {
        vm.prank(adminOne);
        token.pause();
        vm.expectRevert(SalaamGcc.ContractPaused.selector);
        vm.prank(owner);
        token.transfer(address(0x9), 100 ether);
    }

    function testUnpausedTransfers() public {
        uint256 amount = 1000 ether;
        vm.prank(minter);
        token.mint(owner, amount);
        vm.prank(owner);
        token.transfer(address(0x9), 500 ether);
        assertEq(token.balanceOf(address(0x9)), 500 ether);
    }

    function testOwnershipTransfer() public {
        address newOwner = address(0x8);
        vm.prank(owner);
        token.transferOwnership(newOwner);
        assertEq(token.owner(), newOwner);
    }

    function testPausedMinting() public {
        vm.startPrank(adminOne);
        token.pause();
        vm.stopPrank();
        vm.startPrank(minter);
        vm.expectRevert(SalaamGcc.ContractPaused.selector);
        token.mint(owner, 1000 ether);
        vm.stopPrank();
    }

    function testUnpausedMinting() public {
        vm.startPrank(minter);
        token.mint(owner, 1000 ether);
        assertEq(token.balanceOf(owner), 1000 ether);
        vm.stopPrank();
    }

    function testMintingAfterPauseAndUnpause() public {
        vm.prank(adminOne);
        token.pause();
        vm.prank(minter);
        vm.expectRevert(SalaamGcc.ContractPaused.selector);
        token.mint(owner, 1000 ether);
        vm.prank(adminOne);
        token.unpause();
        vm.prank(minter);
        token.mint(owner, 1000 ether);
        assertEq(token.balanceOf(owner), 1000 ether);
    }
}
