// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { BaseScript } from "script/Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";

contract UpdateSettlementConfiguration is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    bytes32 internal maticUsdStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;
    address internal maticUsdMarketOrderKeeper;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        // get the perps engine
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        // get the matic usd stream id
        maticUsdStreamId = MATIC_USD_STREAM_ID;

        // get the chainlink verifier
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));

        // get the matic usd market order keeper
        maticUsdMarketOrderKeeper = vm.envAddress("MATIC_USD_MARKET_ORDER_KEEPER");

        // create the matic usd market order configuration data
        SettlementConfiguration.DataStreamsStrategy memory maticUsdMarketOrderConfigurationData =
        SettlementConfiguration.DataStreamsStrategy({
            chainlinkVerifier: chainlinkVerifier,
            streamId: maticUsdStreamId
        });

        // create the matic usd market order configuration
        SettlementConfiguration.Data memory maticUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: maticUsdMarketOrderKeeper,
            data: abi.encode(maticUsdMarketOrderConfigurationData)
        });

        // update the matic usd market order configuration
        perpsEngine.updateSettlementConfiguration(
            MATIC_USD_MARKET_ID,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            maticUsdMarketOrderConfiguration
        );
    }
}
