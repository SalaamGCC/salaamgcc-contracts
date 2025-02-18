// SPDX-License-Identifier: UNLICENSED
// solhint-disable one-contract-per-file
pragma solidity 0.8.28;

import { BaseTest } from "../BaseTest.t.sol";
import { SalaamGccStaking } from "../../src/staking/SalaamGccStaking.sol";
import { console } from "forge-std/console.sol";

contract StakingTest is BaseTest {
    SalaamGccStaking public staking;
    address stakingAddress;
    address sampleTokenAddress;

    address alice = address(0x3);
    address bob = address(0x4);
    address oscar = address(0x5);
    address charlie = address(0x6);

    uint256 stakingStart = block.timestamp + 15 days;
    uint256 stakingEnd = stakingStart + 183 days;
    uint256 stakingMatured = stakingEnd + (rewardsDuration * 1 days);
    uint256 rewardsDuration = 365;
    uint256[] multipliers = [200, 190, 180, 170, 160, 150];
    uint256 lastStakingMonth = multipliers.length;

    uint256 stakingCap = 100000000 ether;

    event Staked(
        address indexed user,
        uint256 indexed stakedAmount,
        uint256 indexed userMultiplier,
        uint256 rewardsAmount
    );
    event RewardsAdded(uint256 indexed rewardsAmount);
    event Withdrawn(address indexed user, uint256 indexed withdrawalAmount);
    event RewardsPaid(address indexed user, uint256 indexed rewardsAmount);
    event CapChange(uint256 indexed oldCap, uint256 indexed newCap);

    function test() public override {}

    function setUp() public virtual override {
        super.setUp();
        sampleTokenAddress = address(sampleToken);
        vm.startBroadcast(owner);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            sampleTokenAddress,
            rewardsDuration,
            stakingStart,
            stakingEnd,
            stakingCap,
            multipliers
        );
        stakingAddress = address(staking);
        vm.stopBroadcast();
    }
}

contract StakingDeploymentTest is StakingTest {
    function test_Deployment_Succeeds() external view {
        assertEq(address(staking.STAKING_TOKEN()), sampleTokenAddress);
        assertEq(address(staking.REWARDS_TOKEN()), sampleTokenAddress);
        assertEq(staking.REWARDS_DURATION(), rewardsDuration);
        assertEq(staking.STAKING_START(), stakingStart);
        assertEq(staking.STAKING_END(), stakingEnd);
        assertEq(staking.stakingCap(), stakingCap);
        assertEq(staking.totalStakedSupply(), 0);
        assertEq(staking.rewardsPool(), 0);
        assertEq(staking.totalStakedSupply(), 0);
        assertEq(staking.totalRewardsDistributed(), 0);
        assertEq(staking.owner(), address(owner));
        assertEq(lastStakingMonth, 6);

        uint256 first_month = staking.getMonthlyMultiplier(1);
        uint256 second_month = staking.getMonthlyMultiplier(2);
        uint256 third_month = staking.getMonthlyMultiplier(3);
        uint256 fourth_month = staking.getMonthlyMultiplier(4);
        uint256 fifth_month = staking.getMonthlyMultiplier(5);
        uint256 sixth_month = staking.getMonthlyMultiplier(6);

        assertEq(first_month, 200);
        assertEq(second_month, 190);
        assertEq(third_month, 180);
        assertEq(fourth_month, 170);
        assertEq(fifth_month, 160);
        assertEq(sixth_month, 150);

        (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) = staking.getStakerInfo(
            address(owner)
        );
        assertEq(multiplier, 0);
        assertEq(stakedAmount, 0);
        assertEq(rewardsAmount, 0);
        assertEq(stakeStart, 0);
    }

    function test_Deployment_ZeroAddress_Reverts() external {
        vm.expectRevert(SalaamGccStaking.ZeroAddressNotAllowed.selector);
        staking = new SalaamGccStaking(
            address(0),
            sampleTokenAddress,
            rewardsDuration,
            stakingStart,
            stakingEnd,
            stakingCap,
            multipliers
        );

        vm.expectRevert(SalaamGccStaking.ZeroAddressNotAllowed.selector);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            address(0),
            rewardsDuration,
            stakingStart,
            stakingEnd,
            stakingCap,
            multipliers
        );
    }

    function test_Deployment_ZeroRewardsDuration_Reverts() external {
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            sampleTokenAddress,
            0,
            stakingStart,
            stakingEnd,
            stakingCap,
            multipliers
        );
    }

    function test_Deployment_ZeroStakingStart_Reverts() external {
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            sampleTokenAddress,
            rewardsDuration,
            0,
            stakingEnd,
            stakingCap,
            multipliers
        );
    }

    function test_Deployment_ZeroStakingEnd_Reverts() external {
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            sampleTokenAddress,
            rewardsDuration,
            stakingStart,
            0,
            stakingCap,
            multipliers
        );
    }

    function test_Deployment_InvalidMultipliers_Reverts() external {
        uint256[] memory invalidMultipliers = new uint256[](2);

        invalidMultipliers[0] = 200;
        invalidMultipliers[1] = 190;

        vm.expectRevert(SalaamGccStaking.InvalidMultipliers.selector);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            sampleTokenAddress,
            rewardsDuration,
            stakingStart,
            stakingEnd,
            stakingCap,
            invalidMultipliers
        );
    }

    function test_Deployment_ZeroCap_Reverts() external {
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            sampleTokenAddress,
            rewardsDuration,
            stakingStart,
            stakingEnd,
            0,
            multipliers
        );
    }
}

