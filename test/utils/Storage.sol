// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract Storage {
    /// @dev PerpsEngineConfiguration namespace storage location.
    bytes32 internal constant PERPS_ENGINE_CONFIGURATION_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.perpetuals.PerpsEngineConfiguration")) - 1)
    ) & ~bytes32(uint256(0xff));
}
