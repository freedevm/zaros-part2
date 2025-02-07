// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IEngine } from "@zaros/market-making/interfaces/IEngine.sol";
import { IMockEngine } from "test/mocks/IMockEngine.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

contract MockEngine is PerpsEngine, IEngine, IMockEngine {
    constructor(InitParams memory initParams) PerpsEngine(initParams) { }

    int256 public totalDebt;

    function getUnrealizedDebt(uint128) external view override returns (int256) {
        return totalDebt;
    }

    function setUnrealizedDebt(int256 newDebt) external {
        totalDebt = newDebt;
    }
}
