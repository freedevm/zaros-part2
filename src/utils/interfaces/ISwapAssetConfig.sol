// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ISwapAssetConfig {
    function setSwapAssetConfig(address asset, uint8 decimals, address priceAdapter) external;
    function getExpectedOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        external
        view
        returns (uint256 expectedAmountOut);
    function calculateAmountOutMin(uint256 amountOutMinExpected) external view returns (uint256 amountOutMin);
}
