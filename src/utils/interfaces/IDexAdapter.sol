// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { ISwapAssetConfig } from "@zaros/utils/interfaces/ISwapAssetConfig.sol";

/// @notice The struct for the swap exact input single payload.
/// @param tokenIn The token to swap from.
/// @param tokenOut The token to swap to.
/// @param amountIn The token amount to swap.
/// @param recipient The recipient of the swap.
struct SwapExactInputSinglePayload {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    address recipient;
}

/// @notice The struct for the swap exact input payload.
/// @param path The path is a sequence of (tokenAddress - fee - tokenAddress),
/// which are the variables needed to compute each pool contract address in our sequence of swaps.
/// The multihop swap router code will automatically find the correct pool with these variables,
/// and execute the swap needed within each pool in our sequence.
/// @param tokenIn The token to swap from.
/// @param tokenOut The token to swap to.
/// @param recipient The recipient of the swap.
/// @param amountIn The token amount to swap.
struct SwapExactInputPayload {
    bytes path;
    address tokenIn;
    address tokenOut;
    address recipient;
    uint256 amountIn;
}

/// @notice The interface for the DEX adapter.
interface IDexAdapter is ISwapAssetConfig {
    /// @notice Executes a swap using the exact input single amount, coming from the swap payload passed by the Market
    /// Making Engine.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapExactInputSinglePayload memory swapCallData)
        external
        returns (uint256 amountOut);

    /// @notice Executes a swap using the exact input amount, coming from the swap payload passed by the Market Making
    /// Engine.
    /// @return amountOut The amount out returned.
    function executeSwapExactInput(SwapExactInputPayload calldata swapPayload) external returns (uint256 amountOut);

    function STRATEGY_ID() external returns (uint128 strategyId);
}
