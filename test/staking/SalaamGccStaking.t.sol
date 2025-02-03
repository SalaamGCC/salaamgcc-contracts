// SPDX-License-Identifier: UNLICENSED
// solhint-disable one-contract-per-file
pragma solidity 0.8.28;

import { BaseTest } from "../BaseTest.t.sol";
import { SalaamGccStaking } from "../../src/staking/SalaamGccstaking.sol";

contract StakingTest is BaseTest {
    SalaamGccStaking public staking;
    address public stakingAddress;
    address public sampleTokenAddress;

    uint256 public rewardsDuration;
    uint256 public stakingTill;
    uint256 public stakingCap;
    uint256 public rewardRate;
    uint256 public rewardAmount;

    /* ========== EVENTS ========== */
    event RewardAdded(uint256 reward);
    event Staked(address indexed owner, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);
    event RewardPaid(address indexed owner, uint256 reward);
    event IsStakeVestedTokenChanged(bool isStakeVestedToken);
    event CapChange(uint256 oldCap, uint256 newCap);
    event Recovered(address token, uint256 amount);
    event VestingAddressChanged(address _vestingAddress);
    event Sweeped(address indexed token, uint256 amount);
    event SetSweeper(address account, bool enable);
    event StakingStopped(uint256 at);
    event StakingStart();

    /* ========== ERRORS ========== */
    error ZeroAmountNotAllowed();
    error StakingNotAllowed();
    error StakingCapExceeded();
    error StakingNotYetOver();
    error ZeroAddressNotAllowed();
    error StakeVestedTokenPaused();
    error InvalidCapLimit();
    error InvalidCaller();
    error CallerDoesNotHaveAccess();

    function setUp() public virtual override {
        super.setUp();

        sampleTokenAddress = address(sampleToken);
        rewardsDuration = 90;
        stakingTill = block.timestamp + 15 days;
        stakingCap = 150000000 ether;
        rewardRate = 20;
        rewardAmount = 2 ether;

        vm.startPrank(owner);

        staking = new SalaamGccStaking(
            sampleTokenAddress,
            sampleTokenAddress,
            rewardsDuration,
            stakingTill,
            stakingCap,
            rewardRate
        );
        stakingAddress = address(staking);
        vm.stopPrank();
    }
}

contract StakingDeployment is StakingTest {
    function testDeploymentShouldWorkCorrectly() external view {
        assertEq(address(staking.stakingToken()), sampleTokenAddress);
        assertEq(address(staking.rewardsToken()), sampleTokenAddress);
        assertEq(staking.rewardsDuration(), rewardsDuration);
        assertEq(staking.stakingTill(), stakingTill);
        assertEq(staking.stakingCap(), stakingCap);
        assertEq(staking.rewardRate(), rewardRate);

        assertEq(staking.totalSupply(), 0);
        assertEq(staking.balanceOf(owner), 0);
        assertEq(staking.rewards(owner), 0);
        assertEq(staking.owner(), address(owner));
    }

    function testDeploymentShouldRevertWhenPassedZeroAddress() external {
        vm.expectRevert(SalaamGccStaking.ZeroAddressNotAllowed.selector);
        staking = new SalaamGccStaking(
            address(0),
            sampleTokenAddress,
            rewardsDuration,
            stakingTill,
            stakingCap,
            rewardRate
        );

        vm.expectRevert(SalaamGccStaking.ZeroAddressNotAllowed.selector);
        staking = new SalaamGccStaking(
            sampleTokenAddress,
            address(0),
            rewardsDuration,
            stakingTill,
            stakingCap,
            rewardRate
        );
    }

    function testDeploymentShouldRevertWhenRewardIsZero() external {
        vm.expectRevert(SalaamGccStaking.ZeroAmountNotAllowed.selector);
        staking = new SalaamGccStaking(sampleTokenAddress, sampleTokenAddress, 0, stakingTill, stakingCap, rewardRate);
    }
}

contract TotalSupplyTest is StakingTest {
    function testTotalSupplyShouldWorkCorrectly() external {
        assertEq(staking.totalSupply(), 0);

        vm.startPrank(owner);
        sampleToken.approve(address(staking), 2 ether);
        staking.stake(owner, 2 ether);
        vm.stopPrank();

        assertEq(staking.totalSupply(), 2 ether);
    }
}

