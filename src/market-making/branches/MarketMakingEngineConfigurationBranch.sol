// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { StabilityConfiguration } from "@zaros/market-making/leaves/StabilityConfiguration.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { ZlpVault } from "@zaros/zlp/ZlpVault.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";
import { LiveMarkets } from "@zaros/market-making/leaves/LiveMarkets.sol";
import { AssetSwapPath } from "@zaros/market-making/leaves/AssetSwapPath.sol";

// Open Zeppelin Upgradeable dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// TODO: add initializer at upgrade branch or auth branch
contract MarketMakingEngineConfigurationBranch is OwnableUpgradeable {
    using DexSwapStrategy for DexSwapStrategy.Data;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeCast for uint256;
    using DexSwapStrategy for DexSwapStrategy.Data;
    using LiveMarkets for LiveMarkets.Data;
    using AssetSwapPath for AssetSwapPath.Data;

    constructor() {
        _disableInitializers();
    }

    /// @notice Emitted when an engine is registered.
    /// @param engine The address of the engine contract.
    event LogRegisterEngine(address engine);

    /// @notice Emitted when a new vault is created.
    /// @param sender The address that created the vault.
    /// @param vaultId The vault id.
    event LogCreateVault(address indexed sender, uint128 vaultId);

    /// @notice Emitted when a vault is updated.
    /// @param sender The address that updated the vault.
    /// @param vaultId The vault id.
    event LogUpdateVaultConfiguration(address indexed sender, uint128 vaultId);

    /// @notice Emitted when a system keeper is configured.
    /// @param systemKeeper The address of the system keeper.
    /// @param shouldBeEnabled A flag indicating whether the system keeper should be enabled.
    event LogConfigureSystemKeeper(address systemKeeper, bool shouldBeEnabled);

    /// @notice Emitted when an engine's configuration is updated.
    /// @param engine The address of the engine contract.
    /// @param usdToken The address of the USD token contract.
    /// @param shouldBeEnabled A flag indicating whether the engine should be enabled or disabled.
    event LogConfigureEngine(address engine, address usdToken, bool shouldBeEnabled);

    /// @notice Emitted when collateral is configured.
    /// @param collateral The address of the collateral.
    /// @param priceAdapter The address of the price adapter.
    /// @param creditRatio The credit ratio.
    /// @param isEnabled The status of the collateral.
    /// @param decimals The decimals of the collateral.
    event LogConfigureCollateral(
        address indexed collateral, address priceAdapter, uint256 creditRatio, bool isEnabled, uint8 decimals
    );

    /// @notice Emitted when market is configured.
    /// @param engine The address of the perps engine.
    /// @param marketId The perps engine's market id.
    /// @param autoDeleverageStartThreshold The auto deleverage start threshold.
    /// @param autoDeleverageEndThreshold The auto deleverage end threshold.
    /// @param autoDeleverageExpoentZ The auto deleverage power scale.
    event LogConfigureMarket(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleverageExpoentZ
    );

    /// @notice Emitted when a dex swap strategy is configured.
    /// @param dexSwapStrategyId The dex swap strategy id.
    /// @param dexAdapter The address of the dex adapter.
    event LogConfigureDexSwapStrategy(uint128 dexSwapStrategyId, address dexAdapter);

    /// @notice Emitted when the wETH address is set or updated.
    /// @param weth The address of the wETH token.
    event LogSetWeth(address weth);

    /// @notice Emitted when the USDC address is set or updated.
    /// @param usdc The address of the USDC token.
    event LogSetUsdc(address usdc);

    /// @notice Emitted when the settlementBaseFeeUsdX18 is set or updated.
    /// @param settlementBaseFeeUsdX18 The amount of the USDC token fee.
    event LogSetSettlementBaseFeeUsdX18(uint128 settlementBaseFeeUsdX18);

    /// @notice Emitted when a fee recipient is configured.
    /// @param feeRecipient The address of the fee recipient.
    /// @param share The share of the fee recipient, example 0.5e18 (50%).
    event LogConfigureFeeRecipient(address feeRecipient, uint256 share);

    /// @notice Emitted when connected markets are configured on a vault.
    /// @param vaultId The vault id.
    /// @param marketsIds The markets ids.
    event LogConfigureVaultConnectedMarkets(uint128 vaultId, uint256[] marketsIds);

    /// @notice Emitted when connected vaults are configured on a market.
    /// @param marketId The market id.
    /// @param vaultIds The vaults ids.
    event LogConfigureMarketConnectedVaults(uint128 marketId, uint256[] vaultIds);

    /// @notice Emitted whe the referral module is configured.
    /// @param sender The address that configured the referral module.
    /// @param referralModule The address of the referral module.
    event LogConfigureReferralModule(address sender, address referralModule);

    /// @notice Emitted when the dex swap path for an asset is configured.
    /// @param asset the asset for which to update the swap path
    /// @param assets The assets in the swap path
    /// @param dexSwapStrategyIds The strategy ids to use for each consecutive pair of assets
    /// @param enabled Bool indicating whether the swap path is enabled
    event LogConfiguredSwapPath(address asset, address[] assets, uint128[] dexSwapStrategyIds, bool enabled);

    /// @notice Emitted when the deposit fee is configured.
    /// @param vaultId The vault id.
    /// @param depositFee The deposit fee.
    event LogConfigureDepositFee(uint128 vaultId, uint256 depositFee);

    /// @notice Emitted when the redeem fee is configured.
    /// @param vaultId The vault id.
    /// @param redeemFee The redeem fee.
    event LogConfigureRedeemFee(uint128 vaultId, uint256 redeemFee);

    /// @notice Emitted when the vault deposit and redeem fee recipient is configured.
    /// @param vaultDepositAndRedeemFeeRecipient The vault deposit and redeem fee recipient address.
    event LogConfigureVaultDepositAndRedeemFeeRecipient(address vaultDepositAndRedeemFeeRecipient);

    /// @notice Emitted when a market is paused.
    /// @param marketId The market being paused.
    event LogMarketPaused(uint128 marketId);

    /// @notice Emitted when a market is unpaused.
    /// @param marketId The market being unpaused.
    event LogMarketUnpaused(uint128 marketId);

    /// @notice Emitted when stability config is updated
    /// @param chainlinkVerifier The new chainlink verifier address.
    /// @param maxVerificationDelay The new maximum verification delay.
    event LogUpdateStabilityConfig(address chainlinkVerifier, uint128 maxVerificationDelay);

    /// @notice Emitted when a vault's asset allowance is updated
    /// @param vaultId The new vault id being updated.
    /// @param allowance The new asset allowance for the vault.
    event LogUpdateVaultAssetAllowance(uint128 vaultId, uint256 allowance);

    /// @notice Emitted when the vault engine address is updated
    /// @param vaultId The vault id
    /// @param engine The engine address
    event LogSetVaultEngine(uint128 vaultId, address engine);

    /// @notice Emitted when the whitelist configured.
    /// @param whitelist The address of the whitelist.
    /// @param isWhitelistMode The boolean that indicates to use whitelist.
    event LogConfigureWhitelist(address whitelist, bool isWhitelistMode);

    /// @notice Returns the address of custom referral code
    /// @param customReferralCode The custom referral code.
    /// @return referrer The address of the referrer.
    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) { }

    /// @dev Invariants involved in the call:
    function configureSystemParameters() external onlyOwner { }

    /// @notice Creates a custom referral code.
    /// @param referrer The address of the referrer.
    /// @param customReferralCode The custom referral code.
    function createCustomReferralCode(address referrer, string calldata customReferralCode) external onlyOwner {
        // load the market making engine configuration from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // load the referral module
        IReferral referralModule = IReferral(marketMakingEngineConfiguration.referralModule);

        // create the custom referral code
        referralModule.createCustomReferralCode(referrer, customReferralCode);
    }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to create a vault with id set to 0
    function createVault(Vault.CreateParams calldata params) external onlyOwner {
        if (params.indexToken == address(0)) {
            revert Errors.ZeroInput("indexToken");
        }

        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        if (params.engine == address(0)) {
            revert Errors.ZeroInput("engine");
        }

        Vault.create(params);

        emit LogCreateVault(msg.sender, params.vaultId);
    }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to update vault with id set to 0
    function updateVaultConfiguration(Vault.UpdateParams calldata params) external onlyOwner {
        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        Vault.update(params);

        emit LogUpdateVaultConfiguration(msg.sender, params.vaultId);
    }

    /// @notice Configure connected vaults on market
    /// @dev Only owner can call this function
    /// @param marketIds The market ids.
    /// @param vaultIds The vault ids.
    function connectVaultsAndMarkets(uint256[] calldata marketIds, uint256[] calldata vaultIds) external onlyOwner {
        // revert if no marketIds are provided
        if (marketIds.length == 0) {
            revert Errors.ZeroInput("connectedMarketIds");
        }

        // revert if no vaultIds are provided
        if (vaultIds.length == 0) {
            revert Errors.ZeroInput("connectedVaultIds");
        }

        // define array that will contain a single vault id to recalculate credit for
        uint256[] memory vaultIdToRecalculate = new uint256[](1);

        // iterate over vault ids
        for (uint128 i; i < vaultIds.length; i++) {
            // if vault has connected markets
            if (Vault.load(vaultIds[i].toUint128()).connectedMarkets.length > 0) {
                // cache vault id
                vaultIdToRecalculate[0] = vaultIds[i];

                // recalculate the credit capacity of the vault
                Vault.recalculateVaultsCreditCapacity(vaultIdToRecalculate);
            }
        }

        for (uint256 i; i < marketIds.length; i++) {
            _configureMarketConnectedVaults(marketIds[i].toUint128(), vaultIds);
        }

        // perform state updates for markets connected to each market id
        for (uint256 i; i < vaultIds.length; i++) {
            _configureVaultConnectedMarkets(vaultIds[i].toUint128(), marketIds);
        }
    }

    /// @notice Configure connected vaults on market
    /// @dev Only owner can call this function
    /// @param marketId The market id.
    /// @param vaultIds The vault ids.
    function _configureMarketConnectedVaults(uint128 marketId, uint256[] calldata vaultIds) internal {
        // revert if vaultId is set to zero
        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }

        // load vault data from storage
        Market.Data storage market = Market.load(marketId);

        // if market has connected vaults
        if (market.connectedVaults.length > 0) {
            // Make sure that vaults connected to markets that are updated but not passed as an argument
            uint256[] memory vaultIdToRecalculate = market.connectedVaults[market.connectedVaults.length - 1].values();

            // recalculate the credit capacity for current market vaults
            Vault.recalculateVaultsCreditCapacity(vaultIdToRecalculate);
        }

        // push new array of connected markets
        market.connectedVaults.push();

        // add markets ids to connected markets
        for (uint256 i; i < vaultIds.length; i++) {
            // use [vault.connectedVaults.length - 1] to get the last connected markets array
            market.connectedVaults[market.connectedVaults.length - 1].add(vaultIds[i]);
        }

        // emit event LogConfigureMarketConnectedVaults
        emit LogConfigureMarketConnectedVaults(marketId, vaultIds);
    }

    /// @notice Configure connected markets on vault
    /// @dev Only owner can call this function
    /// @param vaultId The vault id.
    /// @param marketsIds The markets ids.
    function _configureVaultConnectedMarkets(uint128 vaultId, uint256[] calldata marketsIds) internal {
        // revert if vaultId is set to zero
        if (vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        // load vault data from storage
        Vault.Data storage vault = Vault.load(vaultId);

        // push new array of connected markets
        vault.connectedMarkets.push();

        // use [vault.connectedMarkets.length - 1] to get the last connected markets array
        uint256 connectedMarketsConfigIndex = vault.connectedMarkets.length - 1;

        // add markets ids to connected markets
        for (uint256 i; i < marketsIds.length; i++) {
            vault.connectedMarkets[connectedMarketsConfigIndex].add(marketsIds[i]);
        }

        // emit event LogConfigureVaultConnectedMarkets
        emit LogConfigureVaultConnectedMarkets(vaultId, marketsIds);
    }

    /// @notice Updates the swap strategy for a specific vault.
    /// @param vaultId The unique identifier of the vault.
    /// @param assetDexSwapPath The encoded path for the asset swap on the DEX.
    /// @param usdcDexSwapPath The encoded path for the USDC swap on the DEX.
    /// @param assetDexSwapStrategyId The identifier for the asset DEX swap strategy.
    /// @param usdcDexSwapStrategyId The identifier for the USDC DEX swap strategy.
    function updateVaultSwapStrategy(
        uint128 vaultId,
        bytes memory assetDexSwapPath,
        bytes memory usdcDexSwapPath,
        uint128 assetDexSwapStrategyId,
        uint128 usdcDexSwapStrategyId
    )
        external
        onlyOwner
    {
        Vault.updateVaultSwapStrategy(
            vaultId, assetDexSwapPath, usdcDexSwapPath, assetDexSwapStrategyId, usdcDexSwapStrategyId
        );
    }

    /// @notice Configure system keeper on Market Making Engine
    /// @dev Only owner can call this function
    /// @param systemKeeper The address of the system keeper.
    /// @param shouldBeEnabled The status of the system keeper.
    function configureSystemKeeper(address systemKeeper, bool shouldBeEnabled) external onlyOwner {
        // revert if systemKeeper is set to zero
        if (systemKeeper == address(0)) revert Errors.ZeroInput("systemKeeper");

        // loads the mm engine config storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // update system keeper status
        marketMakingEngineConfiguration.isSystemKeeperEnabled[systemKeeper] = shouldBeEnabled;

        // emit event LogConfigureSystemKeeper
        emit LogConfigureSystemKeeper(systemKeeper, shouldBeEnabled);
    }

    /// @notice Configures an engine contract and sets its linked USD token address.
    /// @dev This function can be used to enable or disable an active engine contract.
    /// @param engine The address of the engine contract.
    /// @param usdToken The address of the USD token contract.
    /// @param shouldBeEnabled A flag indicating whether the engine should be enabled.
    function configureEngine(address engine, address usdToken, bool shouldBeEnabled) external onlyOwner {
        if (engine == address(0)) revert Errors.ZeroInput("engine");

        // loads the mm engine config storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // if the engine needs to be disabled, set the isRegisteredEngine flag to false
        if (!shouldBeEnabled) {
            marketMakingEngineConfiguration.isRegisteredEngine[engine] = false;
            // sets the engine's usd token address to zero
            marketMakingEngineConfiguration.usdTokenOfEngine[engine] = address(0);

            emit LogConfigureEngine(engine, address(0), shouldBeEnabled);

            return;
        }

        // if the engine should be registered or the usd token updated, it mustn't be the zero address
        if (usdToken == address(0)) revert Errors.ZeroInput("usdToken");

        // registers the given engine if not already registered
        if (!marketMakingEngineConfiguration.isRegisteredEngine[engine]) {
            marketMakingEngineConfiguration.isRegisteredEngine[engine] = true;
        }

        // sets the USD token address of the given engine
        marketMakingEngineConfiguration.usdTokenOfEngine[engine] = usdToken;

        emit LogConfigureEngine(engine, usdToken, shouldBeEnabled);
    }

    /// @notice Set the wETH address
    /// @dev Only owner can call this function
    /// @param weth The address of the wETH token.
    function setWeth(address weth) external onlyOwner {
        // revert if weth is set to zero
        if (weth == address(0)) revert Errors.ZeroInput("wEth");

        // update weth address
        MarketMakingEngineConfiguration.load().weth = weth;

        // emit event LogSetWeth
        emit LogSetWeth(weth);
    }

    /// @notice Set the USDC address
    /// @dev Only owner can call this function
    /// @param usdc The address of the wETH token.
    function setUsdc(address usdc) external onlyOwner {
        // revert if usdc is set to zero
        if (usdc == address(0)) revert Errors.ZeroInput("usdc");

        // update usdc address
        MarketMakingEngineConfiguration.load().usdc = usdc;

        // emit event LogSetUsdc
        emit LogSetUsdc(usdc);
    }

    /// @notice Set the settlementBaseFeeUsdX18 amount
    /// @dev Only owner can call this function
    /// @param settlementBaseFeeUsdX18 The fee amount in usdc in 18 dex
    function setSettlementBaseFeeUsdX18(uint128 settlementBaseFeeUsdX18) external onlyOwner {
        // update fee
        MarketMakingEngineConfiguration.load().settlementBaseFeeUsdX18 = settlementBaseFeeUsdX18;

        // emit event LogSetSettlementBaseFeeUsdX18
        emit LogSetSettlementBaseFeeUsdX18(settlementBaseFeeUsdX18);
    }

    /// @notice Configure collateral on Market Making Engine
    /// @dev Only owner can call this functions
    /// @param collateral The address of the collateral.
    /// @param priceAdapter The address of the price adapter.
    /// @param creditRatio The credit ratio.
    /// @param isEnabled The status of the collateral.
    /// @param decimals The decimals of the collateral.
    function configureCollateral(
        address collateral,
        address priceAdapter,
        uint256 creditRatio,
        bool isEnabled,
        uint8 decimals
    )
        external
        onlyOwner
    {
        // revert if collateral is set to zero
        if (collateral == address(0)) revert Errors.ZeroInput("collateral");

        // revert if price adapter is set to zero
        if (priceAdapter == address(0)) revert Errors.ZeroInput("priceAdapter");

        // revert id credit ratio is set to zero
        if (creditRatio == 0) revert Errors.ZeroInput("creditRatio");

        // revert if decimals is set to zero or greater than system decimals per
        // invariant described in Math::convertTokenAmountToUd60x18 dev note
        if (decimals == 0) revert Errors.ZeroInput("decimals");
        if (decimals > Constants.SYSTEM_DECIMALS) {
            revert Errors.InvalidMarginCollateralConfiguration(collateral, decimals, address(0));
        }

        // load collateral data from storage
        Collateral.Data storage collateralData = Collateral.load(collateral);

        // update collateral data
        collateralData.asset = collateral;
        collateralData.priceAdapter = priceAdapter;
        collateralData.creditRatio = creditRatio;
        collateralData.isEnabled = isEnabled;
        collateralData.decimals = decimals;

        // emit event LogConfigureCollateral
        emit LogConfigureCollateral(collateral, priceAdapter, creditRatio, isEnabled, decimals);
    }

    /// @notice Configure market on Market Making Engine
    /// @dev Only owner can call this functions
    /// @param engine The address of the engine.
    /// @param marketId The market id.
    /// @param autoDeleverageStartThreshold The auto deleverage start threshold.
    /// @param autoDeleverageEndThreshold The auto deleverage end threshold.
    /// @param autoDeleverageExponentZ The auto deleverage power scale.
    function configureMarket(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleverageExponentZ
    )
        external
        onlyOwner
    {
        // revert if engine is set to zero
        if (engine == address(0)) revert Errors.ZeroInput("engine");

        // revert if marketId is set to zero
        if (marketId == 0) revert Errors.ZeroInput("marketId");

        // revert if autoDeleverageStartThreshold is set to zero
        if (autoDeleverageStartThreshold == 0) revert Errors.ZeroInput("autoDeleverageStartThreshold");

        // revert if autoDeleverageEndThreshold is set to zero
        if (autoDeleverageEndThreshold == 0) revert Errors.ZeroInput("autoDeleverageEndThreshold");

        // revert if autoDeleverageExpoentZ is set to zero
        if (autoDeleverageExponentZ == 0) revert Errors.ZeroInput("autoDeleverageExponentZ");

        // load market data from storage
        Market.Data storage market = Market.load(marketId);

        // update market data
        market.engine = engine;
        market.id = marketId;
        market.autoDeleverageStartThreshold = autoDeleverageStartThreshold;
        market.autoDeleverageEndThreshold = autoDeleverageEndThreshold;
        market.autoDeleverageExponentZ = autoDeleverageExponentZ;

        // emit event LogConfigureMarket
        emit LogConfigureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );
    }

    /// @notice Unpauses a specific market by adding its ID from the list of live markets.
    /// @param marketId The ID of the market to be unpaused.
    /// @return success A boolean indicating whether the operation was successful.
    function unpauseMarket(uint128 marketId) external onlyOwner returns (bool success) {
        success = LiveMarkets.load().addMarket(marketId);
        if (success) emit LogMarketUnpaused(marketId);
    }

    /// @notice Pauses a specific market by removing its ID from the list of live markets.
    /// @param marketId The ID of the market to be paused.
    /// @return success A boolean indicating whether the operation was successful.
    function pauseMarket(uint128 marketId) external onlyOwner returns (bool success) {
        success = LiveMarkets.load().removeMarket(marketId);
        if (success) emit LogMarketPaused(marketId);
    }

    /// @notice Configure dex swap strategy on Market Making Engine
    /// @dev Only owner can call this function
    /// @param dexSwapStrategyId The dex swap strategy id.
    /// @param dexAdapter The address of the dex adapter.
    function configureDexSwapStrategy(uint128 dexSwapStrategyId, address dexAdapter) external onlyOwner {
        // revert if dexSwapStrategyId is set to zero
        if (dexSwapStrategyId == 0) revert Errors.ZeroInput("dexSwapStrategyId");

        // revert if dexAdapter is set to zero
        if (dexAdapter == address(0)) revert Errors.ZeroInput("dexAdapter");

        // load dex swap strategy data from storage
        DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.load(dexSwapStrategyId);

        // update dex swap strategy data
        dexSwapStrategy.id = dexSwapStrategyId;
        dexSwapStrategy.dexAdapter = dexAdapter;

        // emit event LogConfigureDexSwapStrategy
        emit LogConfigureDexSwapStrategy(dexSwapStrategyId, dexAdapter);
    }

    /// @notice Configure fee recipient on Market Making Engine
    /// @dev Only owner can call this function
    /// @dev The share is in 1e18 precision, example: 0.5e18 (50%), the sum of all shares must not exceed 1e18 (100%),
    /// if pass it will revert.
    /// @dev The protocol must never be configured with 100% of fees being sent to protocol fee recipients, otherwise
    /// it's expected to produce weird behaviors.
    /// @param feeRecipient The address of the fee recipient.
    /// @param share The share of the fee recipient, example: 0.5e18 (50%).
    function configureFeeRecipient(address feeRecipient, uint256 share) external onlyOwner {
        // revert if protocolFeeRecipient is set to zero
        if (feeRecipient == address(0)) revert Errors.ZeroInput("feeRecipient");

        // load market making engine configuration data from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // check if share is greater than zero to verify the total will not exceed the maximum shares
        if (share > 0) {
            UD60x18 totalFeeRecipientsSharesX18 = ud60x18(marketMakingEngineConfiguration.totalFeeRecipientsShares);

            if (
                totalFeeRecipientsSharesX18.add(ud60x18(share)).gt(
                    ud60x18(Constants.MAX_CONFIGURABLE_PROTOCOL_FEE_SHARES)
                )
            ) {
                revert Errors.FeeRecipientShareExceedsLimit();
            }
        }

        (, uint256 oldFeeRecipientShares) = marketMakingEngineConfiguration.protocolFeeRecipients.tryGet(feeRecipient);

        // update protocol total fee recipients shares value
        if (oldFeeRecipientShares > 0) {
            if (oldFeeRecipientShares > share) {
                marketMakingEngineConfiguration.totalFeeRecipientsShares -=
                    (oldFeeRecipientShares - share).toUint128();
            } else {
                marketMakingEngineConfiguration.totalFeeRecipientsShares +=
                    (share - oldFeeRecipientShares).toUint128();
            }
        } else {
            marketMakingEngineConfiguration.totalFeeRecipientsShares += share.toUint128();
        }

        // update protocol fee recipient
        marketMakingEngineConfiguration.protocolFeeRecipients.set(feeRecipient, share);

        // emit event LogConfigureFeeRecipient
        emit LogConfigureFeeRecipient(feeRecipient, share);
    }

    /// @notice Updates the stability configuration settings, including the Chainlink verifier and maximum
    /// verification delay.
    /// @param chainlinkVerifier The address of the Chainlink verifier contract to be used for price verification.
    /// @param maxVerificationDelay The maximum allowed delay, in seconds, for price verification.
    function updateStabilityConfiguration(
        address chainlinkVerifier,
        uint128 maxVerificationDelay
    )
        external
        onlyOwner
    {
        if (chainlinkVerifier == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }

        if (maxVerificationDelay == 0) {
            revert Errors.ZeroInput("maxVerificationDelay");
        }

        StabilityConfiguration.update(chainlinkVerifier, maxVerificationDelay);

        emit LogUpdateStabilityConfig(chainlinkVerifier, maxVerificationDelay);
    }

    /// @notice Updates the asset allowance for a specific vault.
    /// @param vaultId The ID of the vault for which the asset allowance is being updated.
    /// @param allowance The new asset allowance amount to be set for the vault's index token.
    function updateVaultAssetAllowance(uint128 vaultId, uint256 allowance) external onlyOwner {
        Vault.Data storage vault = Vault.load(vaultId);

        ZlpVault(vault.indexToken).updateAssetAllowance(allowance);

        emit LogUpdateVaultAssetAllowance(vaultId, allowance);
    }

    /// @notice Configures the USD token swap parameters.
    /// @param baseFeeUsd The base fee applied to each swap.
    /// @param swapSettlementFeeBps The settlement fee in basis points applied to each swap.
    /// @param maxExecutionTime The maximum allowable time (in seconds) for swap execution.
    function configureUsdTokenSwapConfig(
        uint128 baseFeeUsd,
        uint128 swapSettlementFeeBps,
        uint128 maxExecutionTime
    )
        external
        onlyOwner
    {
        if (maxExecutionTime == 0) {
            revert Errors.ZeroInput("maxExecutionTime");
        }

        // emits event internally
        UsdTokenSwapConfig.update(baseFeeUsd, swapSettlementFeeBps, maxExecutionTime);
    }

    /// @notice Returns the fees associated with the USD token swap.
    /// @return swapSettlementFeeBps The swap settlement fee in basis points.
    /// @return baseFeeUsd The base fee in USD.
    function getUsdTokenSwapFees() external view returns (uint128 swapSettlementFeeBps, uint128 baseFeeUsd) {
        UsdTokenSwapConfig.Data storage data = UsdTokenSwapConfig.load();

        swapSettlementFeeBps = data.swapSettlementFeeBps;
        baseFeeUsd = data.baseFeeUsd;
    }

    /// @notice Retrieves the amount of USD tokens available for a specific engine.
    /// @param engine The address of the engine for which the available USD tokens are being retrieved.
    /// @return The amount of USD tokens available for the specified engine.
    function getUsdTokenAvailableForEngine(address engine) external view returns (uint256) {
        UsdTokenSwapConfig.Data storage data = UsdTokenSwapConfig.load();

        return data.usdcAvailableForEngine[engine];
    }

    /// @notice Sets the engine for a specific vault.
    /// @param vaultId The ID of the vault for which the engine is being set.
    /// @param engine The address of the engine to be associated with the specified vault.
    function setVaultEngine(uint128 vaultId, address engine) external onlyOwner {
        Vault.Data storage vaultData = Vault.load(vaultId);

        vaultData.engine = engine;

        emit LogSetVaultEngine(vaultId, engine);
    }

    /// @notice Retrieves the collateral data for a given asset.
    /// @param asset The address of the asset for which the collateral data is being retrieved.
    /// @return data The collateral data associated with the specified asset.
    function getCollateralData(address asset) external pure returns (Collateral.Data memory data) {
        data = Collateral.load(asset);
    }

    /// @notice Configures the referral module.
    /// @dev Only owner can configure the referral module.
    /// @param referralModule The address of the referral module.
    function configureReferralModule(address referralModule) external onlyOwner {
        // revert if the referral module is zero
        if (referralModule == address(0)) {
            revert Errors.ZeroInput("referralModule");
        }

        // load the perps engine configuration from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // set the referral module
        marketMakingEngineConfiguration.referralModule = referralModule;

        // emit the LogConfigureReferralModule event
        emit LogConfigureReferralModule(msg.sender, referralModule);
    }

    /// @notice Configure deposit and redeem fee to the vault
    /// @dev Only owner can call this function
    /// @param vaultsIds The array of vaults
    /// @param depositFees The array of deposit fees
    /// @param redeemFees The array of redeem fees
    function configureDepositAndRedeemFees(
        uint128[] calldata vaultsIds,
        uint128[] calldata depositFees,
        uint128[] calldata redeemFees
    )
        external
        onlyOwner
    {
        // verify the array length
        if (vaultsIds.length != depositFees.length) {
            revert Errors.ArrayLengthMismatch(vaultsIds.length, depositFees.length);
        }

        // verify the array length
        if (depositFees.length != redeemFees.length) {
            revert Errors.ArrayLengthMismatch(vaultsIds.length, depositFees.length);
        }

        // loop over the arrays
        for (uint256 i; i < vaultsIds.length; i++) {
            // load vault data from storage
            Vault.Data storage vault = Vault.load(vaultsIds[i]);

            // update deposit and redeem fees
            vault.depositFee = depositFees[i];
            vault.redeemFee = redeemFees[i];

            // emit events
            emit LogConfigureRedeemFee(vaultsIds[i], redeemFees[i]);
            emit LogConfigureDepositFee(vaultsIds[i], depositFees[i]);
        }
    }

    /// @notice Configure the vault deposit and redeem fee recipient
    /// @dev Only owner can call this function
    /// @param vaultDepositAndRedeemFeeRecipient The vault deposit and redeem fee recipient
    function configureVaultDepositAndRedeemFeeRecipient(address vaultDepositAndRedeemFeeRecipient)
        external
        onlyOwner
    {
        // revert if the vaultDepositAndRedeemFeeRecipient is zero
        if (vaultDepositAndRedeemFeeRecipient == address(0)) {
            revert Errors.ZeroInput("vaultDepositAndRedeemFeeRecipient");
        }

        // load the market making engine configuration from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // update the vault deposit and redeem fee recipient
        marketMakingEngineConfiguration.vaultDepositAndRedeemFeeRecipient = vaultDepositAndRedeemFeeRecipient;

        // emit the LogConfigureVaultDepositAndRedeemFeeRecipient event
        emit LogConfigureVaultDepositAndRedeemFeeRecipient(vaultDepositAndRedeemFeeRecipient);
    }

    /// @notice Configures a custom swap path for a specific asset.
    /// @param asset The address of the asset to configure the custom swap path for.
    /// @param enabled A boolean indicating whether the custom swap path is enabled or disabled.
    /// @param assets An array of asset addresses defining the swap path.
    /// @param dexSwapStrategyIds An array of DEX swap strategy IDs corresponding to each swap step.
    function configureAssetCustomSwapPath(
        address asset,
        bool enabled,
        address[] calldata assets,
        uint128[] calldata dexSwapStrategyIds
    )
        external
        onlyOwner
    {
        // each consecutive pair must have a swap strategy
        if (assets.length != dexSwapStrategyIds.length + 1) {
            revert Errors.InvalidSwapPathParamsLength();
        }

        AssetSwapPath.Data storage swapPath = AssetSwapPath.load(asset);
        swapPath.configure(enabled, assets, dexSwapStrategyIds);

        emit LogConfiguredSwapPath(asset, assets, dexSwapStrategyIds, enabled);
    }

    /// @notice Retrieves the custom swap path configuration for a given asset.
    /// @param asset The address of the asset for which the swap path is being queried.
    /// @return assets An array of asset addresses representing the swap path.
    /// @return dexSwapStrategyIds An array of DEX swap strategy IDs corresponding to each step in the swap path.
    function getAssetSwapPath(address asset)
        external
        view
        returns (address[] memory assets, uint128[] memory dexSwapStrategyIds)
    {
        AssetSwapPath.Data storage swapPath = AssetSwapPath.load(asset);

        assets = swapPath.assets;
        dexSwapStrategyIds = swapPath.dexSwapStrategyIds;
    }

    /// @notice Retrieves the IDs of all live markets.
    /// @return ids An array of `uint128` values representing the IDs of the live markets.
    function getLiveMarketIds() external view returns (uint128[] memory ids) {
        ids = LiveMarkets.load().getLiveMarketsIds();
    }

    /// @notice Configures the whitelist.
    /// @dev Only owner can configure the whitelist.
    /// @param whitelist The address of the whitelist.
    /// @param isWhitelistMode The boolean that indicates to use whitelist.
    function configureWhitelist(address whitelist, bool isWhitelistMode) external onlyOwner {
        // if whitelist mode is enabled, must have valid address
        if (isWhitelistMode && whitelist == address(0)) {
            revert Errors.ZeroInput("whitelist");
        }

        // set the whitelist address
        MarketMakingEngineConfiguration.load().whitelist = whitelist;

        // emit the LogConfigureWhitelist event
        emit LogConfigureWhitelist(whitelist, isWhitelistMode);
    }
}
