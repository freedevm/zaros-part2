// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Constants used across the protocol.
library Constants {
    /// @notice Protocol wide standard decimals.
    uint8 internal constant SYSTEM_DECIMALS = 18;

    /// @notice Default period for the proportional funding rate calculations.
    uint256 internal constant PROPORTIONAL_FUNDING_PERIOD = 1 days;

    /// @notice Default grace period for the sequencer uptime feed.
    uint256 internal constant SEQUENCER_GRACE_PERIOD_TIME = 3600;

    /// @notice EIP712 domain name.
    string internal constant ZAROS_DOMAIN_NAME = "Zaros Perpetuals DEX";

    /// @notice EIP712 domain version.
    string internal constant ZAROS_DOMAIN_VERSION = "1";

    /// @notice EIP712 sign offchain order typehash.
    bytes32 internal constant CREATE_OFFCHAIN_ORDER_TYPEHASH = keccak256(
        "CreateOffchainOrder(uint128 tradingAccountId,uint128 marketId,int128 sizeDelta,uint128 targetPrice,bool shouldIncreaseNonce,uint120 nonce,bytes32 salt)"
    );

    /// @notice basis points denominator value.
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice minimum allowed slippage tolerance
    uint256 internal constant MIN_SLIPPAGE_BPS = 100;

    /// @notice maximum allowed slippage tolerance; should be smaller than
    // BPS_DENOMINATOR as otherwise would result in slippage calculated to zero
    uint256 internal constant MAX_SLIPPAGE_BPS = BPS_DENOMINATOR - 1;

    /// @notice Maximum value for shares, example 0.5e18 is 50%.
    /// @dev This is used to avoid overflows when calculating shares.
    uint256 internal constant MAX_SHARES = 1e18;

    /// @notice Sanity value used to ensure that a protocol admin never sets 100% of fees to protocol fee recipients,
    /// avoiding bugs which may happen in that state.
    uint256 internal constant MAX_CONFIGURABLE_PROTOCOL_FEE_SHARES = 0.9e18;

    /// @notice Minimum value for stake shares.
    uint256 internal constant MIN_OF_SHARES_TO_STAKE = 1e5;
}