contract BalanceOfTest is StakingTest {
    function testBalanceOfShouldWorkCorrectly() external {
        assertEq(staking.balanceOf(owner), 0);

        vm.startPrank(owner);
        sampleToken.approve(address(staking), 2 ether);
        staking.stake(owner, 2 ether);
        vm.stopPrank();

        assertEq(staking.balanceOf(owner), 2 ether);
    }
}

contract SetIsWithdrawEnableTest is StakingTest {
    function testSetIsWithdrawEnableShouldWorkCorrectly() external {
        vm.startPrank(owner);
        staking.setIsWithdrawEnable(true);
        assertEq(staking.isWithdrawEnable(), true);
        staking.setIsWithdrawEnable(false);
        assertEq(staking.isWithdrawEnable(), false);
        vm.stopPrank();
    }

    function testRevertWhenSetIsWithdrawEnableCallerIsNotOwner() external {
        vm.startPrank(adminOne);
        vm.expectRevert();
        staking.setIsWithdrawEnable(true);
        vm.stopPrank();
    }
}

contract StakingFunctionalityTest is StakingTest {
    function testStakeShouldWorkCorrectly() external {
        uint256 amount = 1000 ether;
        vm.startPrank(owner);
        sampleToken.approve(stakingAddress, amount);
        staking.stake(owner, amount);
        vm.stopPrank();

        assertEq(staking.balanceOf(owner), amount);
    }

    function testRevertWhenStakeExceedsCap() external {
        uint256 amount = stakingCap + 1 ether;
        vm.startPrank(owner);
        sampleToken.approve(stakingAddress, amount);
        vm.expectRevert();
        staking.stake(owner, amount);
        vm.stopPrank();
    }
}

contract WithdrawFunctionalityTest is StakingTest {
    function testWithdrawShouldWorkCorrectly() external {
        uint256 amount = 1000 ether;
        vm.startPrank(owner);
        staking.setIsWithdrawEnable(true);
        sampleToken.approve(stakingAddress, amount);
        staking.stake(owner, amount);
        staking.withdraw(amount);
        vm.stopPrank();

        assertEq(staking.balanceOf(owner), 0);
    }

    function testRevertWhenWithdrawDisabled() external {
        uint256 amount = 1000 ether;
        vm.startPrank(owner);
        staking.setIsWithdrawEnable(false);
        vm.stopPrank();

        vm.startPrank(owner);
        sampleToken.approve(stakingAddress, amount);
        staking.stake(owner, amount);
        vm.expectRevert();
        staking.withdraw(amount);
        vm.stopPrank();
    }
}

contract RewardFunctionalityTest is StakingTest {
    function testClaimRewardsShouldWorkCorrectly() external {
        uint256 amount = 1000 ether;
        vm.startPrank(owner);
        staking.setIsWithdrawEnable(true);
        sampleToken.approve(stakingAddress, amount);
        staking.stake(owner, amount);
        vm.warp(block.timestamp + rewardsDuration);
        staking.getReward();
        vm.stopPrank();
    }
}

contract AdminFunctionsTest is StakingTest {
    function testSetCapShouldWorkCorrectly() external {
        uint256 newCap = 200000000 ether;
        vm.startPrank(owner);
        staking.setCap(newCap);
        vm.stopPrank();

        assertEq(staking.stakingCap(), newCap);
    }

    function testStartStaking() external {
        vm.startPrank(owner);
        staking.startStaking();
        vm.stopPrank();
    }

    function testStopStaking() external {
        vm.startPrank(owner);
        staking.stopStaking();
        vm.stopPrank();
    }

    function testSetSweeper() external {
        vm.startPrank(owner);
        staking.setSweeper(owner, true);
        vm.stopPrank();
    }

    function testSweep() external {
        uint256 amount = 1000 ether;
        vm.startPrank(owner);
        sampleToken.approve(stakingAddress, amount);
        staking.stake(owner, amount);
        staking.sweep(sampleTokenAddress, amount);
        vm.stopPrank();
    }

    function testRecoverERC20() external {
        uint256 amount = 1000 ether;
        vm.startPrank(owner);
        sampleToken.approve(stakingAddress, amount);
        staking.stake(owner, amount);
        staking.recoverERC20(sampleTokenAddress, amount);
        vm.stopPrank();
    }
}
