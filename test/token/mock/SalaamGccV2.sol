// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SalaamGcc } from "../../../src/token/SalaamGcc.sol";
contract SalaamGccV2 is SalaamGcc {
    string public version;

    function upgradeVersion() public {
        version = "v2";
    }

    function test() public {}
}