contract TotalStakedSupplyTest is StakingTest {
    function test_TotalStakedSupply_AfterStaking_Succeeds() external {
        assertEq(staking.totalStakedSupply(), 0);

        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(owner, 400 ether, 200, 800 ether);
        staking.stake(owner, 400 ether);
        vm.stopBroadcast();

        assertEq(staking.totalStakedSupply(), 400 ether);
    }
}

contract TotalRewardsSupplyTest is StakingTest {
    function test_TotalRewardsSupply_AfterStaking_Succeeds() external {
        assertEq(staking.totalRewardsSupply(), 0);

        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(owner, 400 ether, 200, 800 ether);
        staking.stake(owner, 400 ether);
        vm.stopBroadcast();

        assertEq(staking.totalRewardsSupply(), 800 ether);
    }
}

contract StakingFunctionalityTest is StakingTest {
    function test_Stake_BeforeStart_Reverts() external {
        vm.startBroadcast(owner);
        sampleToken.approve(address(staking), 400 ether);
        vm.expectRevert(SalaamGccStaking.StakingNotStarted.selector);
        staking.stake(owner, 400 ether);
        vm.stopBroadcast();
        (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) = staking.getStakerInfo(
            address(owner)
        );
        assertEq(multiplier, 0);
        assertEq(stakedAmount, 0);
        assertEq(rewardsAmount, 0);
        assertEq(stakeStart, 0);
    }

    function test_Stake_AfterStart_Succeeds() external {
        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(owner, 400 ether, 200, 800 ether);
        staking.stake(owner, 400 ether);
        vm.stopBroadcast();

        (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) = staking.getStakerInfo(
            address(owner)
        );
        assertEq(multiplier, 200);
        assertEq(stakedAmount, 400 ether);
        assertEq(rewardsAmount, 800 ether);
        assertEq(stakeStart, block.timestamp);
    }

    function test_Stake_BehalfUser_Succeeds() external {
        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(charlie, 400 ether, 200, 800 ether);
        staking.stake(charlie, 400 ether);
        vm.stopBroadcast();

        (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) = staking.getStakerInfo(
            address(charlie)
        );
        assertEq(multiplier, 200);
        assertEq(stakedAmount, 400 ether);
        assertEq(rewardsAmount, 800 ether);
        assertEq(stakeStart, block.timestamp);
    }

    function test_Stake_UnderCap_Succeeds() external {
        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(owner, 400 ether, 200, 800 ether);
        staking.stake(owner, 400 ether);
        vm.stopBroadcast();

        (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) = staking.getStakerInfo(
            address(owner)
        );
        assertEq(multiplier, 200);
        assertEq(stakedAmount, 400 ether);
        assertEq(rewardsAmount, 800 ether);
        assertEq(stakeStart, block.timestamp);
    }

    function test_Stake_AboveCap_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(alice, 100000001 ether);
        vm.startBroadcast(alice);
        skip(15 days);
        sampleToken.approve(address(staking), 100000001 ether);
        vm.expectRevert(SalaamGccStaking.StakingCapExceeded.selector);
        staking.stake(alice, 100000001 ether);
        vm.stopBroadcast();
    }

    function test_Stake_AgainStake_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(bob, 800 ether);
        vm.startBroadcast(bob);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);
        staking.stake(bob, 400 ether);
        (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) = staking.getStakerInfo(
            address(bob)
        );
        vm.stopBroadcast();

        assertEq(multiplier, 200);
        assertEq(stakedAmount, 400 ether);
        assertEq(rewardsAmount, 800 ether);
        assertEq(stakeStart, block.timestamp);

        vm.startBroadcast(bob);
        sampleToken.approve(address(staking), 400 ether);
        vm.expectRevert(SalaamGccStaking.UserAlreadyStaked.selector);
        staking.stake(bob, 400 ether);
    }

    function test_Stake_Ended_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(oscar, 800 ether);
        vm.startBroadcast(oscar);
        skip(stakingEnd + 1 days);
        sampleToken.approve(address(staking), 400 ether);
        vm.expectRevert(SalaamGccStaking.StakingEnded.selector);
        staking.stake(bob, 400 ether);
    }

    function test_Stake_ZeroAmount_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(alice, 100 ether);
        vm.startBroadcast(alice);
        skip(15 days);
        sampleToken.approve(address(staking), 100 ether);
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking.stake(alice, 0);
    }

    function test_Stake_ZeroAddress_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(alice, 100 ether);
        vm.startBroadcast(alice);
        skip(15 days);
        sampleToken.approve(address(staking), 100 ether);
        vm.expectRevert(SalaamGccStaking.ZeroAddressNotAllowed.selector);
        staking.stake(address(0), 100 ether);
    }

    function test_Stake_AfterMaturity_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(bob, 100 ether);
        vm.startBroadcast(bob);
        skip(stakingMatured);
        sampleToken.approve(address(staking), 100 ether);
        vm.expectRevert(SalaamGccStaking.StakingEnded.selector);
        staking.stake(charlie, 100 ether);
    }
}

