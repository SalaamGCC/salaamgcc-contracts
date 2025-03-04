// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Test } from "forge-std/Test.sol";
import { SalaamGcc } from "../../src/token/SalaamGcc.sol";
import { SalaamGccV2 } from "./mock/SalaamGccV2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20CappedUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { console } from "forge-std/console.sol";

contract SalaamGccTest is Test {
    SalaamGcc token;
    address v2Address;

    address owner = address(0x1);
    address minter = address(0x2);
    address aliceAdmin = address(0x3);
    address bobAdmin = address(0x4);
    address oscarAdmin = address(0x5);
    address charlie = address(0x6);
    address newMinter = address(0x7);
    address newOwner = address(0x8);

    string tokenName = "SalaamGCC";
    string symbol = "SGCC";
    uint256 tokenDecimals = 18;
    uint256 tokenCap = 6000000000 ether;

    bytes32 adminRole = keccak256("ADMIN_ROLE");
    bytes32 superAdminRole = keccak256("SUPER_ADMIN_ROLE");

    uint256 amount = 1000 ether;
    uint256 exceedCapAmount = 600000000000 ether;

    event MinterChanged(address indexed oldMinter, address indexed newMinter);

    function test() public {}

    function setUp() external {
        owner = address(0x1);
        minter = address(0x2);
        aliceAdmin = address(0x3);
        bobAdmin = address(0x4);
        oscarAdmin = address(0x5);
        charlie = address(0x6);
        newMinter = address(0x7);

        vm.prank(owner);
        SalaamGcc implementation = new SalaamGcc();
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [aliceAdmin, bobAdmin, oscarAdmin],
            minter
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementation), owner, data);
        token = SalaamGcc(address(proxy));
        vm.label(address(token), "token");
    }
}
contract TokenDeploymentTest is SalaamGccTest {
    function test_Deployment_Succeeds() external view {
        assertEq(token.owner(), owner);
        assertTrue(token.hasRole(token.SUPER_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), aliceAdmin));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), bobAdmin));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), oscarAdmin));
        assertEq(token.name(), tokenName);
        assertEq(token.symbol(), symbol);
        assertEq(token.decimals(), tokenDecimals);
        assertEq(token.totalSupply(), 0);
        assertEq(token.cap(), tokenCap);
        assertEq(token.paused(), false);
        assertEq(token.pendingOwner(), address(0));
        assertEq(token.ADMIN_ROLE(), adminRole);
        assertEq(token.SUPER_ADMIN_ROLE(), superAdminRole);
    }

    function test_Deployment_ZeroAddress_Reverts() external {
        SalaamGcc implementation = new SalaamGcc();
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            address(0),
            [aliceAdmin, bobAdmin, oscarAdmin],
            minter
        );
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        new TransparentUpgradeableProxy(address(implementation), owner, data);

        SalaamGcc implementation_2 = new SalaamGcc();
        bytes memory data_2 = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [address(0), bobAdmin, oscarAdmin],
            minter
        );
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        new TransparentUpgradeableProxy(address(implementation_2), owner, data_2);

        SalaamGcc implementation_3 = new SalaamGcc();
        bytes memory data_3 = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [aliceAdmin, address(0), oscarAdmin],
            minter
        );
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        new TransparentUpgradeableProxy(address(implementation_3), owner, data_3);

        SalaamGcc implementation_4 = new SalaamGcc();
        bytes memory data_4 = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [aliceAdmin, bobAdmin, address(0)],
            minter
        );
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        new TransparentUpgradeableProxy(address(implementation_4), owner, data_4);

        SalaamGcc implementation_5 = new SalaamGcc();
        bytes memory data_5 = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [address(0), address(0), address(0)],
            minter
        );
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        new TransparentUpgradeableProxy(address(implementation_5), owner, data_5);

        SalaamGcc implementation_6 = new SalaamGcc();
        bytes memory data_6 = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            owner,
            [aliceAdmin, bobAdmin, oscarAdmin],
            address(0)
        );
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        new TransparentUpgradeableProxy(address(implementation_6), owner, data_6);

        SalaamGcc implementation_7 = new SalaamGcc();
        bytes memory data_7 = abi.encodeWithSignature(
            "initialize(address,address[3],address)",
            address(0),
            [address(0), address(0), address(0)],
            address(0)
        );
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        new TransparentUpgradeableProxy(address(implementation_7), owner, data_7);
    }
}

contract MintTest is SalaamGccTest {
    function test_Mint_MinterMint_Succeeds() external {
        vm.prank(minter);
        token.mint(owner, amount);
        assertEq(token.balanceOf(owner), amount);
    }

    function test_Mint_ExceedCap_Reverts() external {
        vm.prank(minter);
        vm.expectRevert();
        token.mint(owner, exceedCapAmount);
    }

    function test_Mint_NonMinterMint_Reverts() public {
        vm.prank(owner);
        vm.expectRevert();
        token.mint(owner, amount);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.mint(owner, amount);

        vm.prank(aliceAdmin);
        vm.expectRevert();
        token.mint(owner, amount);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.mint(owner, amount);

        vm.prank(charlie);
        vm.expectRevert();
        token.mint(owner, amount);
    }

    function test_Mint_ZeroAmount_Reverts() external {
        uint256 amount = 0;
        vm.prank(minter);
        vm.expectRevert();
        token.mint(owner, amount);
    }

    function test_Mint_ZeroAddress_Reverts() external {
        vm.prank(minter);
        vm.expectRevert();
        token.mint(address(0), amount);
    }
}

