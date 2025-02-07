// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "./Constants.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

library Math {
    function divUp(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
        return a.mod(b).isZero() ? a.div(b) : a.div(b).add(sd59x18(1));
    }

    function divUp(UD60x18 a, UD60x18 b) internal pure returns (UD60x18) {
        return a.mod(b).isZero() ? a.div(b) : a.div(b).add(ud60x18(1));
    }

    function max(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
        return a.gt(b) ? a : b;
    }

    function max(UD60x18 a, UD60x18 b) internal pure returns (UD60x18) {
        return a.gt(b) ? a : b;
    }

    function min(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
        return a.lt(b) ? a : b;
    }

    function min(UD60x18 a, UD60x18 b) internal pure returns (UD60x18) {
        return a.lt(b) ? a : b;
    }

    /// @notice Converts a native amount of ERC20 tokens to 18 decimals.
    /// @dev This function assumes decimals is always <= 18, thus configuration functions must enforce this
    /// invariant. This invariant is enforced in `MarketMakingEngineConfigurationBranch::configureCollateral`
    /// @param decimals The decimals value of an ERC20 token.
    /// @param amount The ERC20 token amount to convert to 18 decimals.
    /// @return amountX18 The ERC20 token amount represented in 18 decimals.
    function convertTokenAmountToUd60x18(uint8 decimals, uint256 amount) internal pure returns (UD60x18) {
        if (Constants.SYSTEM_DECIMALS == decimals) {
            return ud60x18(amount);
        }
        return ud60x18(amount * 10 ** (Constants.SYSTEM_DECIMALS - decimals));
    }

    /// @notice Converts an 18 decimals system value to a native amount of ERC20 tokens.
    /// @dev This function assumes decimals is always <= 18, thus, configuration functions must enforce this
    /// invariant.
    /// @param decimals The decimals value of an ERC20 token.
    /// @param amountX18 The ERC20 token amount to convert to 18 decimals.
    /// @return amount The downscaled amount represented with the ERC20 token decimals.
    function convertUd60x18ToTokenAmount(uint8 decimals, UD60x18 amountX18) internal pure returns (uint256) {
        if (Constants.SYSTEM_DECIMALS == decimals) {
            return amountX18.intoUint256();
        }

        return amountX18.intoUint256() / (10 ** (Constants.SYSTEM_DECIMALS - decimals));
    }

    /// @notice Converts a native amount of ERC20 tokens to 18 decimals.
    /// @dev This function assumes decimals is always <= 18, thus, configuration functions must enforce this
    /// invariant.
    /// @param decimals The decimals value of an ERC20 token.
    /// @param amount The ERC20 token amount to convert to 18 decimals.
    /// @return amountX18 The ERC20 token amount represented in 18 decimals.
    function convertTokenAmountToSd59x18(uint8 decimals, int256 amount) internal pure returns (SD59x18) {
        if (Constants.SYSTEM_DECIMALS == decimals) {
            return sd59x18(amount);
        }
        return sd59x18(amount * int256(10 ** (Constants.SYSTEM_DECIMALS - decimals)));
    }

    /// @notice Converts an 18 decimals system value to a native amount of ERC20 tokens.
    /// @dev This function assumes decimals is always <= 18, thus, configuration functions must enforce this
    /// invariant.
    /// @param decimals The decimals value of an ERC20 token.
    /// @param amountX18 The ERC20 token amount to convert to 18 decimals.
    /// @return amount The downscaled amount represented with the ERC20 token decimals.
    function convertSd59x18ToTokenAmount(uint8 decimals, SD59x18 amountX18) internal pure returns (uint256) {
        if (Constants.SYSTEM_DECIMALS == decimals) {
            return amountX18.intoUint256();
        }

        return amountX18.intoUint256() / (10 ** (Constants.SYSTEM_DECIMALS - decimals));
    }
}
