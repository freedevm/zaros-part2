// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library LiveMarkets {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_FEE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.LiveMarkets")) - 1));

    struct Data {
        EnumerableSet.UintSet liveMarketIds;
    }

    /// @notice Loads a {UsdTokenSwapConfig}.
    /// @return swap The loaded swap data storage pointer.
    function load() internal pure returns (Data storage swap) {
        bytes32 slot = keccak256(abi.encode(MARKET_FEE_LOCATION));
        assembly {
            swap.slot := slot
        }
    }

    /// @notice Adds a market to the set of live market IDs.
    /// @param self The storage pointer to the market data.
    /// @param marketId The ID of the market to be added.
    function addMarket(Data storage self, uint128 marketId) internal returns (bool) {
        return self.liveMarketIds.add(uint256(marketId));
    }

    /// @notice Removes a market from the set of live market IDs.
    /// @param self The storage pointer to the market data.
    /// @param marketId The ID of the market to be removed.
    function removeMarket(Data storage self, uint128 marketId) internal returns (bool) {
        return self.liveMarketIds.remove(uint256(marketId));
    }

    /// @notice Checks if a market ID is present in the set of live market IDs.
    /// @param self The storage pointer to the market data.
    /// @param marketId The ID of the market to check for existence.
    /// @return True if the market ID exists in the set, false otherwise.
    function containsMarket(Data storage self, uint128 marketId) internal view returns (bool) {
        return self.liveMarketIds.contains(uint256(marketId));
    }

    /// @notice Retrieves all market IDs currently in the set of live market IDs.
    /// @param self The storage pointer to the market data.
    /// @return marketIds An array of live market IDs.
    function getLiveMarketsIds(Data storage self) internal view returns (uint128[] memory marketIds) {
        uint256 liveMarketsLength = self.liveMarketIds.length();
        marketIds = new uint128[](liveMarketsLength);

        for (uint256 i; i < liveMarketsLength; i++) {
            marketIds[i] = uint128(self.liveMarketIds.at(i));
        }
    }
}
