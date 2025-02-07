// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { StabilityConfiguration } from "@zaros/market-making/leaves/StabilityConfiguration.sol";

contract StabilityConfigurationHarness {
    function exposed_StabilityConfiguration_load() external pure returns (StabilityConfiguration.Data memory) {
        StabilityConfiguration.Data storage self = StabilityConfiguration.load();
        return self;
    }
}
