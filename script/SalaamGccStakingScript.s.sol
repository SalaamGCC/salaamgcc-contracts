// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { console } from "lib/forge-std/src/console.sol";

import { SalaamGccStaking } from "../src/staking/SalaamGccStaking.sol";

contract StakingScript is Script {
    function test() public {}
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /// replace below with actual values
        address stakingToken = 0x6Cea0415F4b534edfcAF7cE8bc32bf704b18C5c3;
        address rewardToken = 0x6Cea0415F4b534edfcAF7cE8bc32bf704b18C5c3;
        uint256 rewardsDuration = 365;
        uint256 stakingStart = 1739993400;
        uint256 stakingEnd = 1755631800;
        uint256 stakingCap = 100000000 ether;
        uint256[] memory multipliers;
        multipliers[0] = 200;
        multipliers[1] = 190;
        multipliers[2] = 180;
        multipliers[3] = 170;
        multipliers[4] = 160;
        multipliers[0] = 150;

        SalaamGccStaking staking = new SalaamGccStaking(
            stakingToken,
            rewardToken,
            rewardsDuration,
            stakingStart,
            stakingEnd,
            stakingCap,
            multipliers
        );

        vm.stopBroadcast();
        console.log("Contract deployed at: ", address(staking));
    }
}
