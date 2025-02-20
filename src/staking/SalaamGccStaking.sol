// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title SalaamGCC Staking Contract
/// @author SalaamGCC
/// @notice Handles staking of Staked tokens and distribute Rewards tokens
contract SalaamGccStaking is Ownable2Step, ReentrancyGuard {
    /// @notice Thrown when an invalid (zero) amount is provided
    error ZeroAmountNotAllowed();

    /// @notice Thrown when an invalid (zero) address is provided
    error ZeroAddressNotAllowed();

    /// @notice Thrown when user has already staked
    error UserAlreadyStaked();

    /// @notice Thrown when staking has ended
    error StakingEnded();

    /// @notice Thrown when staking cap has exceeded
    error StakingCapExceeded();

    /// @notice Thrown when staking is not yet started
    error StakingNotStarted();

    /// @notice Thrown when staking has not yet ended
    error StakingNotEnded();

    /// @notice Thrown when staking is not yet matured
    error StakingNotMatured();

    /// @notice Thrown when invalid cap limit is provided
    error InvalidCapLimit();

    /// @notice Thrown when recovering staking or rewards token
    error UnauthorizedTokenRecovery();

    /// @notice Thrown when Multiplier is not valid
    error InvalidMultipliers();

    /// @notice Thrown when there is nothing to claim
    error NothingToClaim();

    using SafeERC20 for IERC20;

    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARDS_TOKEN;

    uint256 public immutable STAKING_START;
    uint256 public immutable STAKING_END;
    uint256 public immutable STAKING_MATURED;
    uint256 public immutable REWARDS_DURATION;
    uint256 internal immutable LAST_STAKING_MONTH;

    uint256 public stakingCap;
    uint256 public rewardsPool;
    uint256 public totalStakedSupply;
    uint256 public totalRewardsSupply;
    uint256 public totalRewardsDistributed;

    struct StakingInfo {
        uint256 multiplier; // Multiplier for rewards
        uint256 stakedAmount; // Actual staked amount
        uint256 rewardsAmount; // Effective rewards balance with the multiplier applied
        uint256 stakeStart; // Timestamp when the user started staking
    }

    mapping(address userAddress => StakingInfo stakingInfo) public stakers;
    mapping(uint256 month => uint256 multiplier) public monthlyMultipliers;

    /// @notice Emitted when the rewards is added
    /// @param rewardsAmount the amount of rewards added
    event RewardsAdded(uint256 indexed rewardsAmount);

    /// @notice Emitted when user stakes
    /// @param user the address of the user
    /// @param stakedAmount the amount the user has staked
    /// @param userMultiplier user's multiplier amount
    /// @param rewardsAmount the amount after computing the multiplier bonus
    event Staked(
        address indexed user,
        uint256 indexed stakedAmount,
        uint256 indexed userMultiplier,
        uint256 rewardsAmount
    );

    /// @notice Emitted when user withdraws
    /// @param user the address of the user
    /// @param withdrawalAmount the amount the user has withdrawn
    event Withdrawn(address indexed user, uint256 indexed withdrawalAmount);

    /// @notice Emitted when user claims rewards
    /// @param user the address of the user
    /// @param rewardsAmount the amount of rewards the user has claimed
    event RewardsPaid(address indexed user, uint256 indexed rewardsAmount);

    /// @notice Emitted when staking cap changes
    /// @param oldCap the amount of old cap limit
    /// @param newCap the amount of new cap limit
    event CapChange(uint256 indexed oldCap, uint256 indexed newCap);

    /// @notice Emitted when owner recovers an ERC20
    /// @param token the address of recovered token
    /// @param recoveredTokenAmount the amount of recovered token
    event Recovered(address indexed token, uint256 indexed recoveredTokenAmount);

    /// @dev Constructor that initializes the contract with the given parameters
    /// @param _stakingToken The address of the staking token
    /// @param _rewardsToken The address of the rewards token
    /// @param _rewardsDuration The duration of the rewards period in days
    /// @param _stakingStart The timestamp when the staking has started
    /// @param _stakingEnd The timestamp until when staking is allowed
    /// @param _stakingCap The maximum number of tokens allowed to stake
    constructor(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration,
        uint256 _stakingStart,
        uint256 _stakingEnd,
        uint256 _stakingCap,
        uint256[] memory _multipliers
    ) Ownable(msg.sender) {
        if (_stakingToken == address(0) || _rewardsToken == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        if (_stakingCap == 0 || _rewardsDuration == 0 || _stakingStart == 0 || _stakingEnd == 0) {
            revert ZeroAmountNotAllowed();
        }

        uint256 expectedMonths = (_stakingEnd - _stakingStart) / 30 days;
        if (_multipliers.length == 0 || _multipliers.length != expectedMonths) revert InvalidMultipliers();

        for (uint256 i = 0; i < _multipliers.length; i++) {
            monthlyMultipliers[i + 1] = _multipliers[i];
        }

        STAKING_TOKEN = IERC20(_stakingToken);
        REWARDS_TOKEN = IERC20(_rewardsToken);

        STAKING_START = _stakingStart; // timestamp to start staking
        STAKING_END = _stakingEnd; // timestamp to end staking
        STAKING_MATURED = _stakingEnd + (REWARDS_DURATION * 1 days); // timestamp of staking maturity
        REWARDS_DURATION = _rewardsDuration; // period in days -  ex 30
        LAST_STAKING_MONTH = _multipliers.length; // last month of staking

        stakingCap = _stakingCap; // max num of tokens allowed to stake
    }

    /// @notice Returns the current multiplier based on staking time.
    /// @return The multiplier amount based on the staking month.
    function currentMultiplier() public view returns (uint256) {
        if (STAKING_START == 0 || block.timestamp < STAKING_START) {
            return 0; // Staking hasn't started
        }

        if (block.timestamp >= STAKING_END) {
            return monthlyMultipliers[LAST_STAKING_MONTH]; // Staking has ended, return last multiplier
        }

        uint256 monthsElapsed = ((block.timestamp - STAKING_START) / 30 days) + 1;
        if(monthsElapsed > LAST_STAKING_MONTH) monthsElapsed = LAST_STAKING_MONTH;

        return monthlyMultipliers[monthsElapsed];
    }

    /// @notice Stakes a given amount of tokens with a multiplier
    /// @dev The amount must be greater than 0 and staking must be allowed
    /// @param userAddress The address of user to stake
    /// @param stakedAmount The amount of tokens to stake
    function stake(address userAddress, uint256 stakedAmount) external nonReentrant {
        if (block.timestamp < STAKING_START) revert StakingNotStarted();
        if (block.timestamp >= STAKING_END) revert StakingEnded();
        if (userAddress == address(0)) revert ZeroAddressNotAllowed();
        if (stakedAmount == 0) revert ZeroAmountNotAllowed();
        if (totalStakedSupply + stakedAmount > stakingCap) revert StakingCapExceeded();

        StakingInfo storage staker = stakers[userAddress];
        if (staker.stakedAmount != 0) revert UserAlreadyStaked();

        uint256 userMultiplier = currentMultiplier();
        uint256 rewardsAmount = (stakedAmount * userMultiplier) / 100;

        staker.stakedAmount += stakedAmount;
        staker.rewardsAmount += rewardsAmount;
        staker.multiplier = userMultiplier;
        staker.stakeStart = block.timestamp;

        totalRewardsSupply += rewardsAmount;
        totalStakedSupply += stakedAmount;

        STAKING_TOKEN.safeTransferFrom(msg.sender, address(this), stakedAmount);
        emit Staked(userAddress, stakedAmount, userMultiplier, rewardsAmount);
    }

    /// @notice Withdraws the staked tokens for the caller
    /// @dev Staking must achieve its maturity
    function claimStakedTokens() public nonReentrant {
        if (block.timestamp <= STAKING_MATURED) revert StakingNotMatured();

        address caller = msg.sender;
        StakingInfo storage staker = stakers[caller];
        uint256 stakedAmount = staker.stakedAmount;
        if (stakedAmount == 0) revert NothingToClaim();

        staker.stakedAmount -= stakedAmount;

        if (totalStakedSupply > 0)
            totalStakedSupply = totalStakedSupply > stakedAmount ? totalStakedSupply - stakedAmount : 0;

        STAKING_TOKEN.safeTransfer(caller, stakedAmount);
        emit Withdrawn(caller, stakedAmount);
    }

    /// @notice Gets the rewards for the caller
    /// @dev Staking must achieve its maturity
    function claimRewards() public nonReentrant {
        if (block.timestamp <= STAKING_MATURED) {
            revert StakingNotMatured();
        }

        address caller = msg.sender;

        StakingInfo storage staker = stakers[caller];
        uint256 rewardsAmount = staker.rewardsAmount;
        if (rewardsAmount == 0) revert NothingToClaim();

        staker.rewardsAmount -= rewardsAmount;
        totalRewardsDistributed += rewardsAmount;
        rewardsPool = rewardsPool > rewardsAmount ? rewardsPool - rewardsAmount : 0;

        REWARDS_TOKEN.safeTransfer(caller, rewardsAmount);
        emit RewardsPaid(caller, rewardsAmount);
    }

    /// @dev Exits the staking by withdrawing all tokens and getting the rewards
    function exit() external {
        claimRewards();
        claimStakedTokens();
    }

    /// @notice Notifies the contract of the rewards amount
    /// @dev Can only be called by the owner
    function fundRewardPool() external onlyOwner {
        if (block.timestamp < STAKING_END) revert StakingNotEnded();
        uint256 rewards = totalRewardsSupply;

        if (rewardsPool < rewards) {
            uint256 _rewardsPool = rewardsPool;
            rewardsPool = rewards;
            REWARDS_TOKEN.safeTransferFrom(msg.sender, address(this), rewards - _rewardsPool);
            emit RewardsAdded(rewards);
        }
    }

    /// @notice Updates Staking Cap value
    /// @dev Can only be called by the owner
    /// @param _newCap value of new StakingCap
    function setCap(uint256 _newCap) external onlyOwner {
        if (block.timestamp >= STAKING_END) revert StakingEnded();
        if (_newCap == 0) revert ZeroAmountNotAllowed();
        if (_newCap < totalRewardsSupply) {
            revert InvalidCapLimit();
        }
        uint256 oldCap = stakingCap;
        stakingCap = _newCap;
        emit CapChange(oldCap, _newCap);
    }

    /// @notice recover stuck token from this contract to caller account
    /// @dev Can only be called by the owner
    /// @param _token address for recovering token
    /// @param _recoveredTokenAmount number of tokens want to recover
    function recoverERC20(address _token, uint256 _recoveredTokenAmount) external onlyOwner {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_token == address(STAKING_TOKEN) || _token == address(REWARDS_TOKEN)) revert UnauthorizedTokenRecovery();
        if (_recoveredTokenAmount == 0) revert ZeroAmountNotAllowed();
        IERC20(_token).safeTransfer(msg.sender, _recoveredTokenAmount);
        emit Recovered(_token, _recoveredTokenAmount);
    }

    /// @notice Returns staking details of a given user
    /// @param userAddress The address of the user
    /// @return multiplier The bonus multiplier applied
    /// @return stakedAmount The actual staked amount
    /// @return rewardsAmount The effective staking balance with the multiplier applied
    /// @return stakeStart The timestamp when the user started staking
    function getStakerInfo(
        address userAddress
    ) external view returns (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) {
        StakingInfo memory staker = stakers[userAddress];
        return (staker.multiplier, staker.stakedAmount, staker.rewardsAmount, staker.stakeStart);
    }

    /// @notice Returns the multiplier for a given month
    /// @param month The staking month (1-based index)
    /// @return multiplier The multiplier for the given month
    function getMonthlyMultiplier(uint256 month) external view returns (uint256) {
        return monthlyMultipliers[month];
    }
}
