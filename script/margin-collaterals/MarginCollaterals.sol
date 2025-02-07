// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Margin Collaterals
import { UsdToken } from "script/margin-collaterals/Usdz.sol";
import { Usdc } from "script/margin-collaterals/Usdc.sol";
import { WEth } from "script/margin-collaterals/WEth.sol";
import { WBtc } from "script/margin-collaterals/WBtc.sol";
import { WstEth } from "script/margin-collaterals/WstEth.sol";
import { WeEth } from "script/margin-collaterals/WeEth.sol";

// Zaros dependencies
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockUsdToken } from "test/mocks/MockUsdToken.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";
import { PriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { PriceAdapterUtils } from "script/utils/PriceAdapterUtils.sol";

abstract contract MarginCollaterals is UsdToken, Usdc, WEth, WBtc, WstEth, WeEth {
    struct MarginCollateral {
        string name;
        string symbol;
        uint256 marginCollateralId;
        uint128 depositCap;
        uint120 loanToValue;
        uint256 minDepositMargin;
        uint256 mockUsdPrice;
        address marginCollateralAddress;
        address priceAdapter;
        uint256 liquidationPriority;
        uint8 tokenDecimals;
    }

    mapping(uint256 marginCollateralId => MarginCollateral marginCollateral) internal marginCollaterals;

    function setupMarginCollaterals(address sequencerUptimeFeed, address priceAdapterOwner) internal {
        MarginCollateral memory usdcConfig = MarginCollateral({
            name: USDC_NAME,
            symbol: USDC_SYMBOL,
            marginCollateralId: USDC_MARGIN_COLLATERAL_ID,
            depositCap: USDC_DEPOSIT_CAP_X18.intoUint128(),
            loanToValue: USDC_LOAN_TO_VALUE,
            minDepositMargin: USDC_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_USDC_USD_PRICE,
            marginCollateralAddress: USDC_ADDRESS,
            priceAdapter: address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: USDC_PRICE_ADAPTER_NAME,
                        symbol: USDC_PRICE_ADAPTER_SYMBOL,
                        owner: priceAdapterOwner,
                        priceFeed: USDC_PRICE_FEED,
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: sequencerUptimeFeed,
                        priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            ),
            liquidationPriority: USDC_LIQUIDATION_PRIORITY,
            tokenDecimals: USDC_DECIMALS
        });
        marginCollaterals[USDC_MARGIN_COLLATERAL_ID] = usdcConfig;

        MarginCollateral memory usdTokenConfig = MarginCollateral({
            name: USD_TOKEN_NAME,
            symbol: USD_TOKEN_SYMBOL,
            marginCollateralId: USD_TOKEN_MARGIN_COLLATERAL_ID,
            depositCap: USD_TOKEN_DEPOSIT_CAP_X18.intoUint128(),
            loanToValue: USD_TOKEN_LOAN_TO_VALUE,
            minDepositMargin: USD_TOKEN_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_USD_TOKEN_USD_PRICE,
            marginCollateralAddress: USD_TOKEN_ADDRESS,
            priceAdapter: address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: USD_TOKEN_PRICE_ADAPTER_NAME,
                        symbol: USD_TOKEN_PRICE_ADAPTER_SYMBOL,
                        owner: priceAdapterOwner,
                        priceFeed: USD_TOKEN_PRICE_FEED,
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: sequencerUptimeFeed,
                        priceFeedHeartbeatSeconds: USD_TOKEN_PRICE_FEED_HEARBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            ),
            liquidationPriority: USD_TOKEN_LIQUIDATION_PRIORITY,
            tokenDecimals: USD_TOKEN_DECIMALS
        });
        marginCollaterals[USD_TOKEN_MARGIN_COLLATERAL_ID] = usdTokenConfig;

        MarginCollateral memory wEth = MarginCollateral({
            name: WETH_NAME,
            symbol: WETH_SYMBOL,
            marginCollateralId: WETH_MARGIN_COLLATERAL_ID,
            depositCap: WETH_DEPOSIT_CAP_X18.intoUint128(),
            loanToValue: WETH_LOAN_TO_VALUE,
            minDepositMargin: WETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WETH_USD_PRICE,
            marginCollateralAddress: WETH_ADDRESS,
            priceAdapter: address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WETH_PRICE_ADAPTER_NAME,
                        symbol: WETH_PRICE_ADAPTER_SYMBOL,
                        owner: priceAdapterOwner,
                        priceFeed: WETH_PRICE_FEED,
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: sequencerUptimeFeed,
                        priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            ),
            liquidationPriority: WETH_LIQUIDATION_PRIORITY,
            tokenDecimals: WETH_DECIMALS
        });
        marginCollaterals[WETH_MARGIN_COLLATERAL_ID] = wEth;

        MarginCollateral memory weEth = MarginCollateral({
            name: WEETH_NAME,
            symbol: WEETH_SYMBOL,
            marginCollateralId: WEETH_MARGIN_COLLATERAL_ID,
            depositCap: WEETH_DEPOSIT_CAP_X18.intoUint128(),
            loanToValue: WEETH_LOAN_TO_VALUE,
            minDepositMargin: WEETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WEETH_USD_PRICE,
            marginCollateralAddress: WEETH_ADDRESS,
            priceAdapter: address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WEETH_PRICE_ADAPTER_NAME,
                        symbol: WEETH_PRICE_ADAPTER_SYMBOL,
                        owner: priceAdapterOwner,
                        priceFeed: WEETH_PRICE_FEED,
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: sequencerUptimeFeed,
                        priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            ),
            liquidationPriority: WEETH_LIQUIDATION_PRIORITY,
            tokenDecimals: WEETH_DECIMALS
        });
        marginCollaterals[WEETH_MARGIN_COLLATERAL_ID] = weEth;

        MarginCollateral memory wBtc = MarginCollateral({
            name: WBTC_NAME,
            symbol: WBTC_SYMBOL,
            marginCollateralId: WBTC_MARGIN_COLLATERAL_ID,
            depositCap: WBTC_DEPOSIT_CAP_X18.intoUint128(),
            loanToValue: WBTC_LOAN_TO_VALUE,
            minDepositMargin: WBTC_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WBTC_USD_PRICE,
            marginCollateralAddress: WBTC_ADDRESS,
            priceAdapter: address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WBTC_PRICE_ADAPTER_NAME,
                        symbol: WBTC_PRICE_ADAPTER_SYMBOL,
                        owner: priceAdapterOwner,
                        priceFeed: WBTC_PRICE_FEED,
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: sequencerUptimeFeed,
                        priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            ),
            liquidationPriority: WBTC_LIQUIDATION_PRIORITY,
            tokenDecimals: WBTC_DECIMALS
        });
        marginCollaterals[WBTC_MARGIN_COLLATERAL_ID] = wBtc;

        MarginCollateral memory wstEth = MarginCollateral({
            name: WSTETH_NAME,
            symbol: WSTETH_SYMBOL,
            marginCollateralId: WSTETH_MARGIN_COLLATERAL_ID,
            depositCap: WSTETH_DEPOSIT_CAP_X18.intoUint128(),
            loanToValue: WSTETH_LOAN_TO_VALUE,
            minDepositMargin: WSTETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WSTETH_USD_PRICE,
            marginCollateralAddress: WSTETH_ADDRESS,
            priceAdapter: address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WSTETH_PRICE_ADAPTER_NAME,
                        symbol: WSTETH_PRICE_ADAPTER_SYMBOL,
                        owner: priceAdapterOwner,
                        priceFeed: WSTETH_PRICE_FEED,
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: sequencerUptimeFeed,
                        priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            ),
            liquidationPriority: WSTETH_LIQUIDATION_PRIORITY,
            tokenDecimals: WSTETH_DECIMALS
        });
        marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID] = wstEth;
    }

    function getFilteredMarginCollateralsConfig(uint256[2] memory marginCollateralIdsRange)
        internal
        view
        returns (MarginCollateral[] memory)
    {
        uint256 initialMarginCollateralId = marginCollateralIdsRange[0];
        uint256 finalMarginCollateralId = marginCollateralIdsRange[1];
        uint256 filteredMarketsLength = finalMarginCollateralId - initialMarginCollateralId + 1;

        MarginCollateral[] memory filteredMarginCollateralsConfig = new MarginCollateral[](filteredMarketsLength);

        uint256 nextMarginCollateralId = initialMarginCollateralId;
        for (uint256 i; i < filteredMarketsLength; i++) {
            filteredMarginCollateralsConfig[i] = marginCollaterals[nextMarginCollateralId];
            nextMarginCollateralId++;
        }

        return filteredMarginCollateralsConfig;
    }

    function configureMarginCollaterals(
        IPerpsEngine perpsEngine,
        uint256[2] memory marginCollateralIdsRange,
        bool isTest,
        address sequencerUptimeFeed,
        address owner
    )
        internal
    {
        setupMarginCollaterals(sequencerUptimeFeed, owner);

        MarginCollateral[] memory filteredMarginCollateralsConfig =
            getFilteredMarginCollateralsConfig(marginCollateralIdsRange);

        address[] memory collateralLiquidationPriority = new address[](filteredMarginCollateralsConfig.length);

        for (uint256 i; i < filteredMarginCollateralsConfig.length; i++) {
            uint256 indexLiquidationPriority = filteredMarginCollateralsConfig[i].liquidationPriority - 1;

            address marginCollateralAddress;
            address priceAdapter;
            address mockERC20;

            if (isTest) {
                if (filteredMarginCollateralsConfig[i].marginCollateralId == USD_TOKEN_MARGIN_COLLATERAL_ID) {
                    mockERC20 = address(
                        new MockUsdToken({
                            owner: owner,
                            deployerBalance: 100_000_000e18,
                            _name: "Zaros Perpetuals AMM USD",
                            _symbol: "USDz"
                        })
                    );
                } else {
                    mockERC20 = address(
                        new MockERC20({
                            name: filteredMarginCollateralsConfig[i].name,
                            symbol: filteredMarginCollateralsConfig[i].symbol,
                            decimals_: filteredMarginCollateralsConfig[i].tokenDecimals,
                            deployerBalance: filteredMarginCollateralsConfig[i].minDepositMargin
                        })
                    );
                }

                marginCollateralAddress = address(mockERC20);

                MockPriceFeed mockPriceFeed = new MockPriceFeed(
                    filteredMarginCollateralsConfig[i].tokenDecimals,
                    int256(filteredMarginCollateralsConfig[i].mockUsdPrice)
                );

                priceAdapter = address(
                    PriceAdapterUtils.deployPriceAdapter(
                        PriceAdapter.InitializeParams({
                            name: filteredMarginCollateralsConfig[i].name,
                            symbol: filteredMarginCollateralsConfig[i].symbol,
                            owner: address(0x123),
                            priceFeed: address(mockPriceFeed),
                            ethUsdPriceFeed: address(0),
                            sequencerUptimeFeed: sequencerUptimeFeed,
                            priceFeedHeartbeatSeconds: 86_400,
                            ethUsdPriceFeedHeartbeatSeconds: 0,
                            useEthPriceFeed: false
                        })
                    )
                );

                marginCollaterals[filteredMarginCollateralsConfig[i].marginCollateralId].marginCollateralAddress =
                    marginCollateralAddress;
                filteredMarginCollateralsConfig[i].marginCollateralAddress = marginCollateralAddress;

                marginCollaterals[filteredMarginCollateralsConfig[i].marginCollateralId].priceAdapter = priceAdapter;
                filteredMarginCollateralsConfig[i].priceAdapter = priceAdapter;
            }

            collateralLiquidationPriority[indexLiquidationPriority] =
                filteredMarginCollateralsConfig[i].marginCollateralAddress;

            perpsEngine.configureMarginCollateral(
                filteredMarginCollateralsConfig[i].marginCollateralAddress,
                filteredMarginCollateralsConfig[i].depositCap,
                filteredMarginCollateralsConfig[i].loanToValue,
                filteredMarginCollateralsConfig[i].priceAdapter
            );
        }

        perpsEngine.configureCollateralLiquidationPriority(collateralLiquidationPriority);
    }
}