contract FundRewardPoolTest is StakingTest {
    function test_FundRewardPool_BeforeStakingEnd_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(owner, 10 ether);
        vm.startBroadcast(owner);
        skip(stakingEnd - 1 days);
        sampleToken.approve(address(staking), staking.totalRewardsSupply());
        vm.expectRevert(SalaamGccStaking.StakingNotEnded.selector);
        staking.fundRewardPool();
    }

    function test_FundRewardPool_NotOwner_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(charlie, 400 ether);

        vm.prank(minter);
        sampleToken.mint(bob, 600 ether);

        vm.prank(minter);
        sampleToken.mint(alice, 100 ether);

        vm.prank(minter);
        sampleToken.mint(oscar, 800 ether);

        skip(15 days);

        vm.startBroadcast(charlie);
        sampleToken.approve(address(staking), 400 ether);
        staking.stake(charlie, 400 ether);
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        sampleToken.approve(address(staking), 600 ether);
        staking.stake(bob, 600 ether);
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        sampleToken.approve(address(staking), 100 ether);
        staking.stake(alice, 100 ether);
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        sampleToken.approve(address(staking), 800 ether);
        staking.stake(oscar, 800 ether);
        vm.stopBroadcast();

        skip(stakingEnd - 1 days);

        vm.prank(owner);
        sampleToken.approve(address(staking), staking.totalRewardsSupply());
        vm.expectRevert();
        staking.fundRewardPool();
    }

    function test_FundRewardPool_Succeeds() external {
        vm.prank(minter);
        sampleToken.mint(charlie, 400 ether);

        vm.prank(minter);
        sampleToken.mint(bob, 600 ether);

        vm.prank(minter);
        sampleToken.mint(alice, 100 ether);

        vm.prank(minter);
        sampleToken.mint(oscar, 800 ether);

        skip(15 days);

        vm.startBroadcast(charlie);
        sampleToken.approve(address(staking), 400 ether);
        staking.stake(charlie, 400 ether);
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        sampleToken.approve(address(staking), 600 ether);
        staking.stake(bob, 600 ether);
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        sampleToken.approve(address(staking), 100 ether);
        staking.stake(alice, 100 ether);
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        sampleToken.approve(address(staking), 800 ether);
        staking.stake(oscar, 800 ether);
        vm.stopBroadcast();

        skip(stakingEnd + 1 days);

        vm.startBroadcast(owner);
        sampleToken.approve(address(staking), staking.totalRewardsSupply());
        vm.expectEmit(true, true, false, true);
        emit RewardsAdded(staking.totalRewardsSupply());
        staking.fundRewardPool();
        vm.stopBroadcast();
    }
}

