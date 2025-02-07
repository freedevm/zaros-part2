// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";

contract CollateralHarness {
    function exposed_Collateral_load(address asset) external pure returns (Collateral.Data memory) {
        Collateral.Data storage self = Collateral.load(asset);
        return self;
    }

    function workaround_Collateral_setParams(
        address asset,
        uint256 creditRatio,
        bool isEnabled,
        uint8 decimals,
        address priceAdapter
    )
        external
    {
        Collateral.Data storage self = Collateral.load(asset);
        self.asset = asset;
        self.creditRatio = creditRatio;
        self.isEnabled = isEnabled;
        self.decimals = decimals;
        self.priceAdapter = priceAdapter;
    }
}
