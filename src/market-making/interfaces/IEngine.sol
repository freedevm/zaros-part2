// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IEngine {
    /// @notice Returns the accumulated debt that hasn't yet been realized by the engine.
    /// @dev The protocol admin should manage Vaults configuration gracefully in order to isolate risk profiles and
    /// avoid potential issues of an engine's market improperly reporting debt spoofing the credit delegation state of
    /// other markets connected to the same vault.
    /// @param marketId The market identifier.
    /// @return unrealizedDebt The unrealized debt value.
    function getUnrealizedDebt(uint128 marketId) external view returns (int256);
}