contract SetMinterTest is SalaamGccTest {
    function test_SetMinter_OwnerSet_Succeeds() external {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit MinterChanged(minter, newMinter);
        token.setMinter(newMinter);
        vm.prank(newMinter);
        token.mint(owner, 1000 ether);
        assertEq(token.balanceOf(owner), 1000 ether);
    }

    function test_SetMinter_NonOwnerSet_Reverts() external {
        vm.prank(minter);
        vm.expectRevert();
        token.setMinter(owner);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.setMinter(bobAdmin);

        vm.prank(aliceAdmin);
        vm.expectRevert();
        token.setMinter(aliceAdmin);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.setMinter(oscarAdmin);

        vm.prank(charlie);
        vm.expectRevert();
        token.setMinter(charlie);
    }

    function test_SetMinter_ZeroAddress_Reverts() external {
        vm.prank(owner);
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        token.setMinter(address(0));
    }

    function test_SetMinter_SameMinter_Reverts() external {
        vm.prank(owner);
        vm.expectRevert(SalaamGcc.InvalidAddress.selector);
        token.setMinter(minter);
    }
}

contract PauseTest is SalaamGccTest {
    function test_Pause_AdminPause_Succeeds() external {
        vm.prank(aliceAdmin);
        token.pause();
        assertEq(token.paused(), true);

        vm.prank(minter);
        vm.expectRevert();
        token.mint(oscarAdmin, amount);
    }

    function test_Pause_NonAdminPause_Reverts() external {
        vm.prank(charlie);
        vm.expectRevert();
        token.pause();
    }

    function test_Pause_Mint_Reverts() external {
        vm.prank(aliceAdmin);
        token.pause();

        vm.prank(minter);
        vm.expectRevert();
        token.mint(minter, amount);

        vm.prank(owner);
        vm.expectRevert();
        token.mint(owner, amount);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.mint(owner, amount);

        vm.prank(charlie);
        vm.expectRevert();
        token.mint(bobAdmin, amount);
    }

    function test_Pause_Transfer_Reverts() external {
        vm.startBroadcast(minter);
        token.mint(owner, amount);
        token.mint(bobAdmin, amount);
        token.mint(aliceAdmin, amount);
        token.mint(oscarAdmin, amount);
        token.mint(charlie, amount);
        vm.stopBroadcast();

        vm.prank(aliceAdmin);
        token.pause();

        vm.prank(owner);
        vm.expectRevert();
        token.transfer(oscarAdmin, amount);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.transfer(aliceAdmin, amount);

        vm.prank(aliceAdmin);
        vm.expectRevert();
        token.transfer(oscarAdmin, amount);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.transfer(bobAdmin, amount);

        vm.prank(charlie);
        vm.expectRevert();
        token.transfer(charlie, amount);
    }
}

contract UnpauseTest is SalaamGccTest {
    function test_Unpaused_AdminUnpause_Succeeds() external {
        vm.prank(aliceAdmin);
        token.pause();
        assertEq(token.paused(), true);

        vm.prank(bobAdmin);
        token.unpause();
        assertEq(token.paused(), false);
    }

    function test_UnPaused_Mint_Succeeds() external {
        vm.prank(bobAdmin);
        token.pause();
        assertEq(token.paused(), true);

        vm.prank(aliceAdmin);
        token.unpause();
        assertEq(token.paused(), false);

        vm.prank(minter);
        token.mint(oscarAdmin, amount);
        assertEq(token.balanceOf(oscarAdmin), amount);
    }

    function test_Unpaused_Transfer_Succeeds() external {
        vm.prank(bobAdmin);
        token.pause();
        assertEq(token.paused(), true);

        vm.prank(aliceAdmin);
        token.unpause();
        assertEq(token.paused(), false);

        vm.prank(minter);
        token.mint(oscarAdmin, amount);
        assertEq(token.balanceOf(oscarAdmin), amount);

        vm.prank(oscarAdmin);
        token.transfer(aliceAdmin, amount);
        assertEq(token.balanceOf(oscarAdmin), 0);
        assertEq(token.balanceOf(aliceAdmin), amount);

        vm.prank(aliceAdmin);
        token.transfer(bobAdmin, amount);
        assertEq(token.balanceOf(aliceAdmin), 0);
        assertEq(token.balanceOf(bobAdmin), amount);

        vm.prank(bobAdmin);
        token.transfer(owner, amount);
        assertEq(token.balanceOf(bobAdmin), 0);
        assertEq(token.balanceOf(owner), amount);

        vm.prank(owner);
        token.transfer(charlie, amount);
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(charlie), amount);
    }

    function test_Unpause_NonAdminUnpause_Reverts() external {
        vm.prank(aliceAdmin);
        token.pause();
        vm.prank(charlie);

        vm.expectRevert();
        token.unpause();
    }
}

