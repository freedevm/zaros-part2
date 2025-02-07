// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "../Errors.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Opinionated enumerable map helper to avoid duplicating logic when handling address to uint maps dealing
/// with assets accounting.
library AssetToAmountMap {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice Support function to increment or decrement the amount stored of a given asset in an enumerable map
    /// @param assetToAmountMap The enumerable map to be updated
    /// @param asset The asset address
    /// @param amountX18 The amount to be incremented
    /// @param shouldIncrement A boolean indicating whether the stored amount should be incremented or decremented
    function update(
        EnumerableMap.AddressToUintMap storage assetToAmountMap,
        address asset,
        UD60x18 amountX18,
        bool shouldIncrement
    )
        internal
    {
        // declare newAmount variable
        UD60x18 newAmount;

        // check if the asset is already in the `assetToAmountMap`
        (bool exists, uint256 value) = assetToAmountMap.tryGet(asset);

        if (exists) {
            // if it is, increment or decrement the amount value
            newAmount = shouldIncrement ? amountX18.add(ud60x18(value)) : ud60x18(value).sub(amountX18);
        } else if (shouldIncrement) {
            // if the asset is not in the map and incrementing its amount, set the new amount to the amount to be
            // stored
            newAmount = amountX18;
        } else {
            // if trying to decrement an asset that is not in the map, revert
            revert Errors.InvalidAssetToAmountMapUpdate();
        }

        // set the new amount for the given `assetToAmountMap`
        assetToAmountMap.set(asset, newAmount.intoUint256());
    }
}
