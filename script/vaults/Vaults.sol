// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { ZlpVault } from "@zaros/zlp/ZlpVault.sol";
import { MarginCollaterals } from "script/margin-collaterals/MarginCollaterals.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

// Vaults
import { UsdcCoreVault } from "./UsdcCoreVault.sol";
import { UsdcDegenVault } from "./UsdcDegenVault.sol";
import { UsdcBluechipVault } from "./UsdcBluechipVault.sol";

import { WBtcCoreVault } from "./WBtcCoreVault.sol";
import { WBtcDegenVault } from "./WBtcDegenVault.sol";
import { WBtcBluechipVault } from "./WBtcBluechipVault.sol";

import { WeEthCoreVault } from "./WeEthCoreVault.sol";
import { WeEthDegenVault } from "./WeEthDegenVault.sol";
import { WeEthBluechipVault } from "./WeEthBluechipVault.sol";

import { WEthCoreVault } from "./WEthCoreVault.sol";
import { WEthDegenVault } from "./WEthDegenVault.sol";
import { WEthBluechipVault } from "./WEthBluechipVault.sol";

import { WstEthCoreVault } from "./WstEthCoreVault.sol";
import { WstEthDegenVault } from "./WstEthDegenVault.sol";
import { WstEthBluechipVault } from "./WstEthBluechipVault.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

enum VaultTypes {
    Core, // 0
    Degen, // 1
    Bluechip // 2

}

