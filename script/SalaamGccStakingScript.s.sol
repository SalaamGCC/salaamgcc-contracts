// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { console } from "lib/forge-std/src/console.sol";

import { SalaamGccStaking } from "../src/staking/SalaamGccStaking.sol";

contract StakingScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /// replace below with actual values
        address stakingToken = 0x6Cea0415F4b534edfcAF7cE8bc32bf704b18C5c3;
        address rewardToken = 0x6Cea0415F4b534edfcAF7cE8bc32bf704b18C5c3;
        uint256 rewardsDuration = 150;
        uint256 stakingTill = 1723726800;
        uint256 stakingCap = 150000000 ether;
        uint256 rewardRate = 30;

        SalaamGccStaking staking = new SalaamGccStaking(
            stakingToken,
            rewardToken,
            rewardsDuration,
            stakingTill,
            stakingCap,
            rewardRate
        );

        vm.stopBroadcast();
        console.log("Contract deployed at: ", address(staking));
    }
}
