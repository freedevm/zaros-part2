// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { BaseScript } from "script/Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";

contract UpdatePerpMarketConfiguration is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    bytes32 internal solUsdStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;
    address internal solUsdMarketOrderKeeper;
    IPerpsEngine internal perpsEngine;

    function run(uint128 marketId) public broadcaster {
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        setupSequencerUptimeFeeds();

        setupMarketsConfig(sequencerUptimeFeedByChainId[block.chainid], deployer);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: marketsConfig[marketId].marketName,
            symbol: marketsConfig[marketId].marketSymbol,
            priceAdapter: marketsConfig[marketId].priceAdapter,
            initialMarginRateX18: marketsConfig[marketId].imr,
            maintenanceMarginRateX18: marketsConfig[marketId].mmr,
            maxOpenInterest: marketsConfig[marketId].maxOi,
            maxSkew: marketsConfig[marketId].maxSkew,
            maxFundingVelocity: marketsConfig[marketId].maxFundingVelocity,
            minTradeSizeX18: marketsConfig[marketId].minTradeSize,
            skewScale: marketsConfig[marketId].skewScale,
            orderFees: marketsConfig[marketId].orderFees
        });

        perpsEngine.updatePerpMarketConfiguration(marketId, params);
    }
}
