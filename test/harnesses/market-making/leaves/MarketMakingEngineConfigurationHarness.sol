// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

contract MarketMakingEngineConfigurationHarness {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    function workaround_setWethAddress(address wethAddr) external returns (address) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        data.weth = wethAddr;
        return data.weth;
    }

    function workaround_getWethAddress() external view returns (address) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        return data.weth;
    }

    function exposed_getTotalFeeRecipientsShares() external view returns (uint256) {
        MarketMakingEngineConfiguration.Data storage self = MarketMakingEngineConfiguration.load();
        return uint256(self.totalFeeRecipientsShares);
    }

    function workaround_getIfSystemKeeperIsEnabled(address systemKeeper) external view returns (bool) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        return data.isSystemKeeperEnabled[systemKeeper];
    }

    function workaround_getFeeRecipientShare(address feeRecipient) external view returns (uint256) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        return data.protocolFeeRecipients.get(feeRecipient);
    }

    function workaround_getIfEngineIsRegistered(address engine) external view returns (bool) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        return data.isRegisteredEngine[engine];
    }

    function workaround_getUsdTokenOfEngine(address engine) external view returns (address) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        return data.usdTokenOfEngine[engine];
    }
}
