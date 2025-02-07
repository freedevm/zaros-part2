// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { PerpsEngineConfiguration } from "@zaros/perpetuals/leaves/PerpsEngineConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract PerpsEngineConfigurationHarness {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    function workaround_getLiquidationFeeUsdX18() external view returns (uint128) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();

        return self.liquidationFeeUsdX18;
    }

    function workaround_getMaxPositionsPerAccount() external view returns (uint128) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();

        return self.maxPositionsPerAccount;
    }

    function workaround_getCollateralLiquidationPriority() external view returns (address[] memory) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();
        uint256 length = self.collateralLiquidationPriority.length();

        address[] memory collateralLiquidationPriority = new address[](length);

        for (uint256 i; i < length; i++) {
            collateralLiquidationPriority[i] = self.collateralLiquidationPriority.at(i);
        }

        return collateralLiquidationPriority;
    }

    function workaround_getTradingAccountToken() external view returns (address) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();

        return self.tradingAccountToken;
    }

    function workaround_getUsdToken() external view returns (address) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();

        return self.usdToken;
    }

    function workaround_getAccountIdWithActivePositions(uint128 index) external view returns (uint128) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();

        return uint128(self.accountsIdsWithActivePositions.at(index));
    }

    function workaround_getAccountsIdsWithActivePositionsLength() external view returns (uint256) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();

        return self.accountsIdsWithActivePositions.length();
    }

    function exposed_checkMarketIsEnabled(uint128 marketId) external view {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();
        PerpsEngineConfiguration.checkMarketIsEnabled(self, marketId);
    }

    function exposed_addMarket(uint128 marketId) external {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();
        PerpsEngineConfiguration.addMarket(self, marketId);
    }

    function exposed_removeMarket(uint128 marketId) external {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();
        PerpsEngineConfiguration.removeMarket(self, marketId);
    }

    function exposed_configureCollateralLiquidationPriority(address[] memory collateralTokens) external {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();
        PerpsEngineConfiguration.configureCollateralLiquidationPriority(self, collateralTokens);
    }

    function exposed_removeCollateralFromLiquidationPriority(address collateralToken) external {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();
        PerpsEngineConfiguration.removeCollateralFromLiquidationPriority(self, collateralToken);
    }

    function workaround_getReferralModule() external view returns (address) {
        PerpsEngineConfiguration.Data storage self = PerpsEngineConfiguration.load();
        return self.referralModule;
    }
}
