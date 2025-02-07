// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract Usdc {
    /// @notice Margin collateral configuration parameters.
    string internal constant USDC_NAME = "USD Coin";
    string internal constant USDC_SYMBOL = "USDC";
    string internal constant USDC_PRICE_ADAPTER_NAME = "USDC/USD Zaros Price Adapter";
    string internal constant USDC_PRICE_ADAPTER_SYMBOL = "USDC/USD";
    uint256 internal constant USDC_MARGIN_COLLATERAL_ID = 2;
    UD60x18 internal USDC_DEPOSIT_CAP_X18 = ud60x18(5_000_000_000e18);
    uint120 internal constant USDC_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USDC_MIN_DEPOSIT_MARGIN = 50e6;
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
    address internal constant USDC_ADDRESS = address(0x95011b96c11A4cc96CD8351165645E00F68632a3);
    address internal constant USDC_PRICE_FEED = address(0x80EDee6f667eCc9f63a0a6f55578F870651f06A4);
    uint256 internal constant USDC_LIQUIDATION_PRIORITY = 2;
    uint8 internal constant USDC_DECIMALS = 6;
    uint32 internal constant USDC_PRICE_FEED_HEARBEAT_SECONDS = 86_400;

    bytes32 internal constant USDC_USD_STREAM_ID = 0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992;
    string internal constant USDC_USD_STREAM_ID_STRING =
        "0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992";
}
