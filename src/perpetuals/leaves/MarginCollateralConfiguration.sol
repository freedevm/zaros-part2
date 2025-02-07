// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

library MarginCollateralConfiguration {
    /// @notice ERC7201 storage location.
    bytes32 internal constant MARGIN_COLLATERAL_CONFIGURATION_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.perpetuals.MarginCollateralConfiguration")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice {MarginCollateralConfiguration} namespace storage structure.
    /// @param depositCap The maximum deposit cap of the given margin collateral type.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param decimals The decimals of the given margin collateral type's ERC20 token.
    /// @param priceAdapter The price adapter address of the given margin collateral type.
    /// @param totalDeposited The total amount of margin collateral deposited normalized to 18 decimals.
    /// @param useEthPriceFeed A flag indicating if the margin collateral type uses a custom price adapter.
    struct Data {
        uint128 depositCap;
        uint120 loanToValue;
        uint8 decimals;
        address priceAdapter;
        uint256 totalDeposited;
    }

    /// @notice Loads a {MarginCollateralConfiguration} object.
    /// @param collateralType The margin collateral type.
    /// @return marginCollateralConfiguration The loaded margin collateral storage pointer.
    function load(address collateralType) internal pure returns (Data storage marginCollateralConfiguration) {
        bytes32 slot = keccak256(abi.encode(MARGIN_COLLATERAL_CONFIGURATION_LOCATION, collateralType));
        assembly {
            marginCollateralConfiguration.slot := slot
        }
    }

    /// @notice Converts the provided denormalized amount of margin collateral to UD60x18.
    /// @dev We can assume self.decimals is always <= SYSTEM_DECIMALS, since it's a requirement at `setDecimals`.
    /// @param self The margin collateral type storage pointer.
    /// @param amount The amount of margin collateral to convert.
    /// @return amountX18 The converted amount of margin collateral to the system's decimals.
    function convertTokenAmountToUd60x18(Data storage self, uint256 amount) internal view returns (UD60x18) {
        return Math.convertTokenAmountToUd60x18(self.decimals, amount);
    }

    /// @notice Converts the provided 18 decimals normalized amount to the margin collateral's decimals amount.
    /// @dev We can assume self.decimals is always <= SYSTEM_DECIMALS, since it's a requirement at `setDecimals`.
    /// @param self The margin collateral type storage pointer.
    /// @param amountX18 The 18 decimals normalized amount.
    /// @return amount The denormalized amount using the ERC20 token's decimals.
    function convertUd60x18ToTokenAmount(Data storage self, UD60x18 amountX18) internal view returns (uint256) {
        return Math.convertUd60x18ToTokenAmount(self.decimals, amountX18);
    }

    /// @notice Returns the price of the given margin collateral type.
    /// @param self The margin collateral type storage pointer.
    /// @return price The price of the given margin collateral type.
    function getPrice(Data storage self) internal view returns (UD60x18 price) {
        address priceAdapter = self.priceAdapter;

        if (priceAdapter == address(0)) {
            revert Errors.CollateralPriceFeedNotDefined();
        }

        price = IPriceAdapter(priceAdapter).getPrice();
    }

    /// @notice Configures the settings of a given margin collateral type.
    /// @dev A margin collateral type is considered disabled if `depositCap` == 0.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of  collateral that can be deposited.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param decimals The amount of decimals of the given margin collateral type's ERC20 token.
    /// @param priceAdapter The price oracle address.
    function configure(
        address collateralType,
        uint128 depositCap,
        uint120 loanToValue,
        uint8 decimals,
        address priceAdapter
    )
        internal
    {
        Data storage self = load(collateralType);

        self.depositCap = depositCap;
        self.loanToValue = loanToValue;
        self.decimals = decimals;
        self.priceAdapter = priceAdapter;
    }
}
