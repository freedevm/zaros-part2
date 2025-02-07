// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngineConfiguration } from "@zaros/perpetuals/leaves/PerpsEngineConfiguration.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";
import { MarketConfiguration } from "@zaros/perpetuals/leaves/MarketConfiguration.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";

// PRB Math dependencies
import { sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin Upgradeable dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { ERC20, IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

/// @title Perps Engine Configuration Branch.
/// @notice This  is used by the protocol controller to configure the perps
/// exchange system.
contract PerpsEngineConfigurationBranch is OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using PerpsEngineConfiguration for PerpsEngineConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using MarketConfiguration for MarketConfiguration.Data;

    constructor() {
        _disableInitializers();
    }

    /// @notice Emitted when the account token address is set.
    event LogSetTradingAccountToken(address indexed sender, address indexed tradingAccountToken);

    /// @notice Emitted when the usd token address is set.
    event LogSetUsdToken(address indexed sender, address indexed usdToken);

    /// @notice Emitted when the collateral priority is configured.
    /// @param sender The address that configured the collateral priority.
    /// @param collateralTypes The array of collateral type addresses, ordered by priority.
    event LogConfigureCollateralLiquidationPriority(address indexed sender, address[] collateralTypes);

    /// @notice Emitted when the liquidators are configured.
    /// @param sender The address that configured the liquidators.
    /// @param liquidators The array of liquidator addresses.
    /// @param enable The array of boolean values that enable or disable the liquidator.
    event LogConfigureLiquidators(address indexed sender, address[] liquidators, bool[] enable);

    /// @notice Emitted when a new collateral type is enabled or disabled.
    /// @param sender The address that enabled or disabled the collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param decimals The amount of decimals of the collateral type's ERC20 token.
    /// @param priceAdapter The price oracle address.
    event LogConfigureMarginCollateral(
        address indexed sender,
        address indexed collateralType,
        uint128 depositCap,
        uint120 loanToValue,
        uint8 decimals,
        address priceAdapter
    );

    /// @notice Emitted when a collateral type is removed from the collateral priority.
    /// @param sender The address that removed the collateral type from the priority list.
    /// @param collateralType The address of the collateral type.
    event LogRemoveCollateralFromLiquidationPriority(address indexed sender, address indexed collateralType);

    /// @notice Emitted when the global system parameters are configured.
    /// @param sender The address that configured the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMinLifetime The minimum lifetime of a market order to be considered active.
    /// @param liquidationFeeUsdX18 The liquidation fee in USD.
    event LogConfigureSystemParameters(
        address indexed sender,
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMinLifetime,
        uint128 liquidationFeeUsdX18
    );

    /// @notice Emitted when a new perps market is created.
    /// @param sender The address that configured the price adapter.
    /// @param marketId The perps market id.
    event LogCreatePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted when a perps market is reconfigured.
    /// @param sender The address that configured the perps market.
    /// @param marketId The perps market id.
    event LogUpdatePerpMarketConfiguration(address indexed sender, uint128 marketId);

    /// @notice Emitted when the settlement configuration of a given market is updated.
    /// @param sender The address that updated the settlement configuration.
    /// @param marketId The perps market id.
    /// @param settlementConfigurationId The perps market settlement configuration id.
    event LogUpdateSettlementConfiguration(
        address indexed sender, uint128 indexed marketId, uint128 settlementConfigurationId
    );

    /// @notice Emitted when a perp market is re-enabled by the owner.
    /// @param marketId The perps market id.
    event LogEnablePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted when a perp market is disabled by the owner.
    /// @param marketId The perps market id.
    event LogDisablePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted whe the referral module is configured.
    /// @param sender The address that configured the referral module.
    /// @param referralModule The address of the referral module.
    event LogConfigureReferralModule(address sender, address referralModule);

    /// @notice Emitted when the whitelist configured.
    /// @param whitelist The address of the whitelist.
    /// @param isWhitelistMode The boolean that indicates to use whitelist.
    event LogConfigureWhitelist(address whitelist, bool isWhitelistMode);

    /// @notice Ensures that perp market is initialized.
    /// @param marketId The perps market id.
    modifier onlyWhenPerpMarketIsInitialized(uint128 marketId) {
        PerpMarket.Data memory perpMarket = PerpMarket.load(marketId);

        if (!perpMarket.initialized) {
            revert Errors.PerpMarketNotInitialized(marketId);
        }

        _;
    }

    /// @param lowerBound The lower bound of the accounts to retrieve.
    /// @param upperBound The upper bound of the accounts to retrieve.
    function getAccountsWithActivePositions(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view
        returns (uint128[] memory accountsIds)
    {
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        accountsIds = new uint128[](upperBound - lowerBound + 1);

        uint256 index = 0;
        for (uint256 i = lowerBound; i <= upperBound; i++) {
            accountsIds[index] = uint128(perpsEngineConfiguration.accountsIdsWithActivePositions.at(i));
            index++;
        }
    }

    /// @notice Returns the address of custom referral code
    /// @param customReferralCode The custom referral code.
    /// @return referrer The address of the referrer.
    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) {
        // load the perps engine configuration from storage
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        return IReferral(perpsEngineConfiguration.referralModule).getCustomReferralCodeReferrer(customReferralCode);
    }

    /// @dev Returns the maximum amount that can be deposited as margin for a given
    /// collateral type.
    /// @param collateralType The address of the collateral type.
    /// @return marginCollateralConfiguration The configuration parameters of the given collateral type.
    function getMarginCollateralConfiguration(address collateralType)
        external
        pure
        returns (MarginCollateralConfiguration.Data memory)
    {
        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        return marginCollateralConfiguration;
    }

    /// @notice Sets the address of the account token NFT contract.
    /// @param tradingAccountToken The account token address.
    function setTradingAccountToken(address tradingAccountToken) external onlyOwner {
        if (tradingAccountToken == address(0)) {
            revert Errors.TradingAccountTokenNotDefined();
        }

        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();
        perpsEngineConfiguration.tradingAccountToken = tradingAccountToken;

        emit LogSetTradingAccountToken(msg.sender, tradingAccountToken);
    }

    /// @notice Sets the address of the usd token.
    /// @param usdToken The token address.
    function setUsdToken(address usdToken) external onlyOwner {
        if (usdToken == address(0)) {
            revert Errors.ZeroInput("usdToken");
        }

        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();
        perpsEngineConfiguration.usdToken = usdToken;

        emit LogSetUsdToken(msg.sender, usdToken);
    }

    /// @notice Configures the collateral priority.
    /// @param collateralTypes The array of collateral type addresses.
    function configureCollateralLiquidationPriority(address[] calldata collateralTypes) external onlyOwner {
        if (collateralTypes.length == 0) {
            revert Errors.ZeroInput("collateralTypes");
        }

        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();
        perpsEngineConfiguration.configureCollateralLiquidationPriority(collateralTypes);

        emit LogConfigureCollateralLiquidationPriority(msg.sender, collateralTypes);
    }

    /// @notice Configures the liquidators.
    /// @param liquidators The array of liquidator addresses.
    /// @param enable The array of boolean values that enable or disable the liquidator.
    function configureLiquidators(address[] calldata liquidators, bool[] calldata enable) external onlyOwner {
        if (liquidators.length == 0) {
            revert Errors.ZeroInput("liquidators");
        }

        if (liquidators.length != enable.length) {
            revert Errors.ArrayLengthMismatch(liquidators.length, enable.length);
        }

        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        for (uint256 i; i < liquidators.length; i++) {
            perpsEngineConfiguration.isLiquidatorEnabled[liquidators[i]] = enable[i];
        }

        emit LogConfigureLiquidators(msg.sender, liquidators, enable);
    }

    /// @notice Configures the settings of a given margin collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param priceAdapter The price adapter contract, which handles the market's index price.
    function configureMarginCollateral(
        address collateralType,
        uint128 depositCap,
        uint120 loanToValue,
        address priceAdapter
    )
        external
        onlyOwner
    {
        try ERC20(collateralType).decimals() returns (uint8 decimals) {
            if (decimals > Constants.SYSTEM_DECIMALS || priceAdapter == address(0) || decimals == 0) {
                revert Errors.InvalidMarginCollateralConfiguration(collateralType, decimals, priceAdapter);
            }
            MarginCollateralConfiguration.configure(collateralType, depositCap, loanToValue, decimals, priceAdapter);

            emit LogConfigureMarginCollateral(
                msg.sender, collateralType, depositCap, loanToValue, decimals, priceAdapter
            );
        } catch {
            revert Errors.InvalidMarginCollateralConfiguration(collateralType, 0, priceAdapter);
        }
    }

    /// @notice Removes the given collateral type from the collateral priority.
    /// @param collateralType The address of the collateral type to remove.
    function removeCollateralFromLiquidationPriority(address collateralType) external onlyOwner {
        if (collateralType == address(0)) {
            revert Errors.ZeroInput("collateralType");
        }

        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();
        perpsEngineConfiguration.removeCollateralFromLiquidationPriority(collateralType);

        emit LogRemoveCollateralFromLiquidationPriority(msg.sender, collateralType);
    }

    /// @notice Configures the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMinLifetime The minimum lifetime of a market order to be considered active.
    /// @param liquidationFeeUsdX18 The liquidation fee in USD.
    /// @param marginCollateralRecipient The address that receives the margin collateral.
    /// @param orderFeeRecipient The address that receives the order fees.
    /// @param settlementFeeRecipient The address that receives the settlement fees.
    /// @param liquidationFeeRecipient The address that receives the liquidation fees.
    /// @param marketMakingEngine The address of the market making engine.
    /// @param referralModule The address of the referral module.
    /// @param whitelist The address of the whitelist.
    /// @param maxVerificationDelay The maximum verification delay.
    /// @param isWhitelistMode The boolean that indicates to use whitelist.
    function configureSystemParameters(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMinLifetime,
        uint128 liquidationFeeUsdX18,
        address marginCollateralRecipient,
        address orderFeeRecipient,
        address settlementFeeRecipient,
        address liquidationFeeRecipient,
        address marketMakingEngine,
        address referralModule,
        address whitelist,
        uint256 maxVerificationDelay,
        bool isWhitelistMode
    )
        external
        onlyOwner
    {
        if (maxPositionsPerAccount == 0) {
            revert Errors.ZeroInput("maxPositionsPerAccount");
        }

        if (liquidationFeeUsdX18 == 0) {
            revert Errors.ZeroInput("liquidationFeeUsdX18");
        }

        if (marginCollateralRecipient == address(0)) {
            revert Errors.ZeroInput("marginCollateralRecipient");
        }

        if (orderFeeRecipient == address(0)) {
            revert Errors.ZeroInput("orderFeeRecipient");
        }

        if (settlementFeeRecipient == address(0)) {
            revert Errors.ZeroInput("settlementFeeRecipient");
        }

        if (liquidationFeeRecipient == address(0)) {
            revert Errors.ZeroInput("liquidationFeeRecipient");
        }

        if (marketMakingEngine == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        if (referralModule == address(0)) {
            revert Errors.ZeroInput("referralModule");
        }

        if (maxVerificationDelay == 0) {
            revert Errors.ZeroInput("maxVerificationDelay");
        }

        // if whitelist mode is enabled, must have valid address
        if (isWhitelistMode && whitelist == address(0)) {
            revert Errors.ZeroInput("whitelist");
        }

        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        perpsEngineConfiguration.maxPositionsPerAccount = maxPositionsPerAccount;
        perpsEngineConfiguration.marketOrderMinLifetime = marketOrderMinLifetime;
        perpsEngineConfiguration.liquidationFeeUsdX18 = liquidationFeeUsdX18;
        perpsEngineConfiguration.marginCollateralRecipient = marginCollateralRecipient;
        perpsEngineConfiguration.orderFeeRecipient = orderFeeRecipient;
        perpsEngineConfiguration.settlementFeeRecipient = settlementFeeRecipient;
        perpsEngineConfiguration.liquidationFeeRecipient = liquidationFeeRecipient;
        perpsEngineConfiguration.marketMakingEngine = marketMakingEngine;
        perpsEngineConfiguration.referralModule = referralModule;
        perpsEngineConfiguration.whitelist = whitelist;
        perpsEngineConfiguration.maxVerificationDelay = maxVerificationDelay;

        emit LogConfigureSystemParameters(
            msg.sender, maxPositionsPerAccount, marketOrderMinLifetime, liquidationFeeUsdX18
        );

        // emit the LogConfigureWhitelist event
        emit LogConfigureWhitelist(whitelist, isWhitelistMode);
    }

    /// @notice `createPerpMarket` function parameters.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    /// @param priceAdapter The price adapter contract, which handles the market's index price.
    /// @param initialMarginRateX18 The perps market min initial margin rate, which defines the max leverage.
    /// @param maintenanceMarginRateX18 The perps market maintenance margin rate.
    /// @param maxOpenInterest The perps market maximum open interest per side.
    /// @param maxSkew The perp market maximum skew value.
    /// @param maxFundingVelocity The perps market maximum funding rate velocity.
    /// @param minTradeSizeX18 The minimum size of a trade in contract units.
    /// @param skewScale The configuration parameter used to scale the market's price impact and funding rate.
    /// @param marketOrderConfiguration The market order settlement configuration of the given perp market.
    /// @param offchainOrdersConfiguration The offchain orders settlement configuration of the given perp market.
    /// @param orderFees The perps market maker and taker fees.
    struct CreatePerpMarketParams {
        uint128 marketId;
        string name;
        string symbol;
        address priceAdapter;
        uint128 initialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxSkew;
        uint128 maxFundingVelocity;
        uint128 minTradeSizeX18;
        uint256 skewScale;
        SettlementConfiguration.Data marketOrderConfiguration;
        SettlementConfiguration.Data offchainOrdersConfiguration;
        OrderFees.Data orderFees;
    }

    /// @notice Creates a new market with the requested market id.
    /// @dev See {CreatePerpMarketParams}.
    function createPerpMarket(CreatePerpMarketParams calldata params) external onlyOwner {
        if (params.marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (abi.encodePacked(params.name).length == 0) {
            revert Errors.ZeroInput("name");
        }
        if (abi.encodePacked(params.symbol).length == 0) {
            revert Errors.ZeroInput("symbol");
        }
        if (params.priceAdapter == address(0)) {
            revert Errors.ZeroInput("priceAdapter");
        }
        if (params.maintenanceMarginRateX18 == 0) {
            revert Errors.ZeroInput("maintenanceMarginRateX18");
        }
        if (params.maxOpenInterest == 0) {
            revert Errors.ZeroInput("maxOpenInterest");
        }
        if (params.maxSkew == 0) {
            revert Errors.ZeroInput("maxSkew");
        }
        if (params.initialMarginRateX18 <= params.maintenanceMarginRateX18) {
            revert Errors.InitialMarginRateLessOrEqualThanMaintenanceMarginRate();
        }
        if (params.skewScale == 0) {
            revert Errors.ZeroInput("skewScale");
        }
        if (params.minTradeSizeX18 == 0) {
            revert Errors.ZeroInput("minTradeSizeX18");
        }
        if (params.maxFundingVelocity == 0) {
            revert Errors.ZeroInput("maxFundingVelocity");
        }

        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        PerpMarket.create(
            PerpMarket.CreateParams({
                marketId: params.marketId,
                name: params.name,
                symbol: params.symbol,
                priceAdapter: params.priceAdapter,
                initialMarginRateX18: params.initialMarginRateX18,
                maintenanceMarginRateX18: params.maintenanceMarginRateX18,
                maxOpenInterest: params.maxOpenInterest,
                maxSkew: params.maxSkew,
                maxFundingVelocity: params.maxFundingVelocity,
                minTradeSizeX18: params.minTradeSizeX18,
                skewScale: params.skewScale,
                marketOrderConfiguration: params.marketOrderConfiguration,
                offchainOrdersConfiguration: params.offchainOrdersConfiguration,
                orderFees: params.orderFees
            })
        );
        perpsEngineConfiguration.addMarket(params.marketId);

        emit LogCreatePerpMarket(msg.sender, params.marketId);
    }

    /// @notice `updatePerpMarketConfiguration` params.
    /// @param name The perp market name.
    /// @param symbol The perp market symbol.
    /// @param priceAdapter The price adapter contract, which handles the market's index price.
    /// @param initialMarginRateX18 The perp market min initial margin rate, which defines the max leverage.
    /// @param maintenanceMarginRateX18 The perp market maintenance margin rate.
    /// @param maxOpenInterest The perp market maximum open interest per side.
    /// @param maxSkew The perp market maximum skew value.
    /// @param maxFundingVelocity The perp market maximum funding rate velocity.
    /// @param minTradeSizeX18 The minimum size of a trade in contract units.
    /// @param skewScale The configuration parameter used to scale the market's price impact and funding rate.
    /// @param orderFees The perp market maker and taker fees.
    struct UpdatePerpMarketConfigurationParams {
        string name;
        string symbol;
        address priceAdapter;
        uint128 initialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxSkew;
        uint128 minTradeSizeX18;
        uint128 maxFundingVelocity;
        uint256 skewScale;
        OrderFees.Data orderFees;
    }

    /// @notice Updates the configuration variables of the given perp market id.
    /// @dev A market's configuration must be updated with caution, as the update of some variables may directly
    /// impact open positions.
    /// @dev See {UpdatePerpMarketConfigurationParams}.
    function updatePerpMarketConfiguration(
        uint128 marketId,
        UpdatePerpMarketConfigurationParams calldata params
    )
        external
        onlyOwner
        onlyWhenPerpMarketIsInitialized(marketId)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        MarketConfiguration.Data storage perpMarketConfiguration = perpMarket.configuration;

        if (abi.encodePacked(params.name).length == 0) {
            revert Errors.ZeroInput("name");
        }
        if (abi.encodePacked(params.symbol).length == 0) {
            revert Errors.ZeroInput("symbol");
        }
        if (params.priceAdapter == address(0)) {
            revert Errors.ZeroInput("priceAdapter");
        }
        if (params.maintenanceMarginRateX18 == 0) {
            revert Errors.ZeroInput("maintenanceMarginRateX18");
        }
        if (params.maxOpenInterest == 0) {
            revert Errors.ZeroInput("maxOpenInterest");
        }
        if (params.maxSkew == 0) {
            revert Errors.ZeroInput("maxSkew");
        }
        if (params.initialMarginRateX18 == 0) {
            revert Errors.ZeroInput("initialMarginRateX18");
        }
        if (params.initialMarginRateX18 <= params.maintenanceMarginRateX18) {
            revert Errors.InitialMarginRateLessOrEqualThanMaintenanceMarginRate();
        }
        if (params.skewScale == 0) {
            revert Errors.ZeroInput("skewScale");
        }
        if (params.minTradeSizeX18 == 0) {
            revert Errors.ZeroInput("minTradeSizeX18");
        }
        if (params.maxFundingVelocity == 0) {
            revert Errors.ZeroInput("maxFundingVelocity");
        }

        perpMarket.updateFunding(sd59x18(perpMarket.lastFundingRate), sd59x18(perpMarket.lastFundingFeePerUnit));

        perpMarketConfiguration.update(
            MarketConfiguration.Data({
                name: params.name,
                symbol: params.symbol,
                priceAdapter: params.priceAdapter,
                initialMarginRateX18: params.initialMarginRateX18,
                maintenanceMarginRateX18: params.maintenanceMarginRateX18,
                maxOpenInterest: params.maxOpenInterest,
                maxSkew: params.maxSkew,
                maxFundingVelocity: params.maxFundingVelocity,
                minTradeSizeX18: params.minTradeSizeX18,
                skewScale: params.skewScale,
                orderFees: params.orderFees
            })
        );

        emit LogUpdatePerpMarketConfiguration(msg.sender, marketId);
    }

    /// @notice Updates the settlement configuration of a given market.
    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id.
    /// @param newSettlementConfiguration The new settlement configuration.
    function updateSettlementConfiguration(
        uint128 marketId,
        uint128 settlementConfigurationId,
        SettlementConfiguration.Data memory newSettlementConfiguration
    )
        external
        onlyOwner
        onlyWhenPerpMarketIsInitialized(marketId)
    {
        if (
            settlementConfigurationId != SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID
                && settlementConfigurationId != SettlementConfiguration.OFFCHAIN_ORDERS_CONFIGURATION_ID
        ) {
            revert Errors.InvalidSettlementConfigurationId();
        }
        SettlementConfiguration.update(marketId, settlementConfigurationId, newSettlementConfiguration);

        emit LogUpdateSettlementConfiguration(msg.sender, marketId, settlementConfigurationId);
    }

    /// @notice Enables or disabled the perp market of the given market id.
    /// @param marketId The perps market id.
    /// @param enable Whether the market should be enabled or disabled.
    function updatePerpMarketStatus(
        uint128 marketId,
        bool enable
    )
        external
        onlyOwner
        onlyWhenPerpMarketIsInitialized(marketId)
    {
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        if (enable) {
            perpsEngineConfiguration.addMarket(marketId);

            emit LogEnablePerpMarket(msg.sender, marketId);
        } else {
            perpsEngineConfiguration.removeMarket(marketId);

            emit LogDisablePerpMarket(msg.sender, marketId);
        }
    }

    /// @notice Creates a custom referral code.
    /// @param referrer The address of the referrer.
    /// @param customReferralCode The custom referral code.
    function createCustomReferralCode(address referrer, string memory customReferralCode) external onlyOwner {
        // load the perps engine configuration from storage
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        // load the referral module
        IReferral referralModule = IReferral(perpsEngineConfiguration.referralModule);

        // create the custom referral code
        referralModule.createCustomReferralCode(referrer, customReferralCode);
    }

    /// @notice Updates the allowance of the market making engine to spend the provided tokens.
    /// @param tokens The array of ERC20 token addresses.
    /// @param allowances The array of ERC20 token allowances.
    function setMarketMakingEngineAllowance(
        IERC20[] calldata tokens,
        uint256[] calldata allowances
    )
        external
        onlyOwner
    {
        if (tokens.length == 0) {
            revert Errors.ZeroInput("tokens");
        }

        if (tokens.length != allowances.length) {
            revert Errors.ArrayLengthMismatch(tokens.length, allowances.length);
        }

        // loads the perps engine configuration
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        // approves the market making engine to spend each provided token
        for (uint256 i; i < tokens.length; i++) {
            tokens[i].approve(perpsEngineConfiguration.marketMakingEngine, allowances[i]);
        }
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
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        // set the referral module
        perpsEngineConfiguration.referralModule = referralModule;

        // emit the LogConfigureReferralModule event
        emit LogConfigureReferralModule(msg.sender, referralModule);
    }
}
