// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Swap {
    /// @notice ERC7201 storage location.
    bytes32 internal constant SWAP_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Swap")) - 1));

    // TODO: pack storage slots
    struct Data {
        address assetFrom;
        uint256 amount;
        uint256 minUsdTokenOut;
        uint256 deadline;
    }

    /// @notice Loads a {Swap}.
    /// @param account The address that requested the swap.
    /// @return swap The loaded swap data storage pointer.
    function load(address account) internal pure returns (Data storage swap) {
        bytes32 slot = keccak256(abi.encode(SWAP_LOCATION, account));
        assembly {
            swap.slot := slot
        }
    }
}