contract ClaimStakedTokenTest is StakingTest {
    function test_ClaimStakedToken_BeforeMaturity_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(owner, 400 ether);

        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(owner, 400 ether, 200, 800 ether);
        staking.stake(owner, 400 ether);
        vm.expectRevert(SalaamGccStaking.StakingNotMatured.selector);
        staking.claimStakedTokens();

        skip(stakingMatured - 16 days);

        vm.expectRevert(SalaamGccStaking.StakingNotMatured.selector);
        staking.claimStakedTokens();

        vm.stopBroadcast();
    }

    function test_ClaimStakedToken_NoStake_Reverts() external {
        vm.startBroadcast(owner);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimStakedTokens();
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimStakedTokens();
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimStakedTokens();
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimStakedTokens();
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimStakedTokens();
        vm.stopBroadcast();
    }

    function test_ClaimStakedToken_Succeeds() external {
        vm.prank(minter);
        sampleToken.mint(alice, 100 ether);

        vm.prank(minter);
        sampleToken.mint(bob, 200 ether);

        vm.prank(minter);
        sampleToken.mint(oscar, 300 ether);

        vm.prank(minter);
        sampleToken.mint(charlie, 400 ether);

        skip(15 days);

        vm.startBroadcast(alice);
        sampleToken.approve(address(staking), 100 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(alice, 100 ether, 200, 200 ether);
        staking.stake(alice, 100 ether);
        vm.stopBroadcast();

        skip(30 days);

        vm.startBroadcast(bob);
        sampleToken.approve(address(staking), 200 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(bob, 200 ether, 190, 380 ether);
        staking.stake(bob, 200 ether);
        vm.stopBroadcast();

        skip(10 days);

        vm.startBroadcast(oscar);
        sampleToken.approve(address(staking), 300 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(oscar, 300 ether, 190, 570 ether);
        staking.stake(oscar, 300 ether);
        vm.stopBroadcast();

        skip(20 days);

        vm.startBroadcast(charlie);
        sampleToken.approve(address(staking), 400 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(charlie, 400 ether, 180, 720 ether);
        staking.stake(charlie, 400 ether);
        vm.stopBroadcast();

        vm.startBroadcast(owner);
        skip(stakingEnd);
        sampleToken.approve(address(staking), staking.totalRewardsSupply());
        vm.expectEmit(true, true, false, true);
        emit RewardsAdded(staking.totalRewardsSupply());
        staking.fundRewardPool();
        vm.stopBroadcast();

        skip(stakingMatured);

        vm.startBroadcast(alice);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(alice, 100 ether);
        staking.claimStakedTokens();
        assertEq(sampleToken.balanceOf(alice), 100 ether);
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(bob, 200 ether);
        staking.claimStakedTokens();
        assertEq(sampleToken.balanceOf(bob), 200 ether);
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(oscar, 300 ether);
        staking.claimStakedTokens();
        assertEq(sampleToken.balanceOf(oscar), 300 ether);
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(charlie, 400 ether);
        staking.claimStakedTokens();
        assertEq(sampleToken.balanceOf(charlie), 400 ether);
        vm.stopBroadcast();
    }
}

contract ClaimRewardsTest is StakingTest {
    function test_ClaimRewards_BeforeMaturity_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(owner, 400 ether);

        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(owner, 400 ether, 200, 800 ether);
        staking.stake(owner, 400 ether);
        vm.expectRevert(SalaamGccStaking.StakingNotMatured.selector);
        staking.claimRewards();

        skip(stakingMatured - 16 days);

        vm.expectRevert(SalaamGccStaking.StakingNotMatured.selector);
        staking.claimRewards();

        vm.stopBroadcast();
    }

    function test_ClaimRewards_NoStake_Reverts() external {
        vm.startBroadcast(owner);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimRewards();
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimRewards();
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimRewards();
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimRewards();
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.claimRewards();
        vm.stopBroadcast();
    }

    function test_ClaimRewards_Succeeds() external {
        vm.prank(minter);
        sampleToken.mint(alice, 100 ether);

        vm.prank(minter);
        sampleToken.mint(bob, 200 ether);

        vm.prank(minter);
        sampleToken.mint(oscar, 300 ether);

        vm.prank(minter);
        sampleToken.mint(charlie, 400 ether);

        skip(15 days);

        vm.startBroadcast(alice);
        sampleToken.approve(address(staking), 100 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(alice, 100 ether, 200, 200 ether);
        staking.stake(alice, 100 ether);
        vm.stopBroadcast();

        skip(30 days);

        vm.startBroadcast(bob);
        sampleToken.approve(address(staking), 200 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(bob, 200 ether, 190, 380 ether);
        staking.stake(bob, 200 ether);
        vm.stopBroadcast();

        skip(10 days);

        vm.startBroadcast(oscar);
        sampleToken.approve(address(staking), 300 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(oscar, 300 ether, 190, 570 ether);
        staking.stake(oscar, 300 ether);
        vm.stopBroadcast();

        skip(20 days);

        vm.startBroadcast(charlie);
        sampleToken.approve(address(staking), 400 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(charlie, 400 ether, 180, 720 ether);
        staking.stake(charlie, 400 ether);
        vm.stopBroadcast();

        vm.startBroadcast(owner);
        skip(stakingEnd);
        sampleToken.approve(address(staking), staking.totalRewardsSupply());
        vm.expectEmit(true, true, false, true);
        emit RewardsAdded(staking.totalRewardsSupply());
        staking.fundRewardPool();
        vm.stopBroadcast();

        skip(stakingMatured);

        vm.startBroadcast(alice);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(alice, 200 ether);
        staking.claimRewards();
        assertEq(sampleToken.balanceOf(alice), 200 ether);
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(bob, 380 ether);
        staking.claimRewards();
        assertEq(sampleToken.balanceOf(bob), 380 ether);
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(oscar, 570 ether);
        staking.claimRewards();
        assertEq(sampleToken.balanceOf(oscar), 570 ether);
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(charlie, 720 ether);
        staking.claimRewards();
        assertEq(sampleToken.balanceOf(charlie), 720 ether);
        vm.stopBroadcast();
    }
}

contract ExitTest is StakingTest {
    function test_Exit_BeforeMaturity_Reverts() external {
        vm.prank(minter);
        sampleToken.mint(owner, 400 ether);

        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);

        vm.expectEmit(true, true, false, true);
        emit Staked(owner, 400 ether, 200, 800 ether);
        staking.stake(owner, 400 ether);
        vm.expectRevert(SalaamGccStaking.StakingNotMatured.selector);
        staking.claimRewards();

        skip(stakingMatured - 16 days);

        vm.expectRevert(SalaamGccStaking.StakingNotMatured.selector);
        staking.exit();

        vm.stopBroadcast();
    }

    function test_Exit_NoStake_Reverts() external {
        vm.startBroadcast(owner);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.exit();
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.exit();
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.exit();
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.exit();
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        skip(stakingMatured);
        vm.expectRevert(SalaamGccStaking.NothingToClaim.selector);
        staking.exit();
        vm.stopBroadcast();
    }

    function test_Exit_Succeeds() external {
        vm.prank(minter);
        sampleToken.mint(alice, 100 ether);

        vm.prank(minter);
        sampleToken.mint(bob, 200 ether);

        vm.prank(minter);
        sampleToken.mint(oscar, 300 ether);

        vm.prank(minter);
        sampleToken.mint(charlie, 400 ether);

        skip(15 days);

        vm.startBroadcast(alice);
        sampleToken.approve(address(staking), 100 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(alice, 100 ether, 200, 200 ether);
        staking.stake(alice, 100 ether);
        vm.stopBroadcast();

        skip(30 days);

        vm.startBroadcast(bob);
        sampleToken.approve(address(staking), 200 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(bob, 200 ether, 190, 380 ether);
        staking.stake(bob, 200 ether);
        vm.stopBroadcast();

        skip(10 days);

        vm.startBroadcast(oscar);
        sampleToken.approve(address(staking), 300 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(oscar, 300 ether, 190, 570 ether);
        staking.stake(oscar, 300 ether);
        vm.stopBroadcast();

        skip(20 days);

        vm.startBroadcast(charlie);
        sampleToken.approve(address(staking), 400 ether);
        vm.expectEmit(true, true, false, true);
        emit Staked(charlie, 400 ether, 180, 720 ether);
        staking.stake(charlie, 400 ether);
        vm.stopBroadcast();

        vm.startBroadcast(owner);
        skip(stakingEnd);
        sampleToken.approve(address(staking), staking.totalRewardsSupply());
        vm.expectEmit(true, true, false, true);
        emit RewardsAdded(staking.totalRewardsSupply());
        staking.fundRewardPool();
        vm.stopBroadcast();

        skip(stakingMatured);

        vm.startBroadcast(alice);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(alice, 200 ether);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(alice, 100 ether);
        staking.exit();
        assertEq(sampleToken.balanceOf(alice), 300 ether);
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(bob, 380 ether);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(bob, 200 ether);
        staking.exit();
        assertEq(sampleToken.balanceOf(bob), 580 ether);
        vm.stopBroadcast();

        vm.startBroadcast(oscar);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(oscar, 570 ether);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(oscar, 300 ether);
        staking.exit();
        assertEq(sampleToken.balanceOf(oscar), 870 ether);
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        vm.expectEmit(true, true, false, true);
        emit RewardsPaid(charlie, 720 ether);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(charlie, 400 ether);
        staking.exit();
        assertEq(sampleToken.balanceOf(charlie), 1120 ether);
        vm.stopBroadcast();
    }
}

contract GetMonthlyMultiplierTest is StakingTest {
    function test_GetMonthlyMultiplier_Succeeds() external view {
        uint256 month_0_multiplier = staking.getMonthlyMultiplier(0);
        assertEq(month_0_multiplier, 0);
        uint256 month_1_multiplier = staking.getMonthlyMultiplier(1);
        assertEq(month_1_multiplier, 200);
        uint256 month_2_multiplier = staking.getMonthlyMultiplier(2);
        assertEq(month_2_multiplier, 190);
        uint256 month_3_multiplier = staking.getMonthlyMultiplier(3);
        assertEq(month_3_multiplier, 180);
        uint256 month_4_multiplier = staking.getMonthlyMultiplier(4);
        assertEq(month_4_multiplier, 170);
        uint256 month_5_multiplier = staking.getMonthlyMultiplier(5);
        assertEq(month_5_multiplier, 160);
        uint256 month_6_multiplier = staking.getMonthlyMultiplier(6);
        assertEq(month_6_multiplier, 150);
        uint256 month_7_multiplier = staking.getMonthlyMultiplier(7);
        assertEq(month_7_multiplier, 0);
    }
}

contract GetStakingInfoTest is StakingTest {
    function test_GetStakingInfo_Succeeds() external {
        (uint256 multiplier, uint256 stakedAmount, uint256 rewardsAmount, uint256 stakeStart) = staking.getStakerInfo(
            address(owner)
        );
        assertEq(multiplier, 0);
        assertEq(stakedAmount, 0);
        assertEq(rewardsAmount, 0);
        assertEq(stakeStart, 0);

        vm.startBroadcast(owner);
        skip(15 days);
        sampleToken.approve(address(staking), 400 ether);
        staking.stake(owner, 400 ether);
        vm.stopBroadcast();

        (uint256 multiplier2, uint256 stakedAmount2, uint256 rewardsAmount2, uint256 stakeStart2) = staking
            .getStakerInfo(address(owner));
        assertEq(multiplier2, 200);
        assertEq(stakedAmount2, 400 ether);
        assertEq(rewardsAmount2, 800 ether);
        assertEq(stakeStart2, block.timestamp);
    }
}

contract RecoverERC20Test is StakingTest {
    function test_RecoverERC20Test_ZeroAddress_Reverts() external {
        vm.prank(owner);
        vm.expectRevert(SalaamGccStaking.ZeroAddressNotAllowed.selector);
        staking.recoverERC20(address(0), 100 ether);
    }

    function test_RecoverERC20Test_ZeroAmount_Reverts() external {
        vm.prank(owner);
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking.recoverERC20(address(0x8), 0);
    }

    function test_RecoverERC20Test_Unauth_Reverts() external {
        vm.prank(owner);
        vm.expectRevert(SalaamGccStaking.UnauthorizedTokenRecovery.selector);
        staking.recoverERC20(sampleTokenAddress, 100 ether);
    }

    function test_RecoverERC20Test_NonOwner_Reverts() external {
        vm.prank(bob);
        vm.expectRevert();
        staking.recoverERC20(address(0x9), 100 ether);
    }
}

contract SetCapTest is StakingTest {
    function test_SetCap_StakingEnded_Reverts() external {
        skip(stakingEnd + 1 days);
        vm.prank(owner);
        vm.expectRevert(SalaamGccStaking.StakingEnded.selector);
        staking.setCap(7000000000000000 ether);
    }

    function test_SetCap_Zero_Reverts() external {
        skip(30 days);
        vm.prank(owner);
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking.setCap(0);
    }

    function test_SetCap_Succeeds() external {
        skip(30 days);

        vm.startBroadcast(owner);
        vm.expectEmit(true, true, false, true);
        emit CapChange(staking.stakingCap(), 10000000000000000000 ether);
        staking.setCap(10000000000000000000 ether);
        vm.stopBroadcast();
    }
}

contract CurrentMultiplierTest is StakingTest {
    function test_CurrentMultiplier_StakeNotStart_Reverts() external {
        vm.prank(bob);
        assertEq(staking.currentMultiplier(), 0);
    }

    function test_CurrentMultiplier_StakeEnd_Succeeds() external {
        skip(stakingEnd + 1 days);
        vm.prank(alice);
        assertEq(staking.currentMultiplier(), 150);
    }

    function test_CurrentMultiplier_Staking_Succeeds() external {
        skip(30 days);
        vm.prank(oscar);
        assertEq(staking.currentMultiplier(), 200);

        skip(60 days);
        vm.prank(charlie);
        assertEq(staking.currentMultiplier(), 180);

        skip(60 days);
        vm.prank(bob);
        assertEq(staking.currentMultiplier(), 160);

        skip(60 days);
        vm.prank(alice);
        assertEq(staking.currentMultiplier(), 150);
    }
}
