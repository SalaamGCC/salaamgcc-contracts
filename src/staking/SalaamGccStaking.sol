// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title SalaamGCC Staking Contract
/// @author SalaamGCC
/// @notice Handles staking of given token and distribute Rewards tokens
contract SalaamGccStaking is Ownable2Step, ReentrancyGuard {
    /// @notice Thrown when an invalid (zero) amount is provided
    error ZeroAmountNotAllowed();

    /// @notice Thrown when caller does not have right access
    error CallerDoesNotHaveAccess();

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

    /// @notice Thrown when staking is stopped before stakingTill
    error StakingPeriodNotOver();

    /// @notice Thrown when periodFinish is not initialized or 0
    error StakingFinishPeriodNotInitialized();

    /// @notice Thrown when recovering staking or rewards token
    error UnauthorizedTokenRecovery();

    /// @notice Thrown when Multiplier is not valid
    error InvalidMultiplier();

    /// @notice Thrown when there is nothing to claim
    error NothingToClaim();

    error InvalidAmount();

    using SafeERC20 for IERC20;

    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    bool public isWithdrawEnable;
    uint256 public stoppedAt;
    uint256 public rewardsRate;
    uint256 public rewardsPool;
    uint256 public stakingCap;
    uint256 public stakingTill;
    uint256 public totalSupply;
    uint256 public totalStaked;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardsDuration;
    uint256 public totalRewardsDistributed;
    uint256 public stakingStartTime;
    uint256 public maxMultiplier;

    struct Staker {
        uint256 rewards; // Rewards earned by the user
        uint256 multiplier; // Bonus multiplier for rewards
        uint256 multiplierBonusAmount; // User's effective staking balance
        uint256 stakedAmount; // Actual staked amount (before any deductions)
        uint256 stakeStart; // Timestamp when the user started staking
    }

    mapping(address => Staker) public stakers;

    /// @notice Emitted when the rewards is added
    /// @param rewardsAmount the amount of rewards added
    event RewardsAdded(uint256 rewardsAmount);

    /// @notice Emitted when user stakes
    /// @param user the address of the user
    /// @param stakedAmount the amount the user has staked
    /// @param multiplierBonusAmount the amount after computing the multiplier bonus
    event Staked(address indexed user, uint256 stakedAmount, uint256 multiplierBonusAmount, uint256 userMultiplier);

    /// @notice Emitted when user withdraws
    /// @param user the address of the user
    /// @param withdrawalAmount the amount the user has withdrawn
    event Withdrawn(address indexed user, uint256 withdrawalAmount);

    /// @notice Emitted when user claims rewards
    /// @param user the address of the user
    /// @param rewardsAmount the amount of rewards the user has claimed
    event RewardsPaid(address indexed user, uint256 rewardsAmount);

    /// @notice Emitted when withdrawal status changes
    /// @param isWithdrawEnable boolean value for withdraw status
    event IsWithdrawEnableChanged(bool isWithdrawEnable);

    /// @notice Emitted when staking cap changes
    /// @param oldCap the amount of old cap limit
    /// @param newCap the amount of new cap limit
    event CapChange(uint256 oldCap, uint256 newCap);

    /// @notice Emitted when owner recovers an ERC20
    /// @param token the address of recovered token
    /// @param recoveredTokenAmount the amount of recovered token
    event Recovered(address token, uint256 recoveredTokenAmount);

    /// @notice Emitted when staking is stop
    /// @param at the unix time when staking stops
    event StakingStopped(uint256 at);

    /// @notice Emitted when has started
    event StakingStart();

    /// @dev Constructor that initializes the contract with the given parameters
    /// @param _rewardsToken The address of the rewards token
    /// @param _stakingToken The address of the staking token
    /// @param _rewardsDuration The duration of the rewards period in days
    /// @param _stakingTill The timestamp until when staking is allowed
    /// @param _stakingCap The maximum number of tokens allowed to stake
    /// @param _rate The rewards rate in percentage
    constructor(
        address _rewardsToken,
        address _stakingToken,
        uint256 _rewardsDuration,
        uint256 _stakingTill,
        uint256 _stakingCap,
        uint256 _rate,
        uint256 _maxMultiplier
    ) Ownable(msg.sender) {
        if (_stakingToken == address(0) || _rewardsToken == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        if (_stakingCap == 0 || _rewardsDuration == 0 || _stakingTill == 0 || _rate == 0) {
            revert ZeroAmountNotAllowed();
        }
        if (_maxMultiplier < 100) revert InvalidMultiplier();
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        rewardsDuration = _rewardsDuration; // period in days -  ex 30
        stakingTill = _stakingTill; // timestamp to close staking window
        stakingCap = _stakingCap; // max num of tokens allowed to stake
        rewardsRate = _rate; // rate in percentage - ex 200%
        maxMultiplier = _maxMultiplier; // e.g., 300 for 3x, 200 for 2x
        isWithdrawEnable = false; // this disable withdraw and claimRewards
        stakingStartTime = block.timestamp; // Set staking start time when deployed
    }

    /// @dev Calculates the rewards for a given account
    /// @param userAddress The address of the user
    /// @return The calculated rewards
    function _updateRewards(address userAddress) internal view returns (uint256) {
        Staker storage staker = stakers[userAddress];
        uint256 r = (rewardsRate * rewardsDuration * staker.stakedAmount) / 36500;

        if (stoppedAt == 0) return r;

        uint256 daysCompleted = stoppedAt - stakingTill;
        uint256 tenure = periodFinish - stakingTill;

        return (r * daysCompleted) / tenure;
    }

    /// @notice Returns the current multiplier based on time remaining until staking is closed
    /// @return The multiplier amount of the user by current month
    function getCurrentMultiplier() public view returns (uint256) {
        uint256 totalMonths = (stakingTill - stakingStartTime) / 30 days;
        uint256 monthsRemaining = (stakingTill - block.timestamp) / 30 days;

        if (block.timestamp >= stakingTill || totalMonths <= 1) {
            return 100; // No bonus in the final month or if only 1 month exists
        }

        uint256 monthlyReduction = (maxMultiplier - 100) / totalMonths;
        uint256 currentMultiplier = maxMultiplier - (monthlyReduction * (totalMonths - monthsRemaining));
        return currentMultiplier;
    }

    /// @notice Stakes a given amount of tokens with a multiplier
    /// @dev The amount must be greater than 0 and staking must be allowed
    /// @param userAddress The address of user to stake
    /// @param stakedAmount The amount of tokens to stake
    function stake(address userAddress, uint256 stakedAmount) external nonReentrant {
        if (stakedAmount == 0) {
            revert ZeroAmountNotAllowed();
        }
        if (block.timestamp >= stakingTill || stoppedAt != 0) {
            revert StakingNotAllowed();
        }
        if (totalSupply + stakedAmount > stakingCap) {
            revert StakingCapExceeded();
        }

        uint256 userMultiplier = getCurrentMultiplier();
        uint256 multiplierBonusAmount = (stakedAmount * userMultiplier) / 100;

        Staker storage staker = stakers[userAddress];

        staker.stakedAmount += stakedAmount;
        staker.multiplierBonusAmount += multiplierBonusAmount;
        staker.multiplier = userMultiplier;

        totalSupply += multiplierBonusAmount;
        totalStaked += stakedAmount;

        staker.rewards = _updateRewards(userAddress);
        stakingToken.safeTransferFrom(msg.sender, address(this), stakedAmount);
        emit Staked(userAddress, stakedAmount, multiplierBonusAmount, userMultiplier);
    }

    /// @notice Withdraws a given amount of staked tokens
    /// @dev Staking must be finished or stopped and periodFinish must be over
    /// @param withdrawalAmount The amount of tokens to withdraw
    function claimStakedAmount(uint256 withdrawalAmount) public nonReentrant {
        if (!(isWithdrawEnable)) revert WithdrawNotAllowed();
        if (periodFinish == 0) revert StakingFinishPeriodNotInitialized();
        if (block.timestamp <= periodFinish && stoppedAt == 0) revert StakingNotYetOver();
        if (withdrawalAmount == 0) revert ZeroAmountNotAllowed();

        address caller = msg.sender;
        Staker storage staker = stakers[caller];
        uint256 stakedAmount = staker.stakedAmount;
        if (stakedAmount == 0) revert NothingToClaim();
        if (withdrawalAmount > totalStaked) revert InvalidAmount();

        staker.rewards = _updateRewards(caller);
        staker.stakedAmount -= withdrawalAmount;

        if (totalStaked > 0) totalStaked = totalStaked > withdrawalAmount ? totalStaked - withdrawalAmount : 0;

        stakingToken.safeTransfer(caller, withdrawalAmount);
        emit Withdrawn(caller, withdrawalAmount);
    }

    /// @notice Withdraws a given amount of bonus tokens
    /// @dev Staking must be finished or stopped and periodFinish must be over
    /// @param withdrawalAmount The amount of tokens to withdraw
    function claimMultiplierBonusAmount(uint256 withdrawalAmount) public nonReentrant {
        if (!(isWithdrawEnable)) revert WithdrawNotAllowed();
        if (periodFinish == 0) revert StakingFinishPeriodNotInitialized();
        if (block.timestamp <= periodFinish && stoppedAt == 0) revert StakingNotYetOver();
        if (withdrawalAmount == 0) revert ZeroAmountNotAllowed();

        address caller = msg.sender;
        Staker storage staker = stakers[caller];
        uint256 multiplierBonusAmount = staker.multiplierBonusAmount;
        if (multiplierBonusAmount == 0) revert NothingToClaim();
        if (withdrawalAmount > totalSupply) revert InvalidAmount();

        staker.multiplierBonusAmount -= withdrawalAmount;

        if (totalSupply > 0) totalSupply = totalSupply > withdrawalAmount ? totalSupply - withdrawalAmount : 0;

        stakingToken.safeTransfer(caller, withdrawalAmount);
        emit Withdrawn(caller, withdrawalAmount);
    }

    /// @notice Gets the rewards for the caller
    /// @dev Staking must be finished or stopped and periodFinish must be over
    function claimRewardsAmount() public nonReentrant {
        if (!(isWithdrawEnable)) revert WithdrawNotAllowed();
        if (periodFinish == 0) revert StakingFinishPeriodNotInitialized();
        if (block.timestamp <= periodFinish && stoppedAt == 0) {
            revert StakingNotYetOver();
        }

        address caller = msg.sender;

        Staker storage staker = stakers[caller];
        staker.rewards = _updateRewards(caller);
        uint256 rewardsAmount = staker.rewards;
        if (rewardsAmount == 0) revert NothingToClaim();

        staker.rewards = 0;
        totalRewardsDistributed += rewardsAmount;
        rewardsPool = rewardsPool > rewardsAmount ? rewardsPool - rewardsAmount : 0;

        rewardsToken.safeTransfer(caller, rewardsAmount);
        emit RewardsPaid(caller, rewardsAmount);
    }

    /// @dev Exits the staking by withdrawing all tokens and getting the rewards
    function exit() external {
        Staker storage staker = stakers[msg.sender];
        claimRewardsAmount();
        claimStakedAmount(staker.stakedAmount);
        claimMultiplierBonusAmount(staker.multiplierBonusAmount);
    }

    /// @notice Notifies the contract of the rewards amount
    /// @dev Can only be called by the owner
    function notifyRewardsAmount() public onlyOwner {
        uint256 rewards = (rewardsRate * rewardsDuration * stakingCap) / 36500;
        uint256 timestamp = block.timestamp;

        if (rewardsPool < rewards) {
            uint256 _rewardsPool = rewardsPool;
            rewardsPool = rewards;
            rewardsToken.safeTransferFrom(msg.sender, address(this), rewards - _rewardsPool);
            lastUpdateTime = timestamp;
            periodFinish = timestamp + rewardsDuration * 1 days;
            emit RewardsAdded(rewards);
        }
    }

    /// @notice Updates the rewards rate
    /// @dev Can only be called by the owner
    /// @param rate The new rewards rate
    function updateInterest(uint256 rate) external onlyOwner {
        if (rate == 0) revert ZeroAmountNotAllowed();
        rewardsRate = rate;
        notifyRewardsAmount();
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
    /// @param _recoveredTokenAmount number of tokens want to recover
    /// Added to support recovering to stuck tokens, even reward token in case emergency. only owner
    function recoverERC20(address _token, uint256 _recoveredTokenAmount) external onlyOwner {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_token == address(stakingToken) || _token == address(rewardsToken)) revert UnauthorizedTokenRecovery();
        if (_recoveredTokenAmount == 0) revert ZeroAmountNotAllowed();
        IERC20(_token).safeTransfer(msg.sender, _recoveredTokenAmount);
        emit Recovered(_token, _recoveredTokenAmount);
    }

    /// @notice Stops the staking process
    /// @dev Can only be called by the owner
    function stopStaking() external onlyOwner {
        if (block.timestamp < stakingTill) revert StakingPeriodNotOver();

        stoppedAt = block.timestamp;
        emit StakingStopped(block.timestamp);
    }

    /// @notice Start the staking process
    /// @dev Can only be called by the owner
    function startStaking() external onlyOwner {
        stoppedAt = 0;
        emit StakingStart();
    }

    /// @notice Returns staking details of a given user
    /// @param userAddress The address of the user
    /// @return rewards The rewards earned by the user
    /// @return multiplier The bonus multiplier applied
    /// @return multiplierBonusAmount The effective staking balance with the multiplier applied
    /// @return stakedAmount The actual staked amount
    /// @return stakeStart The timestamp when the user started staking
    function getStakerInfo(
        address userAddress
    )
        external
        view
        returns (
            uint256 rewards,
            uint256 multiplier,
            uint256 multiplierBonusAmount,
            uint256 stakedAmount,
            uint256 stakeStart
        )
    {
        Staker memory staker = stakers[userAddress];
        return (
            staker.rewards,
            staker.multiplier,
            staker.multiplierBonusAmount,
            staker.stakedAmount,
            staker.stakeStart
        );
    }
}
