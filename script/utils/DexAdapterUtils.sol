// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { UniswapV3Adapter } from "@zaros/utils/dex-adapters/UniswapV3Adapter.sol";
import { SwapAssetConfigData } from "@zaros/utils/dex-adapters/BaseAdapter.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { UniswapV2Adapter } from "@zaros/utils/dex-adapters/UniswapV2Adapter.sol";
import { CurveAdapter } from "@zaros/utils/dex-adapters/CurveAdapter.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

/// @notice Dex Adapter Utils
contract DexAdapterUtils {
    // adapter ID => adapter address
    mapping(uint256 id => IDexAdapter adapter) adapters;

    // Dex adapter ids array
    uint256[] dexAdapterIds;

    /// @notice Deploys the Uniswap V3 Adapter
    /// @param marketMakingEngine The Market Making Engine
    /// @param owner The owner of the Uniswap V3 Adapter
    /// @param uniswapV3SwapStrategyRouter The Uniswap V3 Swap Strategy Router
    /// @param slippageToleranceBps The slippage tolerance
    /// @param fee The Uniswap V3 pool fee
    /// @param assets The assets to set in the Uniswap V3 Adapter
    /// @param swapAssetConfigData The asset data to set in the Uniswap V3 Adapter
    function deployUniswapV3Adapter(
        IMarketMakingEngine marketMakingEngine,
        address owner,
        address uniswapV3SwapStrategyRouter,
        uint256 slippageToleranceBps,
        uint24 fee,
        address[] memory assets,
        SwapAssetConfigData[] memory swapAssetConfigData
    )
        public
        returns (UniswapV3Adapter uniswapV3Adapter)
    {
        // revert if the length of assets and swapAssetConfigData is different
        if (assets.length != swapAssetConfigData.length) {
            revert Errors.ArrayLengthMismatch(assets.length, swapAssetConfigData.length);
        }

        // instantiate the Uniswap V3 Adapter Implementation
        UniswapV3Adapter uniswapV3AdapterImplementation = new UniswapV3Adapter();

        // create bytes of the initialize function of Uniswap V3 Adapter Implementation
        bytes memory initializeUniswapV3Adapter = abi.encodeWithSelector(
            uniswapV3AdapterImplementation.initialize.selector,
            owner,
            uniswapV3SwapStrategyRouter,
            slippageToleranceBps,
            fee
        );

        // deploy the Uniswap V3 Adapter Proxy
        uniswapV3Adapter = UniswapV3Adapter(
            address(new ERC1967Proxy(address(uniswapV3AdapterImplementation), initializeUniswapV3Adapter))
        );

        console.log("UniswapV3Adapter deployed at: %s", address(uniswapV3Adapter));

        for (uint256 i; i < assets.length; i++) {
            // set the swap asset config data in the Uniswap V3 Adapter Proxy
            uniswapV3Adapter.setSwapAssetConfig(
                assets[i], swapAssetConfigData[i].decimals, swapAssetConfigData[i].priceAdapter
            );

            console.log(
                "Asset swap config data set in UniswapV3Adapter: asset: %s, decimals: %s, priceAdapter: %s",
                assets[i],
                swapAssetConfigData[i].decimals,
                swapAssetConfigData[i].priceAdapter
            );
        }

        // configure the Dex Swap Strategy in the Market Making Engine
        marketMakingEngine.configureDexSwapStrategy(uniswapV3Adapter.STRATEGY_ID(), address(uniswapV3Adapter));

        adapters[uniswapV3Adapter.STRATEGY_ID()] = IDexAdapter(uniswapV3Adapter);
        dexAdapterIds.push(uniswapV3Adapter.STRATEGY_ID());

        console.log(
            "Uniswap V3 Swap Strategy configured in MarketMakingEngine: strategyId: %s, strategyAddress: %s",
            uniswapV3Adapter.STRATEGY_ID(),
            address(uniswapV3Adapter)
        );
    }

    /// @notice Deploys the Uniswap V2 Adapter
    /// @param marketMakingEngine The Market Making Engine
    /// @param owner The owner of the Uniswap V2 Adapter
    /// @param uniswapV2SwapStrategyRouter The Uniswap V2 Swap Strategy Router
    /// @param slippageToleranceBps The slippage tolerance
    /// @param assets The assets to set in the Uniswap V2 Adapter
    /// @param swapAssetConfigData The asset data to set in the Uniswap V2 Adapter
    function deployUniswapV2Adapter(
        IMarketMakingEngine marketMakingEngine,
        address owner,
        address uniswapV2SwapStrategyRouter,
        uint256 slippageToleranceBps,
        address[] memory assets,
        SwapAssetConfigData[] memory swapAssetConfigData
    )
        public
        returns (UniswapV2Adapter uniswapV2Adapter)
    {
        // revert if the length of assets and swapAssetConfigData is different
        if (assets.length != swapAssetConfigData.length) {
            revert Errors.ArrayLengthMismatch(assets.length, swapAssetConfigData.length);
        }

        // instantiate the Uniswap V2 Adapter Implementation
        UniswapV2Adapter uniswapV2AdapterImplementation = new UniswapV2Adapter();

        // create bytes of the initialize function of Uniswap V2 Adapter Implementation
        bytes memory initializeUniswapV2Adapter = abi.encodeWithSelector(
            uniswapV2AdapterImplementation.initialize.selector,
            owner,
            uniswapV2SwapStrategyRouter,
            slippageToleranceBps
        );

        // deploy the Uniswap V2 Adapter Proxy
        uniswapV2Adapter = UniswapV2Adapter(
            address(new ERC1967Proxy(address(uniswapV2AdapterImplementation), initializeUniswapV2Adapter))
        );

        console.log("UniswapV2Adapter deployed at: %s", address(uniswapV2Adapter));

        for (uint256 i; i < assets.length; i++) {
            // set the swap asset config data in the Uniswap V3 Adapter Proxy
            uniswapV2Adapter.setSwapAssetConfig(
                assets[i], swapAssetConfigData[i].decimals, swapAssetConfigData[i].priceAdapter
            );

            console.log(
                "Asset swap config data set in UniswapV2Adapter: asset: %s, decimals: %s, priceAdapter: %s",
                assets[i],
                swapAssetConfigData[i].decimals,
                swapAssetConfigData[i].priceAdapter
            );
        }

        // configure the Dex Swap Strategy in the Market Making Engine
        marketMakingEngine.configureDexSwapStrategy(uniswapV2Adapter.STRATEGY_ID(), address(uniswapV2Adapter));

        adapters[uniswapV2Adapter.STRATEGY_ID()] = IDexAdapter(uniswapV2Adapter);
        dexAdapterIds.push(uniswapV2Adapter.STRATEGY_ID());

        console.log(
            "Uniswap V3 Swap Strategy configured in MarketMakingEngine: strategyId: %s, strategyAddress: %s",
            uniswapV2Adapter.STRATEGY_ID(),
            address(uniswapV2Adapter)
        );
    }

    /// @notice Deploys the Curve Adapter
    /// @param marketMakingEngine The Market Making Engine
    /// @param owner The owner of the Curve Adapter
    /// @param curveStrategyRouter The Curve Strategy Router
    /// @param slippageToleranceBps The slippage tolerance
    /// @param assets The assets to set in the Curve Adapter
    /// @param swapAssetConfigData The asset data to set in the Curve Adapter
    function deployCurveAdapter(
        IMarketMakingEngine marketMakingEngine,
        address owner,
        address curveStrategyRouter,
        uint256 slippageToleranceBps,
        address[] memory assets,
        SwapAssetConfigData[] memory swapAssetConfigData
    )
        public
        returns (CurveAdapter curveAdapter)
    {
        // revert if the length of assets and swapAssetConfigData is different
        if (assets.length != swapAssetConfigData.length) {
            revert Errors.ArrayLengthMismatch(assets.length, swapAssetConfigData.length);
        }

        // instantiate the Uniswap V2 Adapter Implementation
        CurveAdapter curveAdapterImplementation = new CurveAdapter();

        // create bytes of the initialize function of Uniswap V2 Adapter Implementation
        bytes memory initializeCurveAdapter = abi.encodeWithSelector(
            curveAdapterImplementation.initialize.selector, owner, curveStrategyRouter, slippageToleranceBps
        );

        // deploy the Uniswap V2 Adapter Proxy
        curveAdapter =
            CurveAdapter(address(new ERC1967Proxy(address(curveAdapterImplementation), initializeCurveAdapter)));

        console.log("curveStrategyRouter deployed at: %s", address(curveStrategyRouter));

        for (uint256 i; i < assets.length; i++) {
            // set the swap asset config data in the Curve Adapter Proxy
            curveAdapter.setSwapAssetConfig(
                assets[i], swapAssetConfigData[i].decimals, swapAssetConfigData[i].priceAdapter
            );

            console.log(
                "Asset swap config data set in CurveAdapter: asset: %s, decimals: %s, priceAdapter: %s",
                assets[i],
                swapAssetConfigData[i].decimals,
                swapAssetConfigData[i].priceAdapter
            );
        }

        // configure the Dex Swap Strategy in the Market Making Engine
        marketMakingEngine.configureDexSwapStrategy(curveAdapter.STRATEGY_ID(), address(curveAdapter));

        adapters[curveAdapter.STRATEGY_ID()] = IDexAdapter(curveAdapter);
        dexAdapterIds.push(curveAdapter.STRATEGY_ID());

        console.log(
            "Curve Swap Strategy configured in MarketMakingEngine: strategyId: %s, strategyAddress: %s",
            curveAdapter.STRATEGY_ID(),
            address(curveStrategyRouter)
        );
    }
}
