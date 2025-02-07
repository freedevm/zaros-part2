// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract WeEth {
    /// @notice Margin collateral configuration parameters.
    string internal constant WEETH_NAME = "Wrapped eETH";
    string internal constant WEETH_SYMBOL = "weETH";
    string internal constant WEETH_PRICE_ADAPTER_NAME = "WEETH/USD Zaros Price Adapter";
    string internal constant WEETH_PRICE_ADAPTER_SYMBOL = "WEETH/USD";
    uint256 internal constant WEETH_MARGIN_COLLATERAL_ID = 6;
    UD60x18 internal WEETH_DEPOSIT_CAP_X18 = ud60x18(1_000_000e18);
    uint120 internal constant WEETH_LOAN_TO_VALUE = 0.7e18;
    uint256 internal constant WEETH_MIN_DEPOSIT_MARGIN = 0.025e18;
    uint256 internal constant MOCK_WEETH_USD_PRICE = 2000e18;
    address internal constant WEETH_ADDRESS = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    address internal constant WEETH_PRICE_FEED = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    uint256 internal constant WEETH_LIQUIDATION_PRIORITY = 6;
    uint8 internal constant WEETH_DECIMALS = 18;
    uint32 internal constant WEETH_PRICE_FEED_HEARBEAT_SECONDS = 86_400;

    bytes32 internal constant WEETH_USD_STREAM_ID = 0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9;
    string internal constant WEETH_USD_STREAM_ID_STRING =
        "0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9";
}
