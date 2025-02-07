// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library AssetSwapPath {
    /// @notice ERC7201 storage location.
    bytes32 internal constant ASSET_SWAP_STRATEGY_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.AssetSwapPath")) - 1));

    /// @notice AssetSwapPath data storage struct.
    struct Data {
        bool enabled;
        address[] assets;
        uint128[] dexSwapStrategyIds;
    }

    /// @notice Loads a {AssetSwapPath}.
    /// @param asset The AssetSwapPath asset address.
    /// @return assetSwapPath The loaded AssetSwapPath storage pointer.
    function load(address asset) internal pure returns (Data storage assetSwapPath) {
        bytes32 slot = keccak256(abi.encode(ASSET_SWAP_STRATEGY_LOCATION, asset));
        assembly {
            assetSwapPath.slot := slot
        }
    }

    /// @notice Configures a {AssetSwapPath}.
    /// @param enabled bool indicating whether the swap strategy for the asset is enabled
    /// @param assets the assets path to swap where the first asset should always be the ERC7201 access asset
    /// @param dexSwapStrategyIds The dex swap strategy IDs to use for each swap
    /// Example: 4 tokens, 3 swaps
    /// sUSDe --curve--> USDe --curve--> USDC --UniV3--> WETH
    /// assets should be  [sUSDe, USDe, USDC]
    /// dexSwapStrategyIds should be [3, 3, 1] where "3" is curve swap strategy id and "1" is UniV3
    function configure(
        Data storage self,
        bool enabled,
        address[] memory assets,
        uint128[] memory dexSwapStrategyIds
    )
        internal
    {
        self.enabled = enabled;
        self.assets = assets;
        self.dexSwapStrategyIds = dexSwapStrategyIds;
    }
}
