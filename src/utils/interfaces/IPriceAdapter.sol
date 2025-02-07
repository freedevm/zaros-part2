// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice The interface for the price adapter.
interface IPriceAdapter {
    /// @notice Returns the USD price of the configured asset.
    /// @return priceUsdX18 The USD quote of the token.
    function getPrice() external view returns (UD60x18 priceUsdX18);
}
