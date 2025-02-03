// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { HelperFunctions } from "../utils/HelperFunctions.sol";

/// @title SalaamGCC Staking Contract
/// @author SalaamGCC
/// @notice Handles staking of given token and distribute Rewards tokens
contract SalaamGccStaking is HelperFunctions {
    /// @notice Thrown when an invalid (zero) amount is provided
    error ZeroAmountNotAllowed();

    /// @notice Thrown when staking is not allowed
    error StakingNotAllowed();

    /// @notice Thrown when staking cap has exceeded
    error StakingCapExceeded();

    /// @notice Thrown when staking is not yet over
    error StakingNotYetOver();

    /// @notice Thrown when an invalid (zero) address is provided
    error ZeroAddressNotAllowed();

    /// @notice Thrown when invalid cap limit is provided
    error InvalidCapLimit();

    /// @notice Thrown when caller is invalid
    error InvalidCaller();

    /// @notice Thrown when withdrawal is not allowed
    error WithdrawNotAllowed();

    using SafeERC20 for IERC20;

    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    bool public isWithdrawEnable;
    uint256 public rewardRate;
    uint256 public rewardPool;
    uint256 public stakingCap;
    uint256 public stakingTill;
    uint256 public totalSupply;
    uint256 public totalStaked;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardsDuration;
    uint256 public totalRewardsDistributed;

    mapping(address user => uint256 rewards) public rewards;
    mapping(address user => uint256 balanceOf) public balanceOf;

    /// @notice Emitted when the reward is added
    /// @param reward the amount of reward added
    event RewardAdded(uint256 reward);

    /// @notice Emitted when user stakes
    /// @param user the address of the user
    /// @param amount the amount the user has staked
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when user withdraws
    /// @param user the address of the user
    /// @param amount the amount the user has withdrawn
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when user claims reward
    /// @param user the address of the user
    /// @param reward the amount of reward the user has claimed
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Emitted when withdrawal status changes
    /// @param isWithdrawEnable boolean value for withdraw status
    event IsWithdrawEnableChanged(bool isWithdrawEnable);

    /// @notice Emitted when staking cap changes
    /// @param oldCap the amount of old cap limit
    /// @param newCap the amount of new cap limit
    event CapChange(uint256 oldCap, uint256 newCap);

    /// @notice Emitted when owner recovers an ERC20
    /// @param token the address of recovered token
    /// @param amount the amount of recovered token
    event Recovered(address token, uint256 amount);

    /// @dev Constructor that initializes the contract with the given parameters
    /// @param _rewardsToken The address of the rewards token
    /// @param _stakingToken The address of the staking token
    /// @param _rewardsDuration The duration of the rewards period in days
    /// @param _stakingTill The timestamp until when staking is allowed
    /// @param _stakingCap The maximum number of tokens allowed to stake
    /// @param _rate The reward rate in percentage
    constructor(
        address _rewardsToken,
        address _stakingToken,
        uint256 _rewardsDuration,
        uint256 _stakingTill,
        uint256 _stakingCap,
        uint256 _rate
    ) {
        if (_stakingToken == address(0) || _rewardsToken == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        if (_stakingCap == 0 || _rewardsDuration == 0 || _stakingTill == 0 || _rate == 0) {
            revert ZeroAmountNotAllowed();
        }
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        rewardsDuration = _rewardsDuration; // period in days -  ex 30
        stakingTill = _stakingTill; // timestamp to close staking window
        stakingCap = _stakingCap; // max num of tokens allowed to stake in decimals
        rewardRate = _rate; // rate in percentage - ex 200%
        isWithdrawEnable = false; // this disable withdraw and getReward
    }

    /// @dev Calculates the reward for a given account
    /// @param account The address of the account
    /// @return The calculated reward
    function _updateReward(address account) internal view returns (uint256) {
        uint256 r = (rewardRate * rewardsDuration * balanceOf[account]) / 36500;

        if (stoppedAt == 0) return r;

        uint256 daysCompleted = stoppedAt - stakingTill;
        uint256 tenure = periodFinish - stakingTill;

        return (r * tenure) / daysCompleted;
    }

    /// @notice Gets the reward for the entire duration
    /// @return The reward for the duration
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    /// @notice Stakes a given amount of tokens
    /// @dev The amount must be greater than 0 and staking must be allowed
    /// @param user The address of user to stake
    /// @param amount The amount of tokens to stake
    function stake(address user, uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmountNotAllowed();
        }
        if (block.timestamp >= stakingTill || stoppedAt != 0) {
            revert StakingNotAllowed();
        }
        if (totalSupply + amount >= stakingCap) {
            revert StakingCapExceeded();
        }
        rewards[user] = _updateReward(user);

        totalSupply += amount;
        totalStaked += amount;

        balanceOf[user] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(user, amount);
    }

    /// @notice Withdraws a given amount of tokens
    /// @dev The amount must be greater than 0 and staking must be finished or stopped
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 amount) public nonReentrant {
        if (!(isWithdrawEnable)) revert WithdrawNotAllowed();
        if (amount == 0) {
            revert ZeroAmountNotAllowed();
        }
        if (block.timestamp <= periodFinish && stoppedAt == 0) {
            revert StakingNotYetOver();
        }

        address caller = msg.sender;
        rewards[caller] = _updateReward(caller);

        totalSupply -= amount;
        balanceOf[caller] -= amount;

        stakingToken.safeTransfer(caller, amount);
        emit Withdrawn(caller, amount);
    }

    /// @dev Staking must be finished or stopped
    /// @notice Gets the reward for the caller
    function getReward() public nonReentrant {
        if (!(isWithdrawEnable)) revert WithdrawNotAllowed();
        if (block.timestamp <= periodFinish && stoppedAt == 0) {
            revert StakingNotYetOver();
        }

        address caller = msg.sender;
        uint256 reward = rewards[caller];
        if (reward > 0) {
            rewards[caller] = 0;
            totalRewardsDistributed += reward;
            rewardsToken.safeTransfer(caller, reward);
            emit RewardPaid(caller, reward);
        }
    }

    /// @dev Exits the staking by withdrawing all tokens and getting the reward
    function exit() external {
        withdraw(balanceOf[msg.sender]);
        getReward();
    }

    /// @notice Notifies the contract of the reward amount
    /// @dev Can only be called by the owner
    function notifyRewardAmount() public onlyOwner {
        uint256 reward = (rewardRate * rewardsDuration * stakingCap) / 36500;
        uint256 timestamp = block.timestamp;

        if (rewardPool < reward) {
            uint256 _rewardPool = rewardPool;
            rewardPool = reward;
            rewardsToken.safeTransferFrom(msg.sender, address(this), reward - _rewardPool);
        }

        lastUpdateTime = timestamp;
        periodFinish = timestamp + rewardsDuration * 1 days;
        emit RewardAdded(reward);
    }

    /// @notice Updates the reward rate
    /// @dev Can only be called by the owner
    /// @param rate The new reward rate
    function updateInterest(uint256 rate) external onlyOwner {
        if (rate == 0) revert ZeroAmountNotAllowed();
        rewardRate = rate;
        notifyRewardAmount();
    }

    /// @notice Updates Staking Cap value
    /// @dev Can only be called by the owner
    /// @param _newCap value of new StakingCap
    function setCap(uint256 _newCap) external onlyOwner {
        if (_newCap < totalSupply) {
            revert InvalidCapLimit();
        }
        uint256 oldCap = stakingCap;
        stakingCap = _newCap;
        emit CapChange(oldCap, _newCap);
    }

    /// @notice Updates isWithdrawEnable
    /// @dev Can only be called by the owner
    /// @param _isWithdrawEnable value to update isWithdrawEnable
    function setIsWithdrawEnable(bool _isWithdrawEnable) external onlyOwner {
        isWithdrawEnable = _isWithdrawEnable;
        emit IsWithdrawEnableChanged(isWithdrawEnable);
    }

    /// @notice recover any token from this contract to caller account
    /// @dev Can only be called by the owner
    /// @param _token address for recovering token
    /// @param _amount number of tokens want to recover
    /// Added to support recovering to stuck tokens, even reward token in case emergency. only owner
    function recoverERC20(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_amount == 0) revert ZeroAmountNotAllowed();
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Recovered(_token, _amount);
    }
}
