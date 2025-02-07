// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract GetMarginBalanceUsd_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_WhenTheGetMarginBalanceUsdIsCalled(
        uint256 amountToDepositUsdc,
        uint256 amountToDepositWstEth,
        int256 activePositionsUnrealizedPnl
    )
        external
    {
        // it should return the margin balance usd
        amountToDepositUsdc = bound({
            x: amountToDepositUsdc,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        amountToDepositWstEth = bound({
            x: amountToDepositWstEth,
            min: WSTETH_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18)
        });

        activePositionsUnrealizedPnl = bound({
            x: activePositionsUnrealizedPnl,
            min: -int256(USDC_DEPOSIT_CAP_X18.intoUint256()),
            max: int256(USDC_DEPOSIT_CAP_X18.intoUint256())
        });

        SD59x18 activePositionsUnrealizedPnlX18 = sd59x18(activePositionsUnrealizedPnl);

        deal({ token: address(usdc), to: users.naruto.account, give: amountToDepositUsdc });
        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDepositWstEth });

        UD60x18 usdcEquityUsd = IPriceAdapter((marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter)).getPrice()
            .mul(convertTokenAmountToUd60x18(address(usdc), amountToDepositUsdc)).mul(ud60x18(USDC_LOAN_TO_VALUE));

        UD60x18 wstEthEquityUsd = IPriceAdapter((marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceAdapter))
            .getPrice().mul(convertTokenAmountToUd60x18(address(wstEth), amountToDepositWstEth)).mul(
            ud60x18(WSTETH_LOAN_TO_VALUE)
        );

        int256 expectedMarginBalanceUsd =
            int256(usdcEquityUsd.add(wstEthEquityUsd).intoUint256()) + activePositionsUnrealizedPnl;

        uint128 tradingAccountId = createAccountAndDeposit(amountToDepositUsdc, address(usdc));
        perpsEngine.depositMargin(tradingAccountId, address(wstEth), amountToDepositWstEth);

        (SD59x18 marginBalanceUsdX18) =
            perpsEngine.exposed_getMarginBalanceUsd(tradingAccountId, activePositionsUnrealizedPnlX18);

        assertEq(marginBalanceUsdX18.intoInt256(), expectedMarginBalanceUsd, "getMarginBalanceUsd is not correct");
    }
}
