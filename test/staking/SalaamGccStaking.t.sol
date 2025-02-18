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

    uint256 stakingStart = block.timestamp + 15 days;
    uint256 stakingEnd = stakingStart + 183 days;
    uint256 stakingMatured = stakingEnd + (rewardsDuration * 1 days);
    uint256 rewardsDuration = 365;
    uint256[] multipliers = [200, 190, 180, 170, 160, 150];
    uint256 lastStakingMonth = multipliers.length;

    uint256 stakingCap = 100000000 ether;

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
}

contract GetStakingInfoTest is StakingTest {
    function testGetStakingInfoShouldWorkCorrectly() external {
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

// contract SetIsWithdrawEnableTest is StakingTest {
//     function testSetIsWithdrawEnableShouldWorkCorrectly() external {
//         vm.startPrank(owner);
//         staking.setIsWithdrawEnable(true);
//         assertEq(staking.isWithdrawEnable(), true);
//         staking.setIsWithdrawEnable(false);
//         assertEq(staking.isWithdrawEnable(), false);
//         vm.stopPrank();
//     }

//     function testRevertWhenSetIsWithdrawEnableCallerIsNotOwner() external {
//         vm.startPrank(adminOne);
//         vm.expectRevert();
//         staking.setIsWithdrawEnable(true);
//         vm.stopPrank();
//     }
// }

// contract StakingFunctionalityTest is StakingTest {
//     function testStakeShouldWorkCorrectly() external {
//         uint256 amount = 1000 ether;
//         vm.startPrank(owner);
//         sampleToken.approve(stakingAddress, amount);
//         staking.stake(owner, amount);
//         vm.stopPrank();

//         assertEq(staking.balanceOf(owner), amount);
//     }

//     function testRevertWhenStakeExceedsCap() external {
//         uint256 amount = stakingCap + 1 ether;
//         vm.startPrank(owner);
//         sampleToken.approve(stakingAddress, amount);
//         vm.expectRevert();
//         staking.stake(owner, amount);
//         vm.stopPrank();
//     }
// }

// contract WithdrawFunctionalityTest is StakingTest {
//     function testWithdrawShouldWorkCorrectly() external {
//         uint256 amount = 1000 ether;
//         vm.startPrank(owner);
//         staking.setIsWithdrawEnable(true);
//         sampleToken.approve(stakingAddress, amount);
//         staking.stake(owner, amount);
//         staking.withdraw(amount);
//         vm.stopPrank();

//         assertEq(staking.balanceOf(owner), 0);
//     }

//     function testRevertWhenWithdrawDisabled() external {
//         uint256 amount = 1000 ether;
//         vm.startPrank(owner);
//         staking.setIsWithdrawEnable(false);
//         vm.stopPrank();

//         vm.startPrank(owner);
//         sampleToken.approve(stakingAddress, amount);
//         staking.stake(owner, amount);
//         vm.expectRevert();
//         staking.withdraw(amount);
//         vm.stopPrank();
//     }
// }

// contract RewardFunctionalityTest is StakingTest {
//     function testClaimRewardsShouldWorkCorrectly() external {
//         uint256 amount = 1000 ether;
//         vm.startPrank(owner);
//         staking.setIsWithdrawEnable(true);
//         sampleToken.approve(stakingAddress, amount);
//         staking.stake(owner, amount);
//         vm.warp(block.timestamp + rewardsDuration);
//         staking.getReward();
//         vm.stopPrank();
//     }
// }

// contract AdminFunctionsTest is StakingTest {
//     function testSetCapShouldWorkCorrectly() external {
//         uint256 newCap = 200000000 ether;
//         vm.startPrank(owner);
//         staking.setCap(newCap);
//         vm.stopPrank();

//         assertEq(staking.stakingCap(), newCap);
//     }

//     function testStartStaking() external {
//         vm.startPrank(owner);
//         staking.startStaking();
//         vm.stopPrank();
//     }

//     function testStopStaking() external {
//         vm.startPrank(owner);
//         staking.stopStaking();
//         vm.stopPrank();
//     }

//     function testSetSweeper() external {
//         vm.startPrank(owner);
//         staking.setSweeper(owner, true);
//         vm.stopPrank();
//     }

//     function testSweep() external {
//         uint256 amount = 1000 ether;
//         vm.startPrank(owner);
//         sampleToken.approve(stakingAddress, amount);
//         staking.stake(owner, amount);
//         staking.sweep(sampleTokenAddress, amount);
//         vm.stopPrank();
//     }

//     function testRecoverERC20() external {
//         uint256 amount = 1000 ether;
//         vm.startPrank(owner);
//         sampleToken.approve(stakingAddress, amount);
//         staking.stake(owner, amount);
//         staking.recoverERC20(sampleTokenAddress, amount);
//         vm.stopPrank();
//     }
// }