abstract contract Vaults is
    StdCheats,
    StdUtils,
    WeEthCoreVault,
    WeEthDegenVault,
    WeEthBluechipVault,
    UsdcCoreVault,
    UsdcDegenVault,
    UsdcBluechipVault,
    WBtcCoreVault,
    WBtcDegenVault,
    WBtcBluechipVault,
    WEthCoreVault,
    WEthDegenVault,
    WEthBluechipVault,
    WstEthCoreVault,
    WstEthDegenVault,
    WstEthBluechipVault,
    MarginCollaterals
{
    struct VaultConfig {
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        address indexToken;
        address asset;
        uint256 creditRatio;
        uint256 depositFee;
        uint256 redeemFee;
        uint32 priceFeedHeartbeatSeconds;
        bool isEnabled;
        uint8 decimals;
        address priceAdapter;
        VaultTypes vaultType;
        string streamIdString;
        bytes32 streamId;
        address engine;
    }

    /// @notice Vault configurations mapped by vault id.
    mapping(uint256 vaultId => VaultConfig vaultConfig) internal vaultsConfig;

    mapping(address asset => mapping(VaultTypes vaultType => ZlpVault zlpVault)) internal zlpVaults;

    /// @notice Usd token swap keepers contracts mapped by asset.
    mapping(address asset => address keeper) internal usdTokenSwapKeepers;

    function createZlpVaults(address marketMakingEngine, address owner, uint256[2] memory vaultsIdsRange) public {
        uint256 initialVaultId = vaultsIdsRange[0];
        uint256 finalVaultlId = vaultsIdsRange[1];

        // iterate over vaultsConfig and set ZLP vaults
        for (uint256 i = initialVaultId; i <= finalVaultlId; i++) {
            address vaultAsset = vaultsConfig[i].asset;
            VaultTypes vaultType = vaultsConfig[i].vaultType;

            // deploy zlp vault as an upgradeable proxy
            address zlpVaultImpl = address(new ZlpVault());
            bytes memory zlpVaultInitData = abi.encodeWithSelector(
                ZlpVault.initialize.selector,
                marketMakingEngine,
                Constants.SYSTEM_DECIMALS - vaultsConfig[i].decimals,
                owner,
                IERC20(vaultAsset),
                vaultsConfig[i].vaultId
            );
            ZlpVault zlpVault = ZlpVault(address(new ERC1967Proxy(zlpVaultImpl, zlpVaultInitData)));

            zlpVaults[vaultAsset][vaultType] = zlpVault;
            vaultsConfig[i].indexToken = address(zlpVault);

            if (usdTokenSwapKeepers[vaultAsset] == address(0)) {
                deployUsdTokenSwapKeeper(owner, marketMakingEngine, vaultAsset, vaultsConfig[i].streamIdString);
            }
        }
    }

    function setupVaultsConfig() internal {
        // Not using the margin collateral address or price feed constants as it is reset in the marginCollaterals
        // mapping when MarginCollaterals::configureMarginCollaterals() is called
        address usdcAddress = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address usdcPriceAdapter = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory usdcCore = VaultConfig({
            vaultId: USDC_CORE_VAULT_ID,
            depositCap: USDC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: usdcAddress,
            creditRatio: USDC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_CORE_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: usdcPriceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: USDC_USD_STREAM_ID_STRING,
            streamId: USDC_USD_STREAM_ID,
            depositFee: USDC_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: USDC_CORE_VAULT_REDEEM_FEE,
            engine: USDC_CORE_VAULT_ENGINE
        });
        vaultsConfig[USDC_CORE_VAULT_ID] = usdcCore;

        VaultConfig memory usdcBluechip = VaultConfig({
            vaultId: USDC_BLUECHIP_VAULT_ID,
            depositCap: USDC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: usdcAddress,
            creditRatio: USDC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: usdcPriceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: USDC_USD_STREAM_ID_STRING,
            streamId: USDC_USD_STREAM_ID,
            depositFee: USDC_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: USDC_BLUECHIP_VAULT_REDEEM_FEE,
            engine: USDC_BLUECHIP_VAULT_ENGINE
        });
        vaultsConfig[USDC_BLUECHIP_VAULT_ID] = usdcBluechip;

        VaultConfig memory usdcDegen = VaultConfig({
            vaultId: USDC_DEGEN_VAULT_ID,
            depositCap: USDC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: usdcAddress,
            creditRatio: USDC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_DEGEN_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: usdcPriceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: USDC_USD_STREAM_ID_STRING,
            streamId: USDC_USD_STREAM_ID,
            depositFee: USDC_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: USDC_DEGEN_VAULT_REDEEM_FEE,
            engine: USDC_DEGEN_VAULT_ENGINE
        });
        vaultsConfig[USDC_DEGEN_VAULT_ID] = usdcDegen;

        address wBtcAddress = marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address wBtcPriceAdapter = marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory wBtcCore = VaultConfig({
            vaultId: WBTC_CORE_VAULT_ID,
            depositCap: WBTC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wBtcAddress,
            creditRatio: WBTC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_CORE_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: wBtcPriceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WBTC_USD_STREAM_ID_STRING,
            streamId: WBTC_USD_STREAM_ID,
            depositFee: WBTC_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WBTC_CORE_VAULT_REDEEM_FEE,
            engine: WBTC_CORE_VAULT_ENGINE
        });
        vaultsConfig[WBTC_CORE_VAULT_ID] = wBtcCore;

        VaultConfig memory wBtcBluechip = VaultConfig({
            vaultId: WBTC_BLUECHIP_VAULT_ID,
            depositCap: WBTC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wBtcAddress,
            creditRatio: WBTC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: wBtcPriceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WBTC_USD_STREAM_ID_STRING,
            streamId: WBTC_USD_STREAM_ID,
            depositFee: WBTC_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WBTC_BLUECHIP_VAULT_REDEEM_FEE,
            engine: WBTC_BLUECHIP_VAULT_ENGINE
        });
        vaultsConfig[WBTC_BLUECHIP_VAULT_ID] = wBtcBluechip;

        VaultConfig memory wBtcDegen = VaultConfig({
            vaultId: WBTC_DEGEN_VAULT_ID,
            depositCap: WBTC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wBtcAddress,
            creditRatio: WBTC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_DEGEN_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: wBtcPriceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WBTC_USD_STREAM_ID_STRING,
            streamId: WBTC_USD_STREAM_ID,
            depositFee: WBTC_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WBTC_DEGEN_VAULT_REDEEM_FEE,
            engine: WBTC_DEGEN_VAULT_ENGINE
        });
        vaultsConfig[WBTC_DEGEN_VAULT_ID] = wBtcDegen;

        address weEthAddress = marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address weEthPriceAdapter = marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory weEthCore = VaultConfig({
            vaultId: WEETH_CORE_VAULT_ID,
            depositCap: WEETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: weEthAddress,
            creditRatio: WEETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_CORE_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: weEthPriceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WEETH_USD_STREAM_ID_STRING,
            streamId: WEETH_USD_STREAM_ID,
            depositFee: WEETH_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WEETH_CORE_VAULT_REDEEM_FEE,
            engine: WEETH_CORE_VAULT_ENGINE
        });
        vaultsConfig[WEETH_CORE_VAULT_ID] = weEthCore;

        VaultConfig memory weEthBluechip = VaultConfig({
            vaultId: WEETH_BLUECHIP_VAULT_ID,
            depositCap: WEETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: weEthAddress,
            creditRatio: WEETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: weEthPriceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WEETH_USD_STREAM_ID_STRING,
            streamId: WEETH_USD_STREAM_ID,
            depositFee: WEETH_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WEETH_BLUECHIP_VAULT_REDEEM_FEE,
            engine: WEETH_BLUECHIP_VAULT_ENGINE
        });
        vaultsConfig[WEETH_BLUECHIP_VAULT_ID] = weEthBluechip;

        VaultConfig memory weEthDegen = VaultConfig({
            vaultId: WEETH_DEGEN_VAULT_ID,
            depositCap: WEETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: weEthAddress,
            creditRatio: WEETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: weEthPriceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WEETH_USD_STREAM_ID_STRING,
            streamId: WEETH_USD_STREAM_ID,
            depositFee: WEETH_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WEETH_DEGEN_VAULT_REDEEM_FEE,
            engine: WEETH_DEGEN_VAULT_ENGINE
        });
        vaultsConfig[WEETH_DEGEN_VAULT_ID] = weEthDegen;

        address wEthAddress = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address wEthPriceAdapter = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory wEthCore = VaultConfig({
            vaultId: WETH_CORE_VAULT_ID,
            depositCap: WETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wEthAddress,
            creditRatio: WETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_CORE_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: wEthPriceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WETH_USD_STREAM_ID_STRING,
            streamId: WETH_USD_STREAM_ID,
            depositFee: WETH_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WETH_CORE_VAULT_REDEEM_FEE,
            engine: WETH_CORE_VAULT_ENGINE
        });
        vaultsConfig[WETH_CORE_VAULT_ID] = wEthCore;

        VaultConfig memory wEthBluechip = VaultConfig({
            vaultId: WETH_BLUECHIP_VAULT_ID,
            depositCap: WETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wEthAddress,
            creditRatio: WETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: wEthPriceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WETH_USD_STREAM_ID_STRING,
            streamId: WETH_USD_STREAM_ID,
            depositFee: WETH_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WETH_BLUECHIP_VAULT_REDEEM_FEE,
            engine: WETH_BLUECHIP_VAULT_ENGINE
        });
        vaultsConfig[WETH_BLUECHIP_VAULT_ID] = wEthBluechip;

        VaultConfig memory wEthDegen = VaultConfig({
            vaultId: WETH_DEGEN_VAULT_ID,
            depositCap: WETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wEthAddress,
            creditRatio: WETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: wEthPriceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WETH_USD_STREAM_ID_STRING,
            streamId: WETH_USD_STREAM_ID,
            depositFee: WETH_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WETH_DEGEN_VAULT_REDEEM_FEE,
            engine: WETH_DEGEN_VAULT_ENGINE
        });
        vaultsConfig[WETH_DEGEN_VAULT_ID] = wEthDegen;

        address wStETHAddress = marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address wStEthPriceAdapter = marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory wStEthCore = VaultConfig({
            vaultId: WSTETH_CORE_VAULT_ID,
            depositCap: WSTETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wStETHAddress,
            creditRatio: WSTETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_CORE_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: wStEthPriceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WSTETH_USD_STREAM_ID_STRING,
            streamId: WSTETH_USD_STREAM_ID,
            depositFee: WSTETH_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WSTETH_CORE_VAULT_REDEEM_FEE,
            engine: WSTETH_CORE_VAULT_ENGINE
        });
        vaultsConfig[WSTETH_CORE_VAULT_ID] = wStEthCore;

        VaultConfig memory wStEthBluechip = VaultConfig({
            vaultId: WSTETH_BLUECHIP_VAULT_ID,
            depositCap: WSTETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wStETHAddress,
            creditRatio: WSTETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: wStEthPriceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WSTETH_USD_STREAM_ID_STRING,
            streamId: WSTETH_USD_STREAM_ID,
            depositFee: WSTETH_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WSTETH_BLUECHIP_VAULT_REDEEM_FEE,
            engine: WSTETH_BLUECHIP_VAULT_ENGINE
        });
        vaultsConfig[WSTETH_BLUECHIP_VAULT_ID] = wStEthBluechip;

        VaultConfig memory wStEthDegen = VaultConfig({
            vaultId: WSTETH_DEGEN_VAULT_ID,
            depositCap: WSTETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wStETHAddress,
            creditRatio: WSTETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: wStEthPriceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WSTETH_USD_STREAM_ID_STRING,
            streamId: WSTETH_USD_STREAM_ID,
            depositFee: WSTETH_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WSTETH_DEGEN_VAULT_REDEEM_FEE,
            engine: WSTETH_DEGEN_VAULT_ENGINE
        });
        vaultsConfig[WSTETH_DEGEN_VAULT_ID] = wStEthDegen;
    }

    function createVaults(
        IMarketMakingEngine marketMakingEngine,
        uint256 initialVaultId,
        uint256 finalVaultId,
        bool isTest,
        address testEngine
    )
        public
    {
        for (uint256 i = initialVaultId; i <= finalVaultId; i++) {
            if (isTest) {
                vaultsConfig[i].engine = testEngine;
            }

            marketMakingEngine.configureCollateral(
                vaultsConfig[i].asset,
                vaultsConfig[i].priceAdapter,
                vaultsConfig[i].creditRatio,
                vaultsConfig[i].isEnabled,
                vaultsConfig[i].decimals
            );

            Collateral.Data memory collateral = marketMakingEngine.getCollateralData(vaultsConfig[i].asset);

            marketMakingEngine.createVault(
                Vault.CreateParams({
                    vaultId: vaultsConfig[i].vaultId,
                    depositCap: vaultsConfig[i].depositCap,
                    withdrawalDelay: vaultsConfig[i].withdrawalDelay,
                    indexToken: vaultsConfig[i].indexToken, // ZLP Vault shares
                    collateral: collateral,
                    depositFee: vaultsConfig[i].depositFee,
                    redeemFee: vaultsConfig[i].redeemFee,
                    engine: vaultsConfig[i].engine
                })
            );
        }
    }

    function getFilteredVaultsConfig(uint256[2] memory vaultsIdsRange) internal view returns (VaultConfig[] memory) {
        uint256 initialMarketId = vaultsIdsRange[0];
        uint256 finalMarketId = vaultsIdsRange[1];
        uint256 filteredVaultsLength = finalMarketId - initialMarketId + 1;

        VaultConfig[] memory filteredVaultsConfig = new VaultConfig[](filteredVaultsLength);

        uint256 nextMarketId = initialMarketId;
        for (uint256 i; i < filteredVaultsLength; i++) {
            filteredVaultsConfig[i] = vaultsConfig[nextMarketId];
            nextMarketId++;
        }

        return filteredVaultsConfig;
    }

    function deployUsdTokenSwapKeeper(
        address deployer,
        address marketMakingEngine,
        address asset,
        string memory streamIdString
    )
        internal
        returns (address usdTokenSwapKeeper)
    {
        address usdTokenSwapKeeperImplementation = address(new UsdTokenSwapKeeper());

        usdTokenSwapKeeper = address(
            new ERC1967Proxy(
                usdTokenSwapKeeperImplementation,
                abi.encodeWithSelector(
                    UsdTokenSwapKeeper.initialize.selector,
                    deployer,
                    IMarketMakingEngine(marketMakingEngine),
                    asset,
                    streamIdString
                )
            )
        );

        usdTokenSwapKeepers[asset] = usdTokenSwapKeeper;

        changePrank({ msgSender: deployer });
        IMarketMakingEngine(marketMakingEngine).configureSystemKeeper(usdTokenSwapKeeper, true);
    }
}
