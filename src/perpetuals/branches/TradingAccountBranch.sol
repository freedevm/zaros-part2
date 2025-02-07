// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { ITradingAccountNFT } from "@zaros/trading-account-nft/interfaces/ITradingAccountNFT.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { TradingAccount } from "@zaros/perpetuals/leaves/TradingAccount.sol";
import { PerpsEngineConfiguration } from "@zaros/perpetuals/leaves/PerpsEngineConfiguration.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { Whitelist } from "@zaros/utils/Whitelist.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO, unary } from "@prb-math/SD59x18.sol";

/// @title Trading Account Branch.
/// @notice This branch is used by users in order to mint trading account nfts
/// to use them as trading subaccounts, managing their cross margin collateral and
/// trading on different perps markets.
contract TradingAccountBranch {
    using EnumerableSet for *;
    using TradingAccount for TradingAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using PerpsEngineConfiguration for PerpsEngineConfiguration.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using MarketOrder for MarketOrder.Data;

    /// @notice Emitted when a new trading account is created.
    /// @param tradingAccountId The trading account id.
    /// @param sender The `msg.sender` of the create account transaction.
    event LogCreateTradingAccount(uint128 tradingAccountId, address sender);

    /// @notice Emitted when `msg.sender` deposits `amount` of `collateralType` into `tradingAccountId`.
    /// @param sender The `msg.sender`.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of margin collateral deposited, notated in the `ERC20::decimals` value.
    event LogDepositMargin(
        address indexed sender, uint128 indexed tradingAccountId, address indexed collateralType, uint256 amount
    );

    /// @notice Emitted when `msg.sender` withdraws `amount` of `collateralType` from `tradingAccountId`.
    /// @param sender The `msg.sender`.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of margin collateral withdrawn (token::decimals()).
    event LogWithdrawMargin(
        address indexed sender, uint128 indexed tradingAccountId, address indexed collateralType, uint256 amount
    );

    /// @notice Gets the contract address of the trading accounts NFTs.
    /// @return tradingAccountToken The account token address.
    function getTradingAccountToken() public view returns (address) {
        return PerpsEngineConfiguration.load().tradingAccountToken;
    }

    /// @notice Returns the account's margin amount of the given collateral type.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @return marginCollateralBalanceX18 The margin collateral amount of the given collateral type.
    function getAccountMarginCollateralBalance(
        uint128 tradingAccountId,
        address collateralType
    )
        external
        view
        returns (UD60x18)
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        UD60x18 marginCollateralBalanceX18 = tradingAccount.getMarginCollateralBalance(collateralType);

        return marginCollateralBalanceX18;
    }

    /// @notice Returns the total equity of all assets under the trading account without considering the collateral
    /// value
    /// ratio
    /// @dev This function takes open positions into account.
    /// @dev This function doesn't take the configured LTV of margin collateral types into account.
    /// @param tradingAccountId The trading account id.
    /// @return equityUsdX18 The USD denominated total margin collateral value.
    function getAccountEquityUsd(uint128 tradingAccountId) external view returns (SD59x18) {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        SD59x18 activePositionsUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();

        return tradingAccount.getEquityUsd(activePositionsUnrealizedPnlUsdX18);
    }

    /// @notice Returns the trading account's total margin balance, available balance and maintenance margin.
    /// @dev This function does take open positions data such as unrealized pnl into account.
    /// @dev The margin balance value takes into account the margin collateral's configured ratio (LTV).
    /// @dev If the account's maintenance margin rate rises to 100% or above (MMR >= 1e18),
    /// the liquidation engine will be triggered.
    /// @param tradingAccountId The trading account id.
    /// @return marginBalanceUsdX18 The account's total margin balance.
    /// @return initialMarginUsdX18 The account's initial margin in positions.
    /// @return maintenanceMarginUsdX18 The account's maintenance margin.
    /// @return availableMarginUsdX18 The account's withdrawable margin balance.
    function getAccountMarginBreakdown(uint128 tradingAccountId)
        external
        view
        returns (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableMarginUsdX18
        )
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        SD59x18 activePositionsUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();

        marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(activePositionsUnrealizedPnlUsdX18);

        for (uint256 i; i < tradingAccount.activeMarketsIds.length(); i++) {
            uint128 marketId = tradingAccount.activeMarketsIds.at(i).toUint128();

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(tradingAccountId, marketId);

            UD60x18 indexPrice = perpMarket.getIndexPrice();
            UD60x18 markPrice = perpMarket.getMarkPrice(unary(sd59x18(position.size)), indexPrice);

            UD60x18 notionalValueX18 = position.getNotionalValue(markPrice);
            (UD60x18 positionInitialMarginUsdX18, UD60x18 positionMaintenanceMarginUsdX18) = Position
                .getMarginRequirement(
                notionalValueX18,
                ud60x18(perpMarket.configuration.initialMarginRateX18),
                ud60x18(perpMarket.configuration.maintenanceMarginRateX18)
            );

            initialMarginUsdX18 = initialMarginUsdX18.add(positionInitialMarginUsdX18);
            maintenanceMarginUsdX18 = maintenanceMarginUsdX18.add(positionMaintenanceMarginUsdX18);
        }

        availableMarginUsdX18 = marginBalanceUsdX18.sub((maintenanceMarginUsdX18).intoSD59x18());
    }

    /// @notice Returns the total trading account's unrealized pnl across open positions.
    /// @param tradingAccountId The trading account id.
    /// @return accountTotalUnrealizedPnlUsdX18 The account's total unrealized pnl.
    function getAccountTotalUnrealizedPnl(uint128 tradingAccountId)
        external
        view
        returns (SD59x18 accountTotalUnrealizedPnlUsdX18)
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        accountTotalUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();
    }

    /// @notice Returns the current leverage of a given account id, based on its cross margin collateral and open
    /// positions.
    /// @param tradingAccountId The trading account id.
    /// @return leverage The account leverage.
    function getAccountLeverage(uint128 tradingAccountId) external view returns (UD60x18) {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);

        SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(tradingAccount.getAccountUnrealizedPnlUsd());
        UD60x18 totalPositionsNotionalValue;

        if (marginBalanceUsdX18.isZero()) return marginBalanceUsdX18.intoUD60x18();

        for (uint256 i; i < tradingAccount.activeMarketsIds.length(); i++) {
            uint128 marketId = tradingAccount.activeMarketsIds.at(i).toUint128();

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(tradingAccountId, marketId);

            UD60x18 indexPrice = perpMarket.getIndexPrice();
            UD60x18 markPrice = perpMarket.getMarkPrice(unary(sd59x18(position.size)), indexPrice);

            UD60x18 positionNotionalValueX18 = position.getNotionalValue(markPrice);
            totalPositionsNotionalValue = totalPositionsNotionalValue.add(positionNotionalValueX18);
        }

        return totalPositionsNotionalValue.intoSD59x18().div(marginBalanceUsdX18).intoUD60x18();
    }

    /// @notice Gets the given market's position state.
    /// @param tradingAccountId The trading account id.
    /// @param marketId The perps market id.
    /// @param indexPrice The market's offchain index price.
    /// @return positionState The position's current state.
    function getPositionState(
        uint128 tradingAccountId,
        uint128 marketId,
        uint256 indexPrice
    )
        external
        view
        returns (Position.State memory positionState)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        Position.Data storage position = Position.load(tradingAccountId, marketId);

        UD60x18 markPriceX18 = perpMarket.getMarkPrice(unary(sd59x18(position.size)), ud60x18(indexPrice));
        SD59x18 fundingFeePerUnit =
            perpMarket.getNextFundingFeePerUnit(perpMarket.getCurrentFundingRate(), markPriceX18);

        positionState = position.getState(
            ud60x18(perpMarket.configuration.initialMarginRateX18),
            ud60x18(perpMarket.configuration.maintenanceMarginRateX18),
            markPriceX18,
            fundingFeePerUnit
        );
    }

    /// @notice Creates a new trading account and mints its NFT
    /// @param referralCode The referral code to use.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    /// @return tradingAccountId The trading account id.
    function createTradingAccount(
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        public
        virtual
        returns (uint128 tradingAccountId)
    {
        // fetch storage slot for perps engine configuration
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        // enforce whitelist if enabled
        address whitelistCache = perpsEngineConfiguration.whitelist;
        if (whitelistCache != address(0)) {
            if (!Whitelist(whitelistCache).verifyIfUserIsAllowed(msg.sender)) {
                revert Errors.UserIsNotAllowed(msg.sender);
            }
        }

        // increment next account id & output
        tradingAccountId = ++perpsEngineConfiguration.nextAccountId;

        // get refrence to account nft token
        ITradingAccountNFT tradingAccountToken = ITradingAccountNFT(perpsEngineConfiguration.tradingAccountToken);

        // create account record
        TradingAccount.create(tradingAccountId, msg.sender);

        // mint nft token to account owner
        tradingAccountToken.mint(msg.sender, tradingAccountId);

        emit LogCreateTradingAccount(tradingAccountId, msg.sender);

        IReferral referralModule = IReferral(perpsEngineConfiguration.referralModule);

        if (referralCode.length != 0) {
            referralModule.registerReferral(
                abi.encode(tradingAccountId), msg.sender, referralCode, isCustomReferralCode
            );
        }

        return tradingAccountId;
    }

    /// @notice Creates a new trading account and multicalls using the provided data payload.
    /// @param data The data payload to be multicalled.
    /// @param referralCode The referral code to use.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    /// @return results The array of results of the multicall.
    function createTradingAccountAndMulticall(
        bytes[] calldata data,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external
        virtual
        returns (bytes[] memory results)
    {
        uint128 tradingAccountId = createTradingAccount(referralCode, isCustomReferralCode);

        results = new bytes[](data.length);
        for (uint256 i; i < data.length; i++) {
            bytes memory dataWithAccountId = bytes.concat(data[i][0:4], abi.encode(tradingAccountId), data[i][4:]);
            (bool success, bytes memory result) = address(this).delegatecall(dataWithAccountId);

            if (!success) {
                uint256 len = result.length;
                assembly {
                    revert(add(result, 0x20), len)
                }
            }

            results[i] = result;
        }
    }

    /// @notice Deposits margin collateral into the given trading account.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to deposit.
    function depositMargin(uint128 tradingAccountId, address collateralType, uint256 amount) public virtual {
        // fetch storage slot for this collateral's config config
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        // load existing trading account; reverts for non-existent account
        // does not enforce msg.sender == account owner so anyone can deposit
        // collateral for other traders if they wish
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);

        // reverts if a trader has a pending order
        _requireNoActiveMarketOrder(tradingAccountId);

        // convert uint256 -> UD60x18; scales input amount to 18 decimals
        UD60x18 amountX18 = marginCollateralConfiguration.convertTokenAmountToUd60x18(amount);

        // uint128 -> UD60x18
        UD60x18 depositCapX18 = ud60x18(marginCollateralConfiguration.depositCap);

        // uint256 -> UD60x18
        UD60x18 totalCollateralDepositedX18 = ud60x18(marginCollateralConfiguration.totalDeposited);

        // enforce converted amount > 0
        _requireAmountNotZero(amountX18);

        // enforce new deposit + already deposited <= deposit cap
        _requireEnoughDepositCap(collateralType, amountX18, depositCapX18, totalCollateralDepositedX18);

        // enforce collateral has configured liquidation priority
        _requireCollateralLiquidationPriorityDefined(collateralType);

        // get the tokens first
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);

        // then perform the actual deposit
        tradingAccount.deposit(collateralType, amountX18);

        emit LogDepositMargin(msg.sender, tradingAccountId, collateralType, amount);
    }

    /// @notice Withdraws available margin collateral from the given trading account.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The UD60x18 amount of margin collateral to withdraw.
    function withdrawMargin(uint128 tradingAccountId, address collateralType, uint256 amount) external {
        // fetch storage slot for this collateral's config config
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        // load existing trading account; reverts for non-existent account
        // enforces `msg.sender == owner` so only account owner can withdraw
        TradingAccount.Data storage tradingAccount =
            TradingAccount.loadExistingAccountAndVerifySender(tradingAccountId);

        // reverts if a trader has a pending order
        _requireNoActiveMarketOrder(tradingAccountId);

        // convert uint256 -> UD60x18; scales input amount to 18 decimals
        UD60x18 amountX18 = marginCollateralConfiguration.convertTokenAmountToUd60x18(amount);

        // enforce converted amount > 0
        _requireAmountNotZero(amountX18);

        // enforces that user has deposited enough collateral of this type to withdraw
        _requireEnoughMarginCollateral(tradingAccount, collateralType, amountX18);

        // deduct amount from trader's collateral balance
        tradingAccount.withdraw(collateralType, amountX18);

        // load account required initial margin requirement & unrealized USD profit/loss
        // ignores "required maintenance margin" output parameter
        (UD60x18 requiredInitialMarginUsdX18,, SD59x18 accountTotalUnrealizedPnlUsdX18) =
            tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, SD59x18_ZERO);

        // get trader's margin balance
        SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

        // check against initial margin requirement as initial margin > maintenance margin
        // hence prevent the user from withdrawing all the way to the maintenance margin
        // so that they couldn't be liquidated very soon afterwards if their position
        // goes against them even a little bit
        tradingAccount.validateMarginRequirement(requiredInitialMarginUsdX18, marginBalanceUsdX18, UD60x18_ZERO);

        // cache whether the trader has an active position or not
        bool userHasOpenPosition = !requiredInitialMarginUsdX18.isZero();

        if (userHasOpenPosition) {
            // load perps engine configuration from storage
            PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

            // save the trader's magin balance without taking the unrealized pnl into account
            SD59x18 marginBalanceUsdWithoutUnrealizedPnlUsdX18 = tradingAccount.getMarginBalanceUsd(SD59x18_ZERO);

            // verify if after the withdrawal the account will still own enough collateral to cover the liquidation
            // fee value
            if (
                marginBalanceUsdWithoutUnrealizedPnlUsdX18.lt(
                    sd59x18(int128(perpsEngineConfiguration.liquidationFeeUsdX18))
                )
            ) {
                revert Errors.NotEnoughCollateralForLiquidationFee(perpsEngineConfiguration.liquidationFeeUsdX18);
            }
        }

        // finally send the tokens
        IERC20(collateralType).safeTransfer(msg.sender, amount);

        emit LogWithdrawMargin(msg.sender, tradingAccountId, collateralType, amount);
    }

    /// @notice Used by the Account NFT contract to notify an account transfer.
    /// @dev Can only be called by the Account NFT contract.
    /// @dev It updates the Trading Account stored access control data and cancel existing pending orders.
    /// @param to The recipient of the account transfer.
    /// @param tradingAccountId The trading account id.
    function notifyAccountTransfer(address to, uint128 tradingAccountId) external {
        _onlyTradingAccountToken();

        // load trader's orders
        MarketOrder.Data storage marketOrder = MarketOrder.load(tradingAccountId);

        // cancel pending order if it exists
        if (marketOrder.marketId != 0) {
            // reverts if a trader has a pending order and that pending order hasn't
            // existed for the minimum order lifetime; pending orders can't be cancelled
            // until they have existed for the minimum order lifetime
            marketOrder.checkPendingOrder();
            // cancel pending order
            marketOrder.clear();

            emit OrderBranch.LogCancelMarketOrder(msg.sender, tradingAccountId);
        }

        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        tradingAccount.owner = to;
    }

    /// @notice Get the user referral data
    /// @param tradingAccountId The trading account id.
    /// @return referralCode The user's referral code.
    /// @return isCustomReferralCode A boolean indicating if the referral code is custom.
    function getUserReferralData(uint128 tradingAccountId) external view returns (bytes memory, bool) {
        // fetch storage slot for perps engine configuration
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        IReferral referralModule = IReferral(perpsEngineConfiguration.referralModule);

        (bytes memory referralCode, bool isCustomReferralCode) =
            referralModule.getUserReferralData(abi.encode(tradingAccountId));

        return (referralCode, isCustomReferralCode);
    }

    /// @notice Reverts if the amount is zero.
    function _requireAmountNotZero(UD60x18 amount) internal pure {
        if (amount.isZero()) {
            revert Errors.ZeroInput("amount");
        }
    }

    /// @notice Reverts if the deposit cap is exceeded.
    function _requireEnoughDepositCap(
        address collateralType,
        UD60x18 amount,
        UD60x18 depositCap,
        UD60x18 totalCollateralDeposited
    )
        internal
        pure
    {
        if (amount.add(totalCollateralDeposited).gt(depositCap)) {
            revert Errors.DepositCap(collateralType, amount.intoUint256(), depositCap.intoUint256());
        }
    }

    /// @notice Reverts if the given collateral type is not in the liquidation priority list.
    function _requireCollateralLiquidationPriorityDefined(address collateralType) internal view {
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();
        bool isInCollateralLiquidationPriority =
            perpsEngineConfiguration.collateralLiquidationPriority.contains(collateralType);

        if (!isInCollateralLiquidationPriority) revert Errors.CollateralLiquidationPriorityNotDefined(collateralType);
    }

    /// @notice Checks if there's enough margin collateral balance to be withdrawn.
    /// @param tradingAccount The trading account storage pointer.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to be withdrawn.
    function _requireEnoughMarginCollateral(
        TradingAccount.Data storage tradingAccount,
        address collateralType,
        UD60x18 amount
    )
        internal
        view
    {
        // get currently deposited scaled-to-18-decimals this account has
        // for this collateral type
        UD60x18 marginCollateralBalanceX18 = tradingAccount.getMarginCollateralBalance(collateralType);

        // enforces that user has deposited sufficient collateral of this
        // type; they can only withdraw what they have deposited/remaining
        if (marginCollateralBalanceX18.lt(amount)) {
            revert Errors.InsufficientCollateralBalance(
                amount.intoUint256(), marginCollateralBalanceX18.intoUint256()
            );
        }
    }

    /// @notice Reverts if the trading account has a pending order.
    /// @param tradingAccountId The trading account id.
    function _requireNoActiveMarketOrder(uint128 tradingAccountId) internal view {
        // fetch storage slot for this trading account's market order
        MarketOrder.Data storage marketOrder = MarketOrder.load(tradingAccountId);

        // reverts if a trader has a pending order and that pending order hasn't
        // existed for the minimum order lifetime
        marketOrder.checkPendingOrder();

        // reverts if the trader has a pending order
        if (marketOrder.marketId != 0) {
            revert Errors.ActiveMarketOrder(
                tradingAccountId, marketOrder.marketId, marketOrder.sizeDelta, marketOrder.timestamp
            );
        }
    }

    /// @dev Reverts if the caller is not the account owner.
    function _onlyTradingAccountToken() internal view {
        if (msg.sender != address(getTradingAccountToken())) {
            revert Errors.OnlyTradingAccountToken(msg.sender);
        }
    }
}
