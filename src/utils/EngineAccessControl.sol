// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { Errors } from "@zaros/utils/Errors.sol";

/// @notice EngineAccessControl is an abstract contract that provides access control utility to the market making
/// engine's branches.
abstract contract EngineAccessControl {
    /// @notice Modifier to check if the caller is a registered engine.
    modifier onlyRegisteredEngine(uint128 marketId) {
        // load market making engine configuration
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // if `msg.sender` is not a registered engine, revert
        if (!marketMakingEngineConfiguration.isRegisteredEngine[msg.sender]) {
            revert Errors.Unauthorized(msg.sender);
        }

        // load market
        Market.Data storage market = Market.load(marketId);

        // if `msg.sender` is not the market's registered engine, revert
        if (market.engine != msg.sender) {
            revert Errors.Unauthorized(msg.sender);
        }

        // continue execution
        _;
    }

    /// @notice Modifier to check if the caller is a registered system keeper.
    modifier onlyRegisteredSystemKeepers() {
        // load market making engine configuration
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // if `msg.sender` is not a registered system keeper, revert
        if (!marketMakingEngineConfiguration.isSystemKeeperEnabled[msg.sender]) {
            revert Errors.Unauthorized(msg.sender);
        }

        // continue execution
        _;
    }
}
