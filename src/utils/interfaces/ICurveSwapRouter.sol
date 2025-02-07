// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICurveSwapRouter {
    /// https://docs.curve.fi/router/CurveRegistryExchange/?h=#exchange_with_best_rate
    /// @notice Finds the best rate and performs a swap between two tokens
    /// @param _from The address of the token to swap from
    /// @param _to The address of the token to swap to
    /// @param _amount The amount of `fromToken` to swap
    /// @param _expected The minimum acceptable amount of `toToken` to receive
    /// @param _receiver The address to receive the output tokens (defaults to msg.sender if not provided)
    /// @return amountOut The actual amount of `toToken` received
    function exchange_with_best_rate(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _expected,
        address _receiver
    )
        external
        payable
        returns (uint256 amountOut);
}
