// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title SalaamGCC ERC20 Token
/// @notice ERC20 token with capped supply, pausability, ownership, access control, and UUPS upgradability.
/// @dev Uses OpenZeppelin upgradeable contracts for modularity and security.
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20CappedUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SalaamGCC is
    ERC20Upgradeable,
    ERC20CappedUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    /// @notice Thrown when attempting to upgrade to a non-contract address.
    /// @param newImplementation The address of the invalid implementation.
    error ImplementationIsNotContract(address newImplementation);

    /// @notice Thrown when a function is called while the contract is paused.
    error ContractPaused();

    /// @notice Thrown when an unauthorized address attempts to mint tokens.
    /// @param caller The address that attempted the unauthorized action.
    error UnauthorizedMinter(address caller);

    /// @notice Thrown when an invalid (zero) address is provided.
    error InvalidAddress();

    /// @notice Emitted when the minter role is reassigned.
    /// @param oldMinter The address of the previous minter.
    /// @param newMinter The address of the new minter.
    event MinterChanged(address indexed oldMinter, address indexed newMinter);

    string private constant _NAME = "SalaamGCC";
    string private constant _SYMBOL = "SGCC";
    uint256 private constant _TOTAL_SUPPLY = 6_000_000_000 ether;

    /// @notice Role identifier for administrative privileges.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Address authorized to mint new tokens.
    address private _minter;

    constructor() ERC20Upgradeable() ERC20CappedUpgradeable() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with core parameters.
    /// @param owner Initial owner address.
    /// @param adminAddresses Addresses granted admin role.
    /// @param minterAddress Address authorized to mint tokens.
    function initialize(
        address owner,
        address[3] memory adminAddresses,
        address minterAddress
    ) external initializer onlyProxy {
        if (owner == address(0) || minterAddress == address(0)) revert InvalidAddress();

        __SalaamGCC_init(owner, adminAddresses, minterAddress);
    }

    /// @dev Calls parent initializers in the right order then calls the contract-specific initializer.
    // solhint-disable-next-line
    function __SalaamGCC_init(
        address owner,
        address[3] memory adminAddresses,
        address minterAddress
    ) internal onlyInitializing {
        __ERC20_init(_NAME, _SYMBOL);
        __ERC20Capped_init(_TOTAL_SUPPLY);
        __Ownable_init(owner);
        __Pausable_init();
        __UUPSUpgradeable_init();
        __SalaamGCC_init_unchained(owner, adminAddresses, minterAddress);
    }

    /// @notice Internal function to initialize the state variables specific to SalaamGCC.
    // solhint-disable-next-line
    function __SalaamGCC_init_unchained(
        address owner,
        address[3] memory adminAddresses,
        address minterAddress
    ) internal onlyInitializing {
        _transferOwnership(owner);
        _minter = minterAddress;

        // Ensure the owner is one of the admin addresses
        _grantRole(ADMIN_ROLE, owner);

        _grantRole(ADMIN_ROLE, adminAddresses[0]);
        _grantRole(ADMIN_ROLE, adminAddresses[1]);
        _grantRole(ADMIN_ROLE, adminAddresses[2]);
    }

    /// @dev Restricts function access to the minter.
    modifier onlyMinter() {
        if (msg.sender != _minter) revert UnauthorizedMinter(msg.sender);
        _;
    }

    /// @notice Mints tokens to a specified address.
    /// @param to Recipient address.
    /// @param amount Number of tokens to mint.
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    /// @notice Updates the minter address.
    /// @param newMinter New minter address.
    function setMinter(address newMinter) external onlyOwner {
        if (newMinter == address(0)) revert InvalidAddress();

        address oldMinter = _minter;
        _minter = newMinter;
        emit MinterChanged(oldMinter, newMinter);
    }

    /// @notice Pauses all transfers and minting operations.
    /// @dev Can only be called by an account with the admin role.
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @notice Resumes token transfers and minting.
    /// @dev Can only be called by an account with the admin role.
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @dev Checks if contract is paused before allowing transfers or minting.
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        if (paused()) revert ContractPaused();
        super._update(from, to, amount);
    }

    /// @dev Ensures only the owner can authorize contract upgrades.
    /// @param _newImplementation Address of the new contract implementation.
    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {
        if (_newImplementation.code.length == 0) revert ImplementationIsNotContract(_newImplementation);
    }
}
