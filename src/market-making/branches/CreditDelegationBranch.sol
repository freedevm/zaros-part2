// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { UsdToken } from "@zaros/usd/UsdToken.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD59x18_ZERO, unary } from "@prb-math/SD59x18.sol";

/// @dev This contract deals with USDC to settle protocol debt, used to back USD Token
contract CreditDelegationBranch is EngineAccessControl {
    using Collateral for Collateral.Data;
    using DexSwapStrategy for DexSwapStrategy.Data;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using Market for Market.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeCast for uint256;
    using SafeCast for uint128;
    using SafeCast for int256;
    using SafeERC20 for IERC20;
    using Vault for Vault.Data;

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a system keeper converts a market's assets deposited as credit to USDC.
    /// @param marketId The market identifier.
    /// @param asset The asset used for credit deposits to be settled for USDC.
    /// @param assetAmount The token amount of assets deposited as credit.
    /// @param usdcOut The amount of USDC received from the swap.
    event LogConvertMarketCreditDepositsToUsdc(
        uint128 indexed marketId, address asset, uint256 assetAmount, uint256 usdcOut
    );

    /// @notice Emitted when the market making engine receives margin collateral from an engine.
    /// @param engine The address of the engine that called the function.
    /// @param marketId The engine's market id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral received.
    event LogDepositCreditForMarket(
        address indexed engine, uint128 indexed marketId, address collateralType, uint256 amount
    );

    /// @notice Emitted when the perps engine requests USD Token to be minted by the market making engine.
    /// @param engine The address of the engine that called the function.
    /// @param marketId The engine's market id.
    /// @param requestedUsdTokenAmount The requested amount of USD Token to minted.
    /// @param mintedUsdTokenAmount The actual amount of USD Token minted, potentially factored by the market's auto
    /// deleverage system.
    event LogWithdrawUsdTokenFromMarket(
        address indexed engine,
        uint128 indexed marketId,
        uint256 requestedUsdTokenAmount,
        uint256 mintedUsdTokenAmount
    );

    /// @notice Emitted when a vault's debt or credit is settled.
    /// @dev Some of the emitted values are zero depending on the vault's state.
    /// @param vaultId The vault identifier.
    /// @param assetIn The asset sold to settle the credit or debt.
    /// @param assetInAmount The amount of assets sold.
    /// @param assetOut The asset bought to settle the credit or debt.
    /// @param assetOutAmount The amount of assets bought.
    /// @param settledDebt The amount of settled credit or debt.
    event LogSettleVaultDebt(
        uint128 indexed vaultId,
        address assetIn,
        uint256 assetInAmount,
        address assetOut,
        uint256 assetOutAmount,
        int256 settledDebt
    );

    /// @notice Emitted when two vaults' assets are rebalanced.
    /// @param inCreditVaultId The vault in net credit to receive a usdc deposit from the in debt vault.
    /// @param inDebtVaultId The vault in net debt to sell its assets for usdc.
    /// @param settlementValueUsd The amount of USDC transferred between vaults settling their credit / debt.
    event LogRebalanceVaultsAssets(
        uint128 indexed inCreditVaultId, uint128 indexed inDebtVaultId, uint256 settlementValueUsd
    );

    /*//////////////////////////////////////////////////////////////////////////
                                   VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the credit capacity of the given market id.
    /// @dev `CreditDelegationBranch::updateMarketCreditDelegations` must be called before calling this function in
    /// order to
    /// retrieve the latest state.
    /// @dev Each engine can implement its own debt accounting schema according to its business logic, thus, this
    /// function will simply return the credit capacity in USD for the given market id.
    /// @dev Invariants:
    /// The Market MUST exist.
    /// @param marketId The engine's market id.
    /// @return creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    function getCreditCapacityForMarketId(uint128 marketId) public view returns (SD59x18) {
        Market.Data storage market = Market.loadExisting(marketId);

        return Market.getCreditCapacityUsd(market.getTotalDelegatedCreditUsd(), market.getTotalDebt());
    }

    /// @notice Returns the adjusted profit of an active position at the given market id, considering the market's ADL
    /// state.
    /// @dev If the market is in its default state, it will simply return the provided profit. Otherwise, it will
    /// adjust based on the configured ADL parameters.
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    /// @param marketId The engine's market id.
    /// @param profitUsd The position's profit in USD.
    /// @return adjustedProfitUsdX18 The adjusted profit in USD Token, according to the market's health.
    function getAdjustedProfitForMarketId(
        uint128 marketId,
        uint256 profitUsd
    )
        public
        view
        returns (UD60x18 adjustedProfitUsdX18)
    {
        // load the market's data storage pointer & cache total debt
        Market.Data storage market = Market.loadLive(marketId);
        SD59x18 marketTotalDebtUsdX18 = market.getTotalDebt();

        // caches the market's delegated credit & credit capacity
        UD60x18 delegatedCreditUsdX18 = market.getTotalDelegatedCreditUsd();
        SD59x18 creditCapacityUsdX18 = Market.getCreditCapacityUsd(delegatedCreditUsdX18, marketTotalDebtUsdX18);

        // if the credit capacity is less than or equal to zero then
        // the total debt has already taken all the delegated credit
        if (creditCapacityUsdX18.lte(SD59x18_ZERO)) {
            revert Errors.InsufficientCreditCapacity(marketId, creditCapacityUsdX18.intoInt256());
        }

        // uint256 -> UD60x18; output default case when market not in Auto Deleverage state
        adjustedProfitUsdX18 = ud60x18(profitUsd);

        // we don't need to add `profitUsd` as it's assumed to be part of the total debt
        // NOTE: If we don't return the adjusted profit in this if branch, we assume marketTotalDebtUsdX18 is positive
        if (market.isAutoDeleverageTriggered(delegatedCreditUsdX18, marketTotalDebtUsdX18)) {
            // if the market's auto deleverage system is triggered, it assumes marketTotalDebtUsdX18 > 0
            adjustedProfitUsdX18 =
                market.getAutoDeleverageFactor(delegatedCreditUsdX18, marketTotalDebtUsdX18).mul(adjustedProfitUsdX18);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                REGISTERED ENGINE ONLY PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Adds credit in form of a registered collateral type to the given market id.
    /// @dev Engines call this function to send collateral collected from their users and increase their credit
    /// capacity, rewarding the market making engine's LPs.
    /// @dev Called by the perps engine to send margin collateral deducted from a trader's account during a negative
    /// pnl settlement or a liquidation event.
    /// @dev The system must enforce that if a market is running by an engine, it must have some delegated credit. In
    /// order to delist a market and allow Vaults to fully undelegate the provided credit, it first must be disabled
    /// at the engine level in order to prevent users from being able to fulfill their expected profits.
    /// @param marketId The engine's market id.
    /// @param collateralAddr The margin collateral address.
    /// @param amount The token amount of collateral to receive in collateralAddr's native precision
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    function depositCreditForMarket(
        uint128 marketId,
        address collateralAddr,
        uint256 amount
    )
        external
        onlyRegisteredEngine(marketId)
    {
        if (amount == 0) revert Errors.ZeroInput("amount");

        // loads the collateral's data storage pointer, must be enabled
        Collateral.Data storage collateral = Collateral.load(collateralAddr);
        collateral.verifyIsEnabled();

        // loads the market's data storage pointer, must have delegated credit so
        // engine is not depositing credit to an empty distribution (with 0 total shares)
        // although this should never happen if the system functions properly.
        Market.Data storage market = Market.loadLive(marketId);
        if (market.getTotalDelegatedCreditUsd().isZero()) {
            revert Errors.NoDelegatedCredit(marketId);
        }

        // uint256 -> UD60x18 scaling decimals to zaros internal precision
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // caches the usdToken address
        address usdToken = MarketMakingEngineConfiguration.load().usdTokenOfEngine[msg.sender];

        // caches the usdc
        address usdc = MarketMakingEngineConfiguration.load().usdc;

        // note: storage updates must occur using zaros internal precision
        if (collateralAddr == usdToken) {
            // if the deposited collateral is USD Token, it reduces the market's realized debt
            market.updateNetUsdTokenIssuance(unary(amountX18.intoSD59x18()));
        } else {
            if (collateralAddr == usdc) {
                market.settleCreditDeposit(address(0), amountX18);
            } else {
                // deposits the received collateral to the market to be distributed to vaults
                // to be settled in the future
                market.depositCredit(collateralAddr, amountX18);
            }
        }

        // transfers the margin collateral asset from the registered engine to the market making engine
        // NOTE: The engine must approve the market making engine to transfer the margin collateral asset, see
        // PerpsEngineConfigurationBranch::setMarketMakingEngineAllowance
        // note: transfers must occur using token native precision
        IERC20(collateralAddr).safeTransferFrom(msg.sender, address(this), amount);

        // emit an event
        emit LogDepositCreditForMarket(msg.sender, marketId, collateralAddr, amount);
    }

    /// @notice Mints the requested amount of USD Token to the caller and updates the market's
    /// debt state.
    /// @dev Called by a registered engine to mint USD Token to profitable traders.
    /// @dev USD Token association with an engine's user happens at the engine contract level.
    /// @dev We assume `amount` is part of the market's reported unrealized debt.
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    /// @param marketId The engine's market id requesting USD Token.
    /// @param amount The amount of USD Token to mint.
    function withdrawUsdTokenFromMarket(uint128 marketId, uint256 amount) external onlyRegisteredEngine(marketId) {
        // loads the market's data and connected vaults
        Market.Data storage market = Market.loadLive(marketId);
        uint256[] memory connectedVaults = market.getConnectedVaultsIds();

        // once the unrealized debt is distributed update credit delegated
        // by these vaults to the market
        Vault.recalculateVaultsCreditCapacity(connectedVaults);

        // cache the market's total debt and delegated credit
        SD59x18 marketTotalDebtUsdX18 = market.getTotalDebt();
        UD60x18 delegatedCreditUsdX18 = market.getTotalDelegatedCreditUsd();

        // calculate the market's credit capacity
        SD59x18 creditCapacityUsdX18 = Market.getCreditCapacityUsd(delegatedCreditUsdX18, marketTotalDebtUsdX18);

        // enforces that the market has enough credit capacity, if it's a listed market it must always have some
        // delegated credit, see Vault.Data.lockedCreditRatio.
        // NOTE: additionally, the ADL system if functioning properly must ensure that the market always has credit
        // capacity to cover USD Token mint requests. Deleverage happens when the perps engine calls
        // CreditDelegationBranch::getAdjustedProfitForMarketId.
        // NOTE: however, it still is possible to fall into a scenario where the credit capacity is <= 0, as the
        // delegated credit may be provided in form of volatile collateral assets, which could go down in value as
        // debt reaches its ceiling. In that case, the market will run out of mintable USD Token and the mm engine
        // must settle all outstanding debt for USDC, in order to keep previously paid USD Token fully backed.
        if (creditCapacityUsdX18.lte(SD59x18_ZERO)) {
            revert Errors.InsufficientCreditCapacity(marketId, creditCapacityUsdX18.intoInt256());
        }

        // uint256 -> UD60x18
        // NOTE: we don't need to scale decimals here as it's known that USD Token has 18 decimals
        UD60x18 amountX18 = ud60x18(amount);

        // prepare the amount of usdToken that will be minted to the perps engine;
        // initialize to default non-ADL state
        uint256 amountToMint = amount;

        // now we realize the added usd debt of the market
        // note: USD Token is assumed to be 1:1 with the system's usd accounting
        if (market.isAutoDeleverageTriggered(delegatedCreditUsdX18, marketTotalDebtUsdX18)) {
            // if the market is in the ADL state, it reduces the requested USD
            // Token amount by multiplying it by the ADL factor, which must be < 1
            UD60x18 adjustedUsdTokenToMintX18 =
                market.getAutoDeleverageFactor(delegatedCreditUsdX18, marketTotalDebtUsdX18).mul(amountX18);

            amountToMint = adjustedUsdTokenToMintX18.intoUint256();
            market.updateNetUsdTokenIssuance(adjustedUsdTokenToMintX18.intoSD59x18());
        } else {
            // if the market is not in the ADL state, it realizes the full requested USD Token amount
            market.updateNetUsdTokenIssuance(amountX18.intoSD59x18());
        }

        // loads the market making engine configuration storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // mint USD Token to the perps engine
        UsdToken usdToken = UsdToken(marketMakingEngineConfiguration.usdTokenOfEngine[msg.sender]);
        usdToken.mint(msg.sender, amountToMint);

        // emit an event
        emit LogWithdrawUsdTokenFromMarket(msg.sender, marketId, amount, amountToMint);
    }

    /*//////////////////////////////////////////////////////////////////////////
                REGISTERED SYSTEM KEEPERS ONLY PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    // get around stack too deep
    struct ConvertMarketsCreditDepositsToUsdcContext {
        uint256 creditDepositsNativeDecimals;
    }

    /// @notice Converts assets deposited as credit to a given market for USDC.
    /// @dev USDC accumulated by swaps is stored at markets, and later pushed to its connected vaults in order to
    /// cover an engine's usd token.
    /// @dev The keeper must ensure that the market has received fees for the given asset before calling this
    /// function.
    /// @dev The keeper doesn't need to settle all deposited assets at once, it can settle them in batches as needed.
    /// @param marketId The market identifier.
    /// @param assets The array of assets deposited as credit to be settled for USDC.
    /// @param dexSwapStrategyIds The identifier of the dex swap strategies to be used.
    /// @param paths Used when the keeper wants to perform a multihop swap using one of the swap strategies.
    function convertMarketsCreditDepositsToUsdc(
        uint128 marketId,
        address[] calldata assets,
        uint128[] calldata dexSwapStrategyIds,
        bytes[] calldata paths
    )
        external
        onlyRegisteredSystemKeepers
    {
        // revert if the arrays have different lengths
        if (assets.length != dexSwapStrategyIds.length || assets.length != paths.length) {
            // we ignore in purpose the error params here
            revert Errors.ArrayLengthMismatch(0, 0);
        }

        // load the market's data storage pointer
        Market.Data storage market = Market.loadExisting(marketId);

        // working area
        ConvertMarketsCreditDepositsToUsdcContext memory ctx;

        for (uint256 i; i < assets.length; i++) {
            // revert if the market hasn't received any fees for the given asset
            (bool exists, uint256 creditDeposits) = market.creditDeposits.tryGet(assets[i]);
            if (!exists) revert Errors.MarketDoesNotContainTheAsset(assets[i]);
            if (creditDeposits == 0) revert Errors.AssetAmountIsZero(assets[i]);

            // cache usdc address
            address usdc = MarketMakingEngineConfiguration.load().usdc;

            // creditDeposits in zaros internal precision so convert to native token decimals
            ctx.creditDepositsNativeDecimals =
                Collateral.load(assets[i]).convertUd60x18ToTokenAmount(ud60x18(creditDeposits));

            // convert the assets to USDC; both input and outputs in native token decimals
            uint256 usdcOut = _convertAssetsToUsdc(
                dexSwapStrategyIds[i], assets[i], ctx.creditDepositsNativeDecimals, paths[i], address(this), usdc
            );

            // sanity check to ensure we didn't somehow give away the input tokens
            if (usdcOut == 0) revert Errors.ZeroOutputTokens();

            // settles the credit deposit for the amount of USDC received
            // updating storage so convert from native token decimals to zaros internal precision
            market.settleCreditDeposit(assets[i], Collateral.load(usdc).convertTokenAmountToUd60x18(usdcOut));

            // emit an event
            emit LogConvertMarketCreditDepositsToUsdc(marketId, assets[i], creditDeposits, usdcOut);
        }
    }

    struct SettleVaultDebtContext {
        SD59x18 vaultUnsettledRealizedDebtUsdX18;
        address vaultAsset;
        address usdc;
        address assetIn;
        uint256 assetInAmount;
        address assetOut;
        uint256 assetOutAmount;
        int256 settledDebt;
        uint256 swapAmount;
        uint256 usdcOut;
        UD60x18 usdcOutX18;
        uint256 usdcIn;
        uint256 vaultUsdcBalance;
    }

    /// @notice Settles the given vaults' debt or credit by swapping assets to USDC or vice versa.
    /// @dev Converts ZLP Vaults unsettled debt to settled debt by:
    ///     - If in debt, swapping the vault's assets to USDC.
    ///     - If in credit, swapping the vault's available USDC to its underlying assets.
    /// exchange for their assets.
    /// @dev USDC acquired from onchain markets is deposited to vaults and used to cover future USD Token swaps, in
    /// case the vault is in debt.
    /// @dev If the vault is in net credit and doesn't own enough USDC to fully settle the due amount, it may have its
    /// assets rebalanced with other vaults through `CreditDelegation::rebalanceVaultsAssets`.
    /// @dev There isn't any issue settling debt of vaults of different engines in the same call, as the system
    /// allocates the USDC acquired in case of a debt settlement to the engine's USD Token accordingly.
    /// @param vaultsIds The vaults' identifiers to settle.
    function settleVaultsDebt(uint256[] calldata vaultsIds) external onlyRegisteredSystemKeepers {
        // first, we need to update the credit capacity of the vaults
        Vault.recalculateVaultsCreditCapacity(vaultsIds);

        // working data, cache usdc address
        SettleVaultDebtContext memory ctx;
        ctx.usdc = MarketMakingEngineConfiguration.load().usdc;

        // load the usdc collateral data storage pointer
        Collateral.Data storage usdcCollateralConfig = Collateral.load(ctx.usdc);

        for (uint256 i; i < vaultsIds.length; i++) {
            // load the vault storage pointer
            Vault.Data storage vault = Vault.loadExisting(vaultsIds[i].toUint128());

            // cache the vault's unsettled debt, if zero skip to next vault
            // amount in zaros internal precision
            ctx.vaultUnsettledRealizedDebtUsdX18 = vault.getUnsettledRealizedDebt();
            if (ctx.vaultUnsettledRealizedDebtUsdX18.isZero()) continue;

            // otherwise vault has debt to be settled, cache the vault's collateral asset
            ctx.vaultAsset = vault.collateral.asset;

            // loads the dex swap strategy data storage pointer
            DexSwapStrategy.Data storage dexSwapStrategy =
                DexSwapStrategy.loadExisting(vault.swapStrategy.assetDexSwapStrategyId);

            // if the vault is in debt, swap its assets to USDC
            if (ctx.vaultUnsettledRealizedDebtUsdX18.lt(SD59x18_ZERO)) {
                // get swap amount; both input and output in native precision
                ctx.swapAmount = calculateSwapAmount(
                    dexSwapStrategy.dexAdapter,
                    ctx.usdc,
                    ctx.vaultAsset,
                    usdcCollateralConfig.convertSd59x18ToTokenAmount(ctx.vaultUnsettledRealizedDebtUsdX18.abs())
                );

                // swap the vault's assets to usdc in order to cover the usd denominated debt partially or fully
                // both input and output in native precision
                ctx.usdcOut = _convertAssetsToUsdc(
                    vault.swapStrategy.usdcDexSwapStrategyId,
                    ctx.vaultAsset,
                    ctx.swapAmount,
                    vault.swapStrategy.usdcDexSwapPath,
                    address(this),
                    ctx.usdc
                );

                // sanity check to ensure we didn't somehow give away the input tokens
                if (ctx.usdcOut == 0) revert Errors.ZeroOutputTokens();

                // uint256 -> udc60x18 scaling native precision to zaros internal precision
                ctx.usdcOutX18 = usdcCollateralConfig.convertTokenAmountToUd60x18(ctx.usdcOut);

                // use the amount of usdc bought with assets to update the vault's state
                // note: storage updates must be done using zaros internal precision
                //
                // deduct the amount of usdc swapped for assets from the vault's unsettled debt
                vault.marketsRealizedDebtUsd -= ctx.usdcOutX18.intoUint256().toInt256().toInt128();

                // allocate the usdc acquired to back the engine's usd token
                UsdTokenSwapConfig.load().usdcAvailableForEngine[vault.engine] += ctx.usdcOutX18.intoUint256();

                // update the variables to be logged
                ctx.assetIn = ctx.vaultAsset;
                ctx.assetInAmount = ctx.swapAmount;
                ctx.assetOut = ctx.usdc;
                ctx.assetOutAmount = ctx.usdcOut;
                // since we're handling debt, we provide a positive value
                ctx.settledDebt = ctx.usdcOut.toInt256();
            } else {
                // else vault is in credit, swap its USDC previously accumulated
                // from market and vault deposits into its underlying asset

                // get swap amount; both input and output in native precision
                ctx.usdcIn = calculateSwapAmount(
                    dexSwapStrategy.dexAdapter,
                    ctx.vaultAsset,
                    ctx.usdc,
                    usdcCollateralConfig.convertSd59x18ToTokenAmount(ctx.vaultUnsettledRealizedDebtUsdX18.abs())
                );

                // get deposited USDC balance of the vault, convert to native precision
                ctx.vaultUsdcBalance = usdcCollateralConfig.convertUd60x18ToTokenAmount(ud60x18(vault.depositedUsdc));

                // if the vault doesn't have enough usdc use whatever amount it has
                // make sure we compare native precision values together and output native precision
                ctx.usdcIn = (ctx.usdcIn <= ctx.vaultUsdcBalance) ? ctx.usdcIn : ctx.vaultUsdcBalance;

                // swaps the vault's usdc balance to more vault assets and
                // send them to the ZLP Vault contract (index token address)
                // both input and output in native precision
                ctx.assetOutAmount = _convertUsdcToAssets(
                    vault.swapStrategy.assetDexSwapStrategyId,
                    ctx.vaultAsset,
                    ctx.usdcIn,
                    vault.swapStrategy.assetDexSwapPath,
                    vault.indexToken,
                    ctx.usdc
                );

                // sanity check to ensure we didn't somehow give away the input tokens
                if (ctx.assetOutAmount == 0) revert Errors.ZeroOutputTokens();

                // subtract the usdc amount used to buy vault assets from the vault's deposited usdc, thus, settling
                // the due credit amount (partially or fully).
                // note: storage updates must be done using zaros internal precision
                vault.depositedUsdc -= usdcCollateralConfig.convertTokenAmountToUd60x18(ctx.usdcIn).intoUint128();

                // update the variables to be logged
                ctx.assetIn = ctx.usdc;
                ctx.assetInAmount = ctx.usdcIn;
                ctx.assetOut = ctx.vaultAsset;
                // since we're handling credit, we provide a negative value
                ctx.settledDebt = -ctx.usdcIn.toInt256();
            }

            // emit an event per vault settled
            emit LogSettleVaultDebt(
                vaultsIds[i].toUint128(),
                ctx.assetIn,
                ctx.assetInAmount,
                ctx.assetOut,
                ctx.assetOutAmount,
                ctx.settledDebt
            );
        }
    }

    /// vault asset -> usdc
    /// @notice Calculates the amount of a specific vault asset needed to cover negative unsettled debt in USD.
    /// usdc -> vault asset
    /// @notice Calculates the amount of usdc needed to cover positive unsettled debt in USD.
    /// @param dexAdapter The address of the DEX adapter used for price calculation.
    /// @param assetIn The address of the vault asset to calculate the amount for.
    /// @param assetOut The address of the USDC token.
    /// @param vaultUnsettledDebtUsdAbs The unsettled debt in USD in native token precision
    /// @return amount The amount of the vault asset required to cover the unsettled debt in USD
    ///         using native precision of output token
    function calculateSwapAmount(
        address dexAdapter,
        address assetIn,
        address assetOut,
        uint256 vaultUnsettledDebtUsdAbs
    )
        public
        view
        returns (uint256 amount)
    {
        // calculate expected asset amount needed to cover the debt
        amount = IDexAdapter(dexAdapter).getExpectedOutput(assetIn, assetOut, vaultUnsettledDebtUsdAbs);
    }

    // used as a cache to prevent duplicate storage reads while avoiding "stack too deep" errors
    struct CalculateSwapContext {
        address inDebtVaultCollateralAsset;
        address dexAdapter;
    }

    /// @notice Rebalances credit and debt between two vaults.
    /// @dev There are multiple factors that may result on vaults backing the same engine having a completely
    /// different credit or debt state, such as:
    ///  - connecting vaults with markets in different times
    ///  - connecting vaults with different sets of markets
    ///  - users swapping the engine's usd token for assets of different vaults
    /// This way, from time to time, the system keepers must rebalance vaults with a significant state difference in
    /// order to facilitate settlement of their credit and debt. A rebalancing doesn't need to always fully settle the
    /// amount of USDC that a vault in credit requires to settle its due amount, so the system is optimized to ensure
    /// a financial stability of the protocol.
    /// @dev Example:
    ///  in credit vault markets realized debt = -100 -> -90
    ///  in credit vault deposited usdc = 200 -> 210
    ///  in credit vault unsettled realized debt = -300 | as -100 + -200 -> after settlement -> -300 | as -90 + -210
    ///  = -300

    ///  thus, we need to rebalance as the in credit vault doesn't own enough usdc to settle its due credit

    ///  in debt vault markets realized debt = 50 -> 40
    ///  in debt vault deposited usdc = 10 -> 0
    ///  in debt vault unsettled realized debt = 40 | as 50 + -10  -> after settlement -> 40 | as 40 + 0 = 40
    /// @dev The first vault id passed is assumed to be the in credit vault, and the second vault id is assumed to be
    /// the in debt vault.
    /// @dev The final unsettled realized debt of both vaults MUST remain the same after the rebalance.
    /// @dev The actual increase or decrease in the vaults' unsettled realized debt happen at `settleVaultsDebt`.
    /// @param vaultsIds The vaults' identifiers to rebalance.
    function rebalanceVaultsAssets(uint128[2] calldata vaultsIds) external onlyRegisteredSystemKeepers {
        // load the storage pointers of the vaults in net credit and net debt
        Vault.Data storage inCreditVault = Vault.loadExisting(vaultsIds[0]);
        Vault.Data storage inDebtVault = Vault.loadExisting(vaultsIds[1]);

        // both vaults must belong to the same engine in order to have their debt
        // state rebalanced, as each usd token's debt is isolated
        if (inCreditVault.engine != inDebtVault.engine) {
            revert Errors.VaultsConnectedToDifferentEngines();
        }

        // create an in-memory dynamic array in order to call `Vault::recalculateVaultsCreditCapacity`
        uint256[] memory vaultsIdsForRecalculation = new uint256[](2);
        vaultsIdsForRecalculation[0] = vaultsIds[0];
        vaultsIdsForRecalculation[1] = vaultsIds[1];

        // recalculate the credit capacity of both vaults
        Vault.recalculateVaultsCreditCapacity(vaultsIdsForRecalculation);

        // cache the in debt vault & in credit vault unsettled debt
        SD59x18 inDebtVaultUnsettledRealizedDebtUsdX18 = inDebtVault.getUnsettledRealizedDebt();
        SD59x18 inCreditVaultUnsettledRealizedDebtUsdX18 = inCreditVault.getUnsettledRealizedDebt();

        // revert if 1) the vault that is supposed to be in credit is not OR
        //           2) the vault that is supposed to be in debt is not
        if (
            inCreditVaultUnsettledRealizedDebtUsdX18.lte(SD59x18_ZERO)
                || inDebtVaultUnsettledRealizedDebtUsdX18.gte(SD59x18_ZERO)
        ) {
            revert Errors.InvalidVaultDebtSettlementRequest();
        }

        // get debt absolute value
        SD59x18 inDebtVaultUnsettledRealizedDebtUsdX18Abs = inDebtVaultUnsettledRealizedDebtUsdX18.abs();

        // if debt absolute value > credit, use credit value, else use debt value
        SD59x18 depositAmountUsdX18 = inCreditVaultUnsettledRealizedDebtUsdX18.gt(
            inDebtVaultUnsettledRealizedDebtUsdX18Abs
        ) ? inDebtVaultUnsettledRealizedDebtUsdX18Abs : inCreditVaultUnsettledRealizedDebtUsdX18;

        // loads the dex swap strategy data storage pointer
        DexSwapStrategy.Data storage dexSwapStrategy =
            DexSwapStrategy.loadExisting(inDebtVault.swapStrategy.usdcDexSwapStrategyId);

        // load usdc address
        address usdc = MarketMakingEngineConfiguration.load().usdc;

        // cache input asset and dex adapter
        CalculateSwapContext memory ctx;
        ctx.inDebtVaultCollateralAsset = inDebtVault.collateral.asset;
        ctx.dexAdapter = dexSwapStrategy.dexAdapter;

        // get collateral asset amount in native precision of ctx.inDebtVaultCollateralAsset
        uint256 assetInputNative = IDexAdapter(ctx.dexAdapter).getExpectedOutput(
            usdc,
            ctx.inDebtVaultCollateralAsset,
            // convert usdc input to native precision
            Collateral.load(usdc).convertSd59x18ToTokenAmount(depositAmountUsdX18)
        );

        // prepare the data for executing the swap asset -> usdc
        SwapExactInputSinglePayload memory swapCallData = SwapExactInputSinglePayload({
            tokenIn: ctx.inDebtVaultCollateralAsset,
            tokenOut: usdc,
            amountIn: assetInputNative,
            recipient: address(this) // deposit the usdc to the market making engine proxy
         });

        // approve the collateral token to the dex adapter and swap assets for USDC
        IERC20(ctx.inDebtVaultCollateralAsset).approve(ctx.dexAdapter, assetInputNative);
        dexSwapStrategy.executeSwapExactInputSingle(swapCallData);

        // SD59x18 -> uint128 using zaros internal precision
        uint128 usdDelta = depositAmountUsdX18.intoUint256().toUint128();

        // important considerations:
        // 1) all subsequent storge updates must use zaros internal precision
        // 2) code implicitly assumes that 1 USD = 1 USDC
        //
        // deposits the USDC to the in-credit vault
        inCreditVault.depositedUsdc += usdDelta;
        // increase the in-credit vault's share of the markets realized debt
        // as it has received the USDC and needs to settle it in the future
        inCreditVault.marketsRealizedDebtUsd += usdDelta.toInt256().toInt128();

        // withdraws the USDC from the in-debt vault
        inDebtVault.depositedUsdc -= usdDelta;
        // decrease the in-debt vault's share of the markets realized debt
        // as it has transferred USDC to the in-credit vault
        inDebtVault.marketsRealizedDebtUsd -= usdDelta.toInt256().toInt128();

        // emit an event
        emit LogRebalanceVaultsAssets(vaultsIds[0], vaultsIds[1], usdDelta);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   UNPROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Updates the credit delegations from ZLP Vaults to the given market id.
    /// @dev Must be called whenever an engine needs to know the current credit capacity of a given market id.
    function updateMarketCreditDelegations(uint128 marketId) public {
        Vault.recalculateVaultsCreditCapacity(Market.loadLive(marketId).getConnectedVaultsIds());
    }

    /// @notice Called by a registered to update a market's credit delegations and return its credit capacity.
    /// @param marketId The engine's market id.
    /// @return creditCapacity creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    function updateMarketCreditDelegationsAndReturnCapacity(uint128 marketId)
        external
        returns (SD59x18 creditCapacity)
    {
        updateMarketCreditDelegations(marketId);
        creditCapacity = getCreditCapacityForMarketId(marketId);
    }

    /// @notice Updates the credit capacity of the given vault id, recalculating its connected markets' debt and its
    /// collateral assets USD value.
    /// @param vaultId The vault identifier.
    function updateVaultCreditCapacity(uint128 vaultId) external {
        // prepare the `Vault::recalculateVaultsCreditCapacity` call
        uint256[] memory vaultsIds = new uint256[](1);
        vaultsIds[0] = uint256(vaultId);

        // updates the vault's credit capacity
        Vault.recalculateVaultsCreditCapacity(vaultsIds);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @param assetAmount in native precision of asset token
    /// @return usdcOut in native usdc precision
    function _convertAssetsToUsdc(
        uint128 dexSwapStrategyId,
        address asset,
        uint256 assetAmount,
        bytes memory path,
        address recipient,
        address usdc
    )
        internal
        returns (uint256 usdcOut)
    {
        // revert if the amount is zero
        if (assetAmount == 0) revert Errors.AssetAmountIsZero(asset);

        // if the asset being handled is usdc, simply output it to `usdcOut`
        if (asset == usdc) {
            usdcOut = assetAmount;
        } else {
            // approve the asset to be spent by the dex adapter contract
            DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.loadExisting(dexSwapStrategyId);
            IERC20(asset).approve(dexSwapStrategy.dexAdapter, assetAmount);

            // verify if the swap should be input single or multihop
            if (path.length == 0) {
                // prepare the data for executing the swap
                SwapExactInputSinglePayload memory swapCallData = SwapExactInputSinglePayload({
                    tokenIn: asset,
                    tokenOut: usdc,
                    amountIn: assetAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                usdcOut = dexSwapStrategy.executeSwapExactInputSingle(swapCallData);
            } else {
                // prepare the data for executing the swap
                SwapExactInputPayload memory swapCallData = SwapExactInputPayload({
                    path: path,
                    tokenIn: asset,
                    tokenOut: usdc,
                    amountIn: assetAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                usdcOut = dexSwapStrategy.executeSwapExactInput(swapCallData);
            }

            // load market making config
            MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
                MarketMakingEngineConfiguration.load();

            // cache the settlement base fee value using usdc's native decimals
            uint256 settlementBaseFeeUsd = Collateral.load(usdc).convertUd60x18ToTokenAmount(
                ud60x18(marketMakingEngineConfiguration.settlementBaseFeeUsdX18)
            );

            if (settlementBaseFeeUsd > 0) {
                // revert if there isn't enough usdc to cover the base fee
                // NOTE: keepers must be configured to buy good chunks of usdc at minimum (e.g $500)
                // as the settlement base fee shouldn't be much greater than $1.
                if (usdcOut < settlementBaseFeeUsd) {
                    revert Errors.FailedToPaySettlementBaseFee();
                }

                usdcOut -= settlementBaseFeeUsd;

                // distribute the base fee to protocol fee recipients
                marketMakingEngineConfiguration.distributeProtocolAssetReward(usdc, settlementBaseFeeUsd);
            }
        }
    }

    /// @param usdcAmount native precision
    function _convertUsdcToAssets(
        uint128 dexSwapStrategyId,
        address asset,
        uint256 usdcAmount,
        bytes memory path,
        address recipient,
        address usdc
    )
        internal
        returns (uint256 assetOut)
    {
        // revert if the amount is zero
        if (usdcAmount == 0) revert Errors.AssetAmountIsZero(usdc);

        // if the asset being handled is usdc, output it to `usdcOut`
        if (asset == usdc) {
            assetOut = usdcAmount;
        } else {
            // load the market making engine configuration storage pointer
            MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
                MarketMakingEngineConfiguration.load();

            // cache the settlement base fee value using usdc's native decimals
            uint256 settlementBaseFeeUsd = Collateral.load(usdc).convertUd60x18ToTokenAmount(
                ud60x18(marketMakingEngineConfiguration.settlementBaseFeeUsdX18)
            );

            if (settlementBaseFeeUsd > 0) {
                // revert if there isn't enough usdc to convert the base fee
                // NOTE: keepers must be configured to buy good chunks of usdc at minimum (e.g $500)
                // as the settlement base fee shouldn't be much greater than $1.
                if (usdcAmount < settlementBaseFeeUsd) {
                    revert Errors.FailedToPaySettlementBaseFee();
                }

                // subtract fee from usdc input
                usdcAmount -= settlementBaseFeeUsd;

                // distribute the base fee to protocol fee recipients
                marketMakingEngineConfiguration.distributeProtocolAssetReward(usdc, settlementBaseFeeUsd);
            }

            // loads the dex swap strategy data storage pointer
            DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.loadExisting(dexSwapStrategyId);

            // approve the asset to be spent by the dex adapter contract
            IERC20(usdc).approve(dexSwapStrategy.dexAdapter, usdcAmount);

            // verify if the swap should be input single or multihop
            if (path.length == 0) {
                // prepare the data for executing the swap
                SwapExactInputSinglePayload memory swapCallData = SwapExactInputSinglePayload({
                    tokenIn: usdc,
                    tokenOut: asset,
                    amountIn: usdcAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                assetOut = dexSwapStrategy.executeSwapExactInputSingle(swapCallData);
            } else {
                // prepare the data for executing the swap
                SwapExactInputPayload memory swapCallData = SwapExactInputPayload({
                    path: path,
                    tokenIn: usdc,
                    tokenOut: asset,
                    amountIn: usdcAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                assetOut = dexSwapStrategy.executeSwapExactInput(swapCallData);
            }
        }
    }
}
