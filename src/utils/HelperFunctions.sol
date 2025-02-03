// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title HelperFunction Contract
/// @author SalaamGcc
/// @notice Handles staking helper functions
contract HelperFunctions is Ownable(msg.sender), ReentrancyGuard {
    /// @notice Thrown when caller does not have right access
    error CallerDoesNotHaveAccess();

    mapping(address _user => bool sweepers) public sweepers;
    uint256 public stoppedAt;

    /// @notice Emitted when a token is sweeped
    /// @param token the address of the token sweeped
    /// @param amount the amount of the token sweeped
    event Sweeped(address indexed token, uint256 amount);

    /// @notice Emitted when sweeper address is set
    /// @param account the address of the sweeper
    /// @param enable the status of sweeper
    event SetSweeper(address account, bool enable);

    /// @notice Emitted when staking is stop
    /// @param at the unix time when staking stops
    event StakingStopped(uint256 at);
    event StakingStart();

    /// @notice Sets or unsets a sweeper
    /// @dev Can only be called by the owner
    /// @param account The address of the account to set or unset as a sweeper
    /// @param enable A boolean indicating if the account should be enabled as a sweeper
    function setSweeper(address account, bool enable) external onlyOwner {
        sweepers[account] = enable;
        emit SetSweeper(account, enable);
    }

    /// @notice Sweeps tokens to the caller
    /// @dev Caller must be an owner or a sweeper
    /// @param token The address of the token to sweep
    /// @param amount The amount of tokens to sweep
    function sweep(address token, uint256 amount) external {
        if (!(sweepers[msg.sender] || msg.sender == owner())) {
            revert CallerDoesNotHaveAccess();
        }

        IERC20(token).transfer(msg.sender, amount);
        emit Sweeped(token, amount);
    }

    /// @notice Stops the staking process
    /// @dev Can only be called by the owner
    function stopStaking() external onlyOwner {
        stoppedAt = block.timestamp;
        emit StakingStopped(block.timestamp);
    }

    /// @notice Start the staking process
    /// @dev Can only be called by the owner
    function startStaking() external onlyOwner {
        stoppedAt = 0;
        emit StakingStart();
    }
}
