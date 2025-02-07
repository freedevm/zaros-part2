// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { UsdToken } from "@zaros/usd/UsdToken.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";
import { StabilityConfiguration } from "@zaros/market-making/leaves/StabilityConfiguration.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, convert as ud60x18Convert } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract StabilityBranch is EngineAccessControl {
    using Collateral for Collateral.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for uint120;
    using StabilityConfiguration for StabilityConfiguration.Data;
    using UsdTokenSwapConfig for UsdTokenSwapConfig.Data;
    using Vault for Vault.Data;

    /// @notice Emitted to trigger the Chainlink Log based upkeep
    event LogInitiateSwap(
        address indexed caller,
        uint128 indexed requestId,
        uint128 vaultId,
        uint128 amountIn,
        uint128 minAmountOut,
        address assetOut,
        uint120 deadline
    );

    /// @notice Emitted when a swap is not fulfilled by the keeper and assets are refunded
    event LogRefundSwap(
        address indexed user,
        uint128 indexed requestId,
        uint128 vaultId,
        uint128 amountIn,
        uint128 minAmountOut,
        address assetOut,
        uint120 deadline,
        uint256 baseFeeUsd,
        uint256 refundAmount
    );

    /// @notice Emitted when a swap is fulfilled by the keeper
    event LogFulfillSwap(
        address indexed user,
        uint128 indexed requestId,
        uint128 vaultId,
        uint128 amountIn,
        uint128 minAmountOut,
        address assetOut,
        uint120 deadline,
        uint256 amountOut,
        uint256 baseFee,
        uint256 swapFee,
        uint256 protocolReward
    );

    /// @notice Retrieves a specific USD token swap request for a given user and request ID.
    /// @param caller The address of the user who initiated the swap request.
    /// @param requestId The unique ID of the swap request being retrieved.
    /// @return request The `SwapRequest` structure containing the details of the swap request.
    function getSwapRequest(
        address caller,
        uint128 requestId
    )
        external
        view
        returns (UsdTokenSwapConfig.SwapRequest memory request)
    {
        request = UsdTokenSwapConfig.load().swapRequests[caller][requestId];
    }

    /// @notice Calculates the amount of assets to be received in a swap based on the input USD amount, its current
    /// price and the premium or discount to be applied.
    /// @dev This function assumes that checks for the vault's liveness or existence state are performed in the parent
    /// context if needed.
    /// @param usdAmountInX18 The amount of USD tokens to be swapped in zaros internal precision
    /// @param indexPriceX18 The price of the collateral asset in zaros internal precision
    /// @return amountOutX18 The amount of assets to be received using in the ERC20's decimals, calculated from the
    /// input USD amount and its price.
    function getAmountOfAssetOut(
        uint128 vaultId,
        UD60x18 usdAmountInX18,
        UD60x18 indexPriceX18
    )
        public
        view
        returns (UD60x18 amountOutX18)
    {
        // fetch the vault's storage pointer
        Vault.Data storage vault = Vault.load(vaultId);

        // fetch the vault's total assets in USD; if the vault is empty
        // revert here to prevent panic from subsequent divide by zero
        UD60x18 vaultAssetsUsdX18 = ud60x18(IERC4626(vault.indexToken).totalAssets()).mul(indexPriceX18);
        if (vaultAssetsUsdX18.isZero()) revert Errors.InsufficientVaultBalance(vaultId, 0, 0);

        // we use the vault's net sum of all debt types coming from its connected markets to determine the swap rate
        SD59x18 vaultDebtUsdX18 = vault.getTotalDebt();

        // calculate the premium or discount that may be applied to the vault asset's index price
        // note: if no premium or discount needs to be applied, the premiumDiscountFactorX18 will be
        // 1e18 (UD60x18 one value)
        UD60x18 premiumDiscountFactorX18 =
            UsdTokenSwapConfig.load().getPremiumDiscountFactor(vaultAssetsUsdX18, vaultDebtUsdX18);

        // get amounts out taking into consideration the CL price and the premium/discount
        amountOutX18 = usdAmountInX18.div(indexPriceX18).mul(premiumDiscountFactorX18);
    }

    /// @notice Returns the applicable fees for the specified amount of assets being paid in a swap.
    /// @param assetsAmountOutX18 The desired amount of assets to be acquired.
    /// @param priceX18 The current price of the asset in UD60x18 format.
    /// @return baseFeeX18 The base swap fee in assets units in UD60x18 format.
    /// @return swapFeeX18 The dynamic swap fee in assets units in UD60x18 format.
    function getFeesForAssetsAmountOut(
        UD60x18 assetsAmountOutX18,
        UD60x18 priceX18
    )
        public
        view
        returns (UD60x18 baseFeeX18, UD60x18 swapFeeX18)
    {
        // load swap data
        UsdTokenSwapConfig.Data storage tokenSwapData = UsdTokenSwapConfig.load();

        // convert the base fee in usd to the asset amount to be charged
        baseFeeX18 = ud60x18(tokenSwapData.baseFeeUsd).div(priceX18);

        // calculates the swap fee portion rounding up
        swapFeeX18 = Math.divUp(
            assetsAmountOutX18.mul(ud60x18(tokenSwapData.swapSettlementFeeBps)),
            ud60x18Convert(Constants.BPS_DENOMINATOR)
        );
    }

    /// @notice Applies the swap fee to the USD token amount in the context of a refund.
    /// @dev The base and swap fees are only applied to the usd token amount in when the user requests a refund,
    /// otherwise, fees will be collected from the assets being paid out.
    /// @dev Zaros USD tokens must always implement 18 decimals by default, otherwise assumptions would break.
    /// @param usdAmountInX18 The original amount of USD tokens to be swapped, before the fee is deducted, in UD60x18.
    /// @return baseFeeUsdX18 The base fee charged from the usd token amount in UD60x18.
    /// @return swapFeeUsdX18 The dynamic swap fee charged from the usd token amount in UD60x18.
    function getFeesForUsdTokenAmountIn(UD60x18 usdAmountInX18)
        public
        view
        returns (UD60x18 baseFeeUsdX18, UD60x18 swapFeeUsdX18)
    {
        // load swap data
        UsdTokenSwapConfig.Data storage tokenSwapData = UsdTokenSwapConfig.load();

        // returns the base fee in UD60x18
        baseFeeUsdX18 = ud60x18(tokenSwapData.baseFeeUsd);
        // calculates and returns the swap fee in UD60x18
        swapFeeUsdX18 = Math.divUp(
            usdAmountInX18.mul(ud60x18(tokenSwapData.swapSettlementFeeBps)), ud60x18Convert(Constants.BPS_DENOMINATOR)
        );
    }

    struct InitiateSwapContext {
        address initialVaultIndexToken;
        address initialVaultCollateralAsset;
        uint128 requestId;
        uint120 deadlineCache;
        uint120 maxExecTime;
        uint256 vaultAssetBalance;
        uint256 expectedAssetOut;
        UD60x18 collateralPriceX18;
        IERC20 usdTokenOfEngine;
    }

    /// @notice Initiates multiple (or one) USD token swap requests for the specified vaults and amounts.
    /// @param vaultIds An array of vault IDs from which to take assets.
    /// @param amountsIn An array of USD token amounts to be swapped from the user in zaros internal precision
    /// @param minAmountsOut An array of minimum acceptable amounts of collateral the user expects to receive for each
    /// swap.
    /// @dev Swap is fulfilled by a registered keeper.
    /// @dev Invariants involved in the call:
    /// The arrays lengths MUST match
    /// The vaults MUST be of the same asset
    function initiateSwap(
        uint128[] calldata vaultIds,
        uint128[] calldata amountsIn,
        uint128[] calldata minAmountsOut
    )
        external
    {
        // Perform length checks
        if (vaultIds.length != amountsIn.length) {
            revert Errors.ArrayLengthMismatch(vaultIds.length, amountsIn.length);
        }

        if (amountsIn.length != minAmountsOut.length) {
            revert Errors.ArrayLengthMismatch(amountsIn.length, minAmountsOut.length);
        }

        // working data
        InitiateSwapContext memory ctx;

        // cache the vault's index token and asset addresses
        Vault.Data storage currentVault = Vault.load(vaultIds[0]);
        ctx.initialVaultIndexToken = currentVault.indexToken;
        ctx.initialVaultCollateralAsset = currentVault.collateral.asset;

        // load collateral data; must be enabled
        Collateral.Data storage collateral = Collateral.load(ctx.initialVaultCollateralAsset);
        collateral.verifyIsEnabled();

        // load market making engine config
        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();

        // load usd token swap data
        UsdTokenSwapConfig.Data storage tokenSwapData = UsdTokenSwapConfig.load();

        // cache additional common fields
        // ctx.collateralPriceX18 in zaros internal precision
        ctx.collateralPriceX18 = currentVault.collateral.getPrice();
        ctx.maxExecTime = uint120(tokenSwapData.maxExecutionTime);
        // ctx.vaultAssetBalance in native precision of ctx.initialVaultCollateralAsset
        ctx.vaultAssetBalance = IERC20(ctx.initialVaultCollateralAsset).balanceOf(ctx.initialVaultIndexToken);

        for (uint256 i; i < amountsIn.length; i++) {
            // for all but first iteration, refresh the vault and enforce same collateral asset
            if (i != 0) {
                currentVault = Vault.load(vaultIds[i]);

                // revert for swaps using vaults with different collateral assets
                if (currentVault.collateral.asset != ctx.initialVaultCollateralAsset) {
                    revert Errors.VaultsCollateralAssetsMismatch();
                }

                // refresh current vault balance in native precision of ctx.initialVaultCollateralAsset
                ctx.vaultAssetBalance = IERC20(ctx.initialVaultCollateralAsset).balanceOf(currentVault.indexToken);
            }

            // cache the expected amount of assets acquired with the provided parameters
            // amountsIn[i] and ctx.collateralPriceX18 using zaros internal precision
            ctx.expectedAssetOut =
                getAmountOfAssetOut(vaultIds[i], ud60x18(amountsIn[i]), ctx.collateralPriceX18).intoUint256();

            // revert if the slippage wouldn't pass or the expected output was 0
            if (ctx.expectedAssetOut == 0) revert Errors.ZeroOutputTokens();
            if (ctx.expectedAssetOut < minAmountsOut[i]) {
                revert Errors.SlippageCheckFailed(minAmountsOut[i], ctx.expectedAssetOut);
            }

            // if there aren't enough assets in the vault to fulfill the swap request, we must revert
            if (ctx.vaultAssetBalance < ctx.expectedAssetOut) {
                revert Errors.InsufficientVaultBalance(vaultIds[i], ctx.vaultAssetBalance, ctx.expectedAssetOut);
            }

            // transfer USD: user => address(this) - burned in fulfillSwap
            ctx.usdTokenOfEngine = IERC20(configuration.usdTokenOfEngine[currentVault.engine]);
            ctx.usdTokenOfEngine.safeTransferFrom(msg.sender, address(this), amountsIn[i]);

            // get next request id for user
            ctx.requestId = tokenSwapData.nextId(msg.sender);

            // load swap request
            UsdTokenSwapConfig.SwapRequest storage swapRequest = tokenSwapData.swapRequests[msg.sender][ctx.requestId];

            // Set swap request parameters
            swapRequest.minAmountOut = minAmountsOut[i];
            swapRequest.vaultId = vaultIds[i];
            swapRequest.assetOut = ctx.initialVaultCollateralAsset;
            ctx.deadlineCache = uint120(block.timestamp) + ctx.maxExecTime;
            swapRequest.deadline = ctx.deadlineCache;
            swapRequest.amountIn = amountsIn[i];

            emit LogInitiateSwap(
                msg.sender,
                ctx.requestId,
                vaultIds[i],
                amountsIn[i],
                minAmountsOut[i],
                ctx.initialVaultCollateralAsset,
                ctx.deadlineCache
            );
        }
    }

    struct FulfillSwapContext {
        UsdToken usdToken;
        UD60x18 baseFeeX18;
        UD60x18 swapFeeX18;
        address asset;
        UD60x18 priceX18;
        uint120 deadline;
        uint128 vaultId;
        uint128 amountIn;
        uint128 minAmountOut;
        uint256 amountOut;
        UD60x18 amountOutBeforeFeesX18;
        UD60x18 protocolSwapFeeX18;
        uint256 protocolReward;
    }

    /// @notice Fulfills a USD token swap request by converting the specified amount of USD tokens to a collateral
    /// asset.
    /// @param user The address of the user who initiated the swap request.
    /// @param requestId The unique ID of the swap request made by the user.
    /// @param priceData The off-chain price data provided by Chainlink, encoded in calldata.
    /// @dev Called by data streams powered keeper.
    /// @dev Invariants involved in the call:
    /// The swap request MUST NOT have been processed
    /// MUST apply fees when swap is fulfilled
    /// The number of received assets MUST be greater than or equal to min assets.
    /// MUST only be callable by a registered keeper
    function fulfillSwap(
        address user,
        uint128 requestId,
        bytes calldata priceData,
        address engine
    )
        external
        onlyRegisteredSystemKeepers
    {
        // load request for user by id
        UsdTokenSwapConfig.SwapRequest storage request = UsdTokenSwapConfig.load().swapRequests[user][requestId];

        // revert if already processed
        if (request.processed) {
            revert Errors.RequestAlreadyProcessed(user, requestId);
        }

        // working data
        FulfillSwapContext memory ctx;

        // if request dealine expired revert
        ctx.deadline = request.deadline;
        if (ctx.deadline < block.timestamp) {
            revert Errors.SwapRequestExpired(user, requestId, ctx.deadline);
        }

        // set request processed to true
        request.processed = true;

        // load market making engine config
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // load vault data
        ctx.vaultId = request.vaultId;
        Vault.Data storage vault = Vault.loadLive(ctx.vaultId);

        // get usd token of engine
        ctx.usdToken = UsdToken(marketMakingEngineConfiguration.usdTokenOfEngine[engine]);

        // load Stability configuration data
        StabilityConfiguration.Data storage stabilityConfiguration = StabilityConfiguration.load();

        // get price from report in 18 dec
        ctx.priceX18 = stabilityConfiguration.verifyOffchainPrice(priceData);

        // get amount out asset
        ctx.amountIn = request.amountIn;
        ctx.amountOutBeforeFeesX18 = getAmountOfAssetOut(ctx.vaultId, ud60x18(ctx.amountIn), ctx.priceX18);

        // gets the base fee and swap fee for the given amount out before fees
        (ctx.baseFeeX18, ctx.swapFeeX18) = getFeesForAssetsAmountOut(ctx.amountOutBeforeFeesX18, ctx.priceX18);

        // cache the collateral asset address
        ctx.asset = vault.collateral.asset;

        // load the collateral configuration storage pointer
        Collateral.Data storage collateral = Collateral.load(ctx.asset);

        // subtract the fees and convert the UD60x18 value to the collateral's decimals value
        ctx.amountOut =
            collateral.convertUd60x18ToTokenAmount(ctx.amountOutBeforeFeesX18.sub(ctx.baseFeeX18.add(ctx.swapFeeX18)));

        // slippage check
        ctx.minAmountOut = request.minAmountOut;
        if (ctx.amountOut < ctx.minAmountOut) {
            revert Errors.SlippageCheckFailed(ctx.minAmountOut, ctx.amountOut);
        }

        // calculates the protocol's share of the swap fee by multiplying the total swap fee by the protocol's fee
        // recipients' share.
        ctx.protocolSwapFeeX18 = ctx.swapFeeX18.mul(ud60x18(marketMakingEngineConfiguration.totalFeeRecipientsShares));
        // the protocol reward amount is the sum of the base fee and the protocol's share of the swap fee
        ctx.protocolReward = collateral.convertUd60x18ToTokenAmount(ctx.baseFeeX18.add(ctx.protocolSwapFeeX18));

        // update vault debt
        vault.marketsRealizedDebtUsd -= int128(ctx.amountIn);

        // burn usd amount from address(this)
        ctx.usdToken.burn(ctx.amountIn);

        // transfer the required assets from the vault to the mm engine contract before distributions
        // note: as the swap fee stays in the ZLP Vault, it is technically a net gain to share holders, i.e it is auto
        // accumulated to the contract
        IERC20(ctx.asset).safeTransferFrom(vault.indexToken, address(this), ctx.amountOut + ctx.protocolReward);

        // distribute protocol reward value
        marketMakingEngineConfiguration.distributeProtocolAssetReward(ctx.asset, ctx.protocolReward);

        // transfers the remaining amount out to the user, discounting fees
        // note: the vault's share of the swap fee remains in the index token contract, thus, we don't need transfer
        // it anywhere. The end result is that vaults have an amount of their debt paid off with a discount.
        IERC20(ctx.asset).safeTransfer(user, ctx.amountOut);

        emit LogFulfillSwap(
            user,
            requestId,
            ctx.vaultId,
            ctx.amountIn,
            ctx.minAmountOut,
            request.assetOut,
            ctx.deadline,
            ctx.amountOut,
            ctx.baseFeeX18.intoUint256(),
            ctx.swapFeeX18.intoUint256(),
            ctx.protocolReward
        );
    }

    /// @notice Refunds a swap request that has not been processed and has expired.
    /// @param requestId The unique ID of the swap request to be refunded.
    function refundSwap(uint128 requestId, address engine) external {
        // load swap data
        UsdTokenSwapConfig.Data storage tokenSwapData = UsdTokenSwapConfig.load();

        // load swap request
        UsdTokenSwapConfig.SwapRequest storage request = tokenSwapData.swapRequests[msg.sender][requestId];

        // if request already procesed revert
        if (request.processed) {
            revert Errors.RequestAlreadyProcessed(msg.sender, requestId);
        }

        // if dealine has not yet passed revert
        uint120 deadlineCache = request.deadline;
        if (deadlineCache > block.timestamp) {
            revert Errors.RequestNotExpired(msg.sender, requestId);
        }

        // set precessed to true
        request.processed = true;

        // load Market making engine config
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // get usd token for engine
        address usdToken = marketMakingEngineConfiguration.usdTokenOfEngine[engine];

        // cache the usd token swap base fee
        uint256 baseFeeUsd = tokenSwapData.baseFeeUsd;

        // cache the amount of usd token previously deposited
        uint128 depositedUsdToken = request.amountIn;

        // transfer base fee too protocol fee recipients
        marketMakingEngineConfiguration.distributeProtocolAssetReward(usdToken, baseFeeUsd);

        // cache the amount of usd tokens to be refunded
        uint256 refundAmountUsd = depositedUsdToken - baseFeeUsd;

        // transfer usd refund amount back to user
        IERC20(usdToken).safeTransfer(msg.sender, refundAmountUsd);

        emit LogRefundSwap(
            msg.sender,
            requestId,
            request.vaultId,
            depositedUsdToken,
            request.minAmountOut,
            request.assetOut,
            deadlineCache,
            baseFeeUsd,
            refundAmountUsd
        );
    }
}
