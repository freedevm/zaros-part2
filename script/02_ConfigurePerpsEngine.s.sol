// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { TradingAccountNFT } from "@zaros/trading-account-nft/TradingAccountNFT.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigurePerpsEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal usdToken;
    address internal liquidationKeeper;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    TradingAccountNFT internal tradingAccountToken;
    IPerpsEngine internal perpsEngine;
    IMarketMakingEngine internal marketMakingEngine;
    IReferral internal referralModule;

    function run(uint256 initialMarginCollateralId, uint256 finalMarginCollateralId) public broadcaster {
        tradingAccountToken = TradingAccountNFT(vm.envAddress("TRADING_ACCOUNT_NFT"));
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));
        usdToken = vm.envAddress("USD_TOKEN");
        liquidationKeeper = vm.envAddress("LIQUIDATION_KEEPER");
        referralModule = IReferral(vm.envAddress("REFERRAL_MODULE"));

        configureContracts(initialMarginCollateralId, finalMarginCollateralId);
    }

    function configureContracts(uint256 initialMarginCollateralId, uint256 finalMarginCollateralId) internal {
        tradingAccountToken.transferOwnership(address(perpsEngine));

        perpsEngine.setTradingAccountToken(address(tradingAccountToken));

        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMinLifetime: MARKET_ORDER_MIN_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD,
            marginCollateralRecipient: MSIG_ADDRESS,
            orderFeeRecipient: MSIG_ADDRESS,
            settlementFeeRecipient: MSIG_ADDRESS,
            liquidationFeeRecipient: MSIG_ADDRESS,
            marketMakingEngine: address(marketMakingEngine),
            referralModule: address(referralModule),
            whitelist: address(0),
            maxVerificationDelay: MAX_VERIFICATION_DELAY,
            isWhitelistMode: false
        });

        setupSequencerUptimeFeeds();

        uint256[2] memory marginCollateralIdsRange;
        marginCollateralIdsRange[0] = initialMarginCollateralId;
        marginCollateralIdsRange[1] = finalMarginCollateralId;

        configureMarginCollaterals(
            perpsEngine, marginCollateralIdsRange, false, sequencerUptimeFeedByChainId[block.chainid], deployer
        );

        address[] memory liquidators = new address[](1);
        bool[] memory liquidatorStatus = new bool[](1);

        liquidators[0] = liquidationKeeper;
        liquidatorStatus[0] = true;

        console.log("**************************");
        console.log("Configuring liquidators...");
        console.log("**************************");

        perpsEngine.configureLiquidators(liquidators, liquidatorStatus);

        console.log("Success! Liquidator address:");
        console.log("\n");
        console.log(liquidators[0]);

        console.log("**************************");
        console.log("Configuring USD Token token...");
        console.log("**************************");

        perpsEngine.setUsdToken(usdToken);

        console.log("Success! USD Token token address:");
        console.log("\n");
        console.log(usdToken);

        console.log("**************************");
        console.log("Configuring trading account token...");
        console.log("**************************");

        perpsEngine.setTradingAccountToken(address(tradingAccountToken));

        console.log("Success! Trading account token address:");
        console.log("\n");
        console.log(address(tradingAccountToken));

        console.log("**************************");
        console.log("Transferring USD Token ownership to the market making engine...");
        console.log("**************************");

        // NOTE: Once the MM engine v1 is deployed, USD Token ownership must be transferred to the MM engine.
        LimitedMintingERC20(USD_TOKEN_ADDRESS).transferOwnership(address(perpsEngine));

        console.log("Success! USD Token token ownership transferred to the market making engine.");
    }
}
