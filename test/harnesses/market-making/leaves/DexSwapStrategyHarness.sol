// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";

contract DexSwapStrategyHarness {
    function exposed_dexSwapStrategy_load(uint128 dexSwapStrategyId)
        external
        pure
        returns (DexSwapStrategy.Data memory)
    {
        DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.load(dexSwapStrategyId);
        return dexSwapStrategy;
    }
}
