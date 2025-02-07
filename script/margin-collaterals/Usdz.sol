// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract UsdToken {
    /// @notice Margin collateral configuration parameters.
    string internal constant USD_TOKEN_NAME = "Zaros Perpetuals AMM USD";
    string internal constant USD_TOKEN_SYMBOL = "USDz";
    string internal constant USD_TOKEN_PRICE_ADAPTER_NAME = "USDz/USD Zaros Price Adapter";
    string internal constant USD_TOKEN_PRICE_ADAPTER_SYMBOL = "USDz/USD";
    uint256 internal constant USD_TOKEN_MARGIN_COLLATERAL_ID = 1;
    UD60x18 internal USD_TOKEN_DEPOSIT_CAP_X18 = ud60x18(50_000_000_000e18);
    uint120 internal constant USD_TOKEN_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USD_TOKEN_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USD_TOKEN_USD_PRICE = 1e18;
    address internal constant USD_TOKEN_ADDRESS = address(0x8648d10fE74dD9b4B454B4db9B63b03998c087Ba);
    address internal constant USD_TOKEN_PRICE_FEED = address(0x80EDee6f667eCc9f63a0a6f55578F870651f06A4);
    uint256 internal constant USD_TOKEN_LIQUIDATION_PRIORITY = 1;
    uint8 internal constant USD_TOKEN_DECIMALS = 18;
    uint32 internal constant USD_TOKEN_PRICE_FEED_HEARBEAT_SECONDS = 86_400;
}