contract OwnershipTest is SalaamGccTest {
    function test_Ownership_Transfer_Succeeds() external {
        vm.prank(owner);
        token.transferOwnership(newOwner);
        assertEq(token.owner(), owner);
        assertEq(token.pendingOwner(), newOwner);

        vm.prank(newOwner);
        token.acceptOwnership();
        assertEq(token.owner(), newOwner);
    }

    function test_Ownership_Renounce_Succeeds() external {
        vm.prank(owner);
        token.renounceOwnership();

        assertEq(token.owner(), address(0));
    }

    function test_Ownership_Transfer_Reverts() external {
        vm.prank(bobAdmin);
        vm.expectRevert();
        token.transferOwnership(newOwner);
        assertEq(token.owner(), owner);

        vm.prank(aliceAdmin);
        vm.expectRevert();
        token.transferOwnership(newOwner);
        assertEq(token.owner(), owner);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.transferOwnership(newOwner);
        assertEq(token.owner(), owner);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.transferOwnership(newOwner);
        assertEq(token.owner(), owner);

        vm.prank(charlie);
        vm.expectRevert();
        token.transferOwnership(newOwner);
        assertEq(token.owner(), owner);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.acceptOwnership();
        assertEq(token.owner(), owner);

        vm.prank(aliceAdmin);
        vm.expectRevert();
        token.acceptOwnership();
        assertEq(token.owner(), owner);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.acceptOwnership();
        assertEq(token.owner(), owner);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.acceptOwnership();
        assertEq(token.owner(), owner);

        vm.prank(charlie);
        vm.expectRevert();
        token.acceptOwnership();
        assertEq(token.owner(), owner);
    }

    function test_Ownership_Renounce_Reverts() external {
        vm.prank(bobAdmin);
        vm.expectRevert();
        token.renounceOwnership();
        assertEq(token.owner(), owner);

        vm.prank(aliceAdmin);
        vm.expectRevert();
        token.renounceOwnership();
        assertEq(token.owner(), owner);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.renounceOwnership();
        assertEq(token.owner(), owner);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.renounceOwnership();
        assertEq(token.owner(), owner);

        vm.prank(charlie);
        vm.expectRevert();
        token.renounceOwnership();
        assertEq(token.owner(), owner);
    }
}

contract RoleTest is SalaamGccTest {
    function test_Role_Renonce_Reverts() external {
        vm.startBroadcast(owner);
        vm.expectRevert();
        token.renounceRole(adminRole, bobAdmin);
        vm.stopBroadcast();

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.renounceRole(adminRole, owner);

        vm.prank(aliceAdmin);
        vm.expectRevert();
        token.renounceRole(adminRole, bobAdmin);
    }

    function test_Role_Revoke_Reverts() external {
        vm.prank(bobAdmin);
        vm.expectRevert();
        token.revokeRole(adminRole, aliceAdmin);

        vm.prank(bobAdmin);
        vm.expectRevert();
        token.revokeRole(adminRole, bobAdmin);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.revokeRole(adminRole, charlie);

        vm.prank(oscarAdmin);
        vm.expectRevert();
        token.revokeRole(adminRole, owner);

        vm.prank(charlie);
        vm.expectRevert();
        token.revokeRole(adminRole, minter);
    }

    function test_Role_Renonce_Succeeds() external {
        vm.startBroadcast(owner);
        token.renounceRole(adminRole, owner);
        vm.stopBroadcast();

        vm.prank(bobAdmin);
        token.renounceRole(adminRole, bobAdmin);
        assertEq(token.hasRole(adminRole, bobAdmin), false);

        vm.prank(aliceAdmin);
        token.renounceRole(adminRole, aliceAdmin);
        assertEq(token.hasRole(adminRole, aliceAdmin), false);
    }

    function test_Role_Revoke_Succeeds() external {
        vm.startBroadcast(owner);
        assertEq(token.hasRole(adminRole, oscarAdmin), true);
        token.revokeRole(adminRole, oscarAdmin);
        assertEq(token.hasRole(adminRole, oscarAdmin), false);
        vm.stopBroadcast();
    }
}

contract UpgradabilityTest is SalaamGccTest {
    function test_Upgradability_Succeeds() external {
        vm.startBroadcast(owner);
        SalaamGccV2 newImplementation = new SalaamGccV2();
        address v2Address = address(newImplementation);

        bytes memory data = abi.encodeCall(newImplementation.upgradeVersion, ());
        token.upgradeToAndCall(v2Address, data);

        SalaamGccV2 upgradedToken = SalaamGccV2(address(token));

        assertEq(upgradedToken.version(), "v2");

        vm.stopBroadcast();
    }

    function test_Upgradability_Reverts() external {
        vm.startBroadcast(owner);

        vm.expectRevert();
        token.upgradeToAndCall(minter, "");

        vm.stopBroadcast();
    }
}
