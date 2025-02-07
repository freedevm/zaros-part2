// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, UNIT as UD60x18_UNIT, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD59x18_ZERO } from "@prb-math/SD59x18.sol";

library UsdTokenSwapConfig {
    /// @notice ERC7201 storage location.
    bytes32 internal constant USD_TOKEN_SWAP_CONFIG_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.UsdTokenSwapConfig")) - 1));

    /// @notice Emitted when the USD token swap configuration is updated.
    /// @param baseFeeUsd The updated base fee in USD.
    /// @param swapSettlementFeeBps The updated swap settlement fee in basis points.
    /// @param maxExecutionTime The updated maximum execution time in seconds.
    event LogUpdateUsdTokenSwapConfig(uint128 baseFeeUsd, uint128 swapSettlementFeeBps, uint128 maxExecutionTime);

    /// @notice Represents a swap request for a user.
    /// @param processed Indicates whether the swap has been processed.
    /// @param amountIn The amount of the input asset provided for the swap.
    /// @param minAmountOut The min amount of the output asset expected after the swap.
    /// @param deadline The deadline by which the swap must be fulfilled.
    /// @param assetOut The address of the asset to be received as the output of the swap.
    /// @param vaultId The id of the vault associated with the swap.
    struct SwapRequest {
        bool processed;
        uint120 deadline;
        uint128 amountIn;
        address assetOut;
        uint128 vaultId;
        uint128 minAmountOut;
    }

    /// @notice Represents the configuration and state data for USD token swaps.
    /// @dev The premium/discount function is defined for a usd token swap is defined as:
    ///      f(x) = y_min + Δy * ((x - x_min) / (x_max - x_min))^z
    ///      where:
    ///      - y_min is the minimum premium or discount abs value.
    ///      - Δy = y_max - y_min in abs value.
    ///      - x_min is the minimum debt / tvl value for the premium or discount to be applied.
    ///      - x_max is the maximum debt / tvl value for the premium or discount to be applied.
    ///      - z is the exponent that determines the curvature of the function, i.e how fast the premium or discount
    /// scale up.
    /// @param baseFeeUsd The flat fee for each swap, denominated in USD.
    /// @param swapSettlementFeeBps The swap settlement fee in basis points (bps), applied as a percentage of the swap
    /// amount.
    /// @param maxExecutionTime The maximum allowed time, in seconds, to execute a swap after it has been requested.
    /// @param pdCurveYMin The minimum y value of the premium / discount curve.
    /// @param pdCurveYMax The maximum y value of the premium / discount curve.
    /// @param pdCurveXMin The minimum x value of the premium / discount curve.
    /// @param pdCurveXMax The maximum x value of the premium / discount curve.
    /// @param pdCurveZ The exponent that determines the curvature of the premium / discount curve.
    /// @param usdcAvailableForEngine The amount of USDC backing an engine's usd token, coming from vaults that had
    /// their debt settled, allocating the usdc acquired to users of that engine. Note: usdc stored here isn't owned
    /// by any vault, it's where usdc from settled vaults is stored, to be used for swaps, although swaps can
    /// also be done using a vault's deposited usdc.
    /// @param swapRequestIdCounter A counter for tracking the number of swap requests per user address.
    /// @param swapRequests A mapping that tracks all swap requests for each user, by user address and swap request
    /// id.
    struct Data {
        uint128 baseFeeUsd; // 1 USD
        uint128 swapSettlementFeeBps; // 0.3 %
        uint128 maxExecutionTime;
        uint128 pdCurveYMin;
        uint128 pdCurveYMax;
        uint128 pdCurveXMin;
        uint128 pdCurveXMax;
        uint128 pdCurveZ;
        mapping(address engine => uint256 availableUsdc) usdcAvailableForEngine;
        mapping(address => uint128) swapRequestIdCounter;
        mapping(address => mapping(uint128 => SwapRequest)) swapRequests;
    }

    /// @notice Loads the {UsdTokenSwapConfig}.
    /// @return usdTokenSwapConfig The loaded usd token swap config data storage pointer.
    function load() internal pure returns (Data storage usdTokenSwapConfig) {
        bytes32 slot = keccak256(abi.encode(USD_TOKEN_SWAP_CONFIG_LOCATION));
        assembly {
            usdTokenSwapConfig.slot := slot
        }
    }

    /// @notice Returns the premium or discount to be applied to the amount out of a swap, based on the vault's debt
    /// and the system configured premium / discount curve parameters.
    /// @dev The following invariant defining the premium / discount curve must hold true:
    ///      f(x) = y_min + Δy * ((x - x_min) / (x_max - x_min))^z | x ∈ [x_min, x_max]
    /// @dev The proposed initial curve is defined as:
    ///      f(x) = 1 + 9 * ((x - 0.3) / 0.5)^3
    /// @dev If no premium or discount has to be applied, the function returns 1 as UD60x18.
    /// @dev Using the proposed z value of 3, the slope of f(x) near the upper bound of x is steeper than near the
    /// lower bound, meaning the premium or discount accelerates faster as the vault's debt / tvl ratio increases.
    function getPremiumDiscountFactor(
        Data storage self,
        UD60x18 vaultAssetsValueUsdX18,
        SD59x18 vaultDebtUsdX18
    )
        internal
        view
        returns (UD60x18 premiumDiscountFactorX18)
    {
        // calculate the vault's tvl / debt absolute value, positive means we'll apply a discount, negative means
        // we'll apply a premium

        UD60x18 vaultDebtTvlRatioAbs = vaultDebtUsdX18.abs().intoUD60x18().div(vaultAssetsValueUsdX18);

        // cache the minimum x value of the premium / discount curve
        UD60x18 pdCurveXMinX18 = ud60x18(self.pdCurveXMin);
        // cache the maximum x value of the premium / discount curve
        UD60x18 pdCurveXMaxX18 = ud60x18(self.pdCurveXMax);

        // if the vault's debt / tvl ratio is less than or equal to the minimum x value of the premium / discount
        // curve, then we don't apply any premium or discount
        if (vaultDebtTvlRatioAbs.lte(pdCurveXMinX18)) {
            premiumDiscountFactorX18 = UD60x18_UNIT;
            return premiumDiscountFactorX18;
        }

        // if the vault's debt / tvl ratio is greater than or equal to the maximum x value of the premium / discount
        // curve, we use the max X value, otherwise, use the calculated vault tvl / debt ratio
        UD60x18 pdCurveXX18 = vaultDebtTvlRatioAbs.gte(pdCurveXMaxX18) ? pdCurveXMaxX18 : vaultDebtTvlRatioAbs;

        // cache the minimum y value of the premium / discount curve
        UD60x18 pdCurveYMinX18 = ud60x18(self.pdCurveYMin);
        // cache the maximum y value of the premium / discount curve
        UD60x18 pdCurveYMaxX18 = ud60x18(self.pdCurveYMax);

        // cache the exponent that determines the steepness of the premium / discount curve
        UD60x18 pdCurveZX18 = ud60x18(self.pdCurveZ);

        // calculate the y point of the premium or discount curve given the x point
        UD60x18 pdCurveYX18 = pdCurveYMinX18.add(
            pdCurveYMaxX18.sub(pdCurveYMinX18).mul(
                pdCurveXX18.sub(pdCurveXMinX18).div(pdCurveXMaxX18.sub(pdCurveXMinX18)).pow(pdCurveZX18)
            )
        );
        // if the vault is in credit, we apply a discount, otherwise, we apply a premium
        premiumDiscountFactorX18 =
            vaultDebtUsdX18.lt(SD59x18_ZERO) ? UD60x18_UNIT.sub(pdCurveYX18) : UD60x18_UNIT.add(pdCurveYX18);
    }

    /// @notice Updates the fee and execution time parameters for USD token swaps.
    /// @param baseFeeUsd The new flat fee for each swap, denominated in USD.
    /// @param swapSettlementFeeBps The new swap settlement fee in basis points (bps), applied as a percentage of the
    /// swap amount.
    /// @param maxExecutionTime The new maximum allowed time, in seconds, to execute a swap after it has been
    /// requested.
    function update(uint128 baseFeeUsd, uint128 swapSettlementFeeBps, uint128 maxExecutionTime) internal {
        Data storage self = load();

        self.baseFeeUsd = baseFeeUsd;
        self.swapSettlementFeeBps = swapSettlementFeeBps;
        self.maxExecutionTime = maxExecutionTime;

        emit LogUpdateUsdTokenSwapConfig(baseFeeUsd, swapSettlementFeeBps, maxExecutionTime);
    }

    /// @notice Increments and returns the next swap request ID for a given user.
    /// @dev This function updates the `swapRequestIdCounter` mapping to generate a unique ID for each user's swap
    /// request.
    /// @param user The address of the user for whom the next swap request ID is being generated.
    /// @return id The new incremented swap request ID for the specified user.
    function nextId(Data storage self, address user) internal returns (uint128 id) {
        return ++self.swapRequestIdCounter[user];
    }
}
