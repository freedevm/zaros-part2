// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { MockUsdToken } from "test/mocks/MockUsdToken.sol";

// Mock dependencies
import { MockEngine } from "test/mocks/MockEngine.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

// Markets
import { BtcPerpMarketCreditConfig } from "script/perp-markets-credit-config/BtcPerpMarketCreditConfig.sol";
import { EthPerpMarketCreditConfig } from "script/perp-markets-credit-config/EthPerpMarketCreditConfig.sol";
import { ArbPerpMarketCreditConfig } from "script/perp-markets-credit-config/ArbPerpMarketCreditConfig.sol";
import { BnbPerpMarketCreditConfig } from "script/perp-markets-credit-config/BnbPerpMarketCreditConfig.sol";
import { DogePerpMarketCreditConfig } from "script/perp-markets-credit-config/DogePerpMarketCreditConfig.sol";
import { FtmPerpMarketCreditConfig } from "script/perp-markets-credit-config/FtmPerpMarketCreditConfig.sol";
import { LinkPerpMarketCreditConfig } from "script/perp-markets-credit-config/LinkPerpMarketCreditConfig.sol";
import { LtcPerpMarketCreditConfig } from "script/perp-markets-credit-config/LtcPerpMarketCreditConfig.sol";
import { MaticPerpMarketCreditConfig } from "script/perp-markets-credit-config/MaticPerpMarketCreditConfig.sol";
import { SolPerpMarketCreditConfig } from "script/perp-markets-credit-config/SolPerpMarketCreditConfig.sol";

/// @notice PerpMarketsCreditConfig contract
abstract contract PerpMarketsCreditConfig is
    StdCheats,
    StdUtils,
    BtcPerpMarketCreditConfig,
    EthPerpMarketCreditConfig,
    ArbPerpMarketCreditConfig,
    BnbPerpMarketCreditConfig,
    DogePerpMarketCreditConfig,
    FtmPerpMarketCreditConfig,
    LinkPerpMarketCreditConfig,
    LtcPerpMarketCreditConfig,
    MaticPerpMarketCreditConfig,
    SolPerpMarketCreditConfig
{
    /// @notice Perp Market Credit Config
    /// @param engine Engine address
    /// @param marketId Market id
    /// @param autoDeleverageStartThreshold Auto deleverage start threshold
    /// @param autoDeleverageEndThreshold Auto deleverage end threshold
    /// @param autoDeleverageExpoentZ Auto deleverage power scale
    struct PerpMarketCreditConfig {
        address engine;
        address usdToken;
        uint128 marketId;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleverageExpoentZ;
    }

    /// @notice Configure market params
    /// @param marketMakingEngine Market making engine
    /// @param initialMarketId Initial market id
    /// @param finalMarketId Final market id
    struct ConfigureMarketParams {
        IMarketMakingEngine marketMakingEngine;
        uint256 initialMarketId;
        uint256 finalMarketId;
    }

    /// @notice Perp market credit configurations mapped by market id.
    mapping(uint256 marketId => PerpMarketCreditConfig marketConfig) internal perpMarketsCreditConfig;

    /// @notice Setup perp markets credit config
    /// @param isTest When isTest is True a new mock engine will created for a each perp market using the initParams
    /// variable
    /// @param engine Only used when isTest is true
    /// @param usdToken Only used when isTest is true
    function setupPerpMarketsCreditConfig(bool isTest, address engine, address usdToken) internal {
        perpMarketsCreditConfig[BTC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : BTC_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : BTC_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: BTC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[ETH_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : ETH_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : ETH_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: ETH_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[SOL_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : SOL_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : SOL_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: SOL_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[MATIC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : MATIC_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : MATIC_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: MATIC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: MATIC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: MATIC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: MATIC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[LTC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : LTC_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : LTC_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: LTC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: LTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: LTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: LTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[LINK_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : LINK_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : LINK_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: LINK_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: LINK_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: LINK_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: LINK_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[FTM_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : FTM_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : FTM_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: FTM_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: FTM_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: FTM_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: FTM_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[DOGE_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : DOGE_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : DOGE_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: DOGE_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: DOGE_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: DOGE_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: DOGE_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[BNB_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : BNB_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : BNB_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: BNB_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: BNB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: BNB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: BNB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[ARB_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? engine : ARB_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            usdToken: isTest ? usdToken : ARB_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN,
            marketId: ARB_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: ARB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: ARB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: ARB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });
    }

    /// @notice Get filtered perp markets credit config
    /// @param marketsIdsRange Markets ids range
    function getFilteredPerpMarketsCreditConfig(uint256[2] memory marketsIdsRange)
        internal
        view
        returns (PerpMarketCreditConfig[] memory)
    {
        uint256 initialMarketId = marketsIdsRange[0];
        uint256 finalMarketId = marketsIdsRange[1];
        uint256 filteredMarketsLength = finalMarketId - initialMarketId + 1;

        PerpMarketCreditConfig[] memory filteredPerpMarketsCreditConfig =
            new PerpMarketCreditConfig[](filteredMarketsLength);

        uint256 nextMarketId = initialMarketId;
        for (uint256 i; i < filteredMarketsLength; i++) {
            filteredPerpMarketsCreditConfig[i] = perpMarketsCreditConfig[nextMarketId];
            nextMarketId++;
        }

        return filteredPerpMarketsCreditConfig;
    }

    /// @notice Configure markets
    /// @param params Configure market params
    function configureMarkets(ConfigureMarketParams memory params) public {
        for (uint256 i = params.initialMarketId; i <= params.finalMarketId; i++) {
            params.marketMakingEngine.configureMarket(
                perpMarketsCreditConfig[i].engine,
                perpMarketsCreditConfig[i].marketId,
                perpMarketsCreditConfig[i].autoDeleverageStartThreshold,
                perpMarketsCreditConfig[i].autoDeleverageEndThreshold,
                perpMarketsCreditConfig[i].autoDeleverageExpoentZ
            );

            params.marketMakingEngine.unpauseMarket(perpMarketsCreditConfig[i].marketId);

            params.marketMakingEngine.configureEngine(
                address(perpMarketsCreditConfig[i].engine), perpMarketsCreditConfig[i].usdToken, true
            );
        }
    }
}
