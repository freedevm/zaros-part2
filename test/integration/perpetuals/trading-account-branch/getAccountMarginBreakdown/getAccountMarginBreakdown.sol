// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract getAccountMarginBreakdown_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_GetAccountMarginOneCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: users.naruto.account, give: amountToDeposit });

        uint256 expectedMarginBalance = IPriceAdapter((marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter))
            .getPrice().mul(convertTokenAmountToUd60x18(address(usdc), amountToDeposit)).intoUint256();

        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdc));

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableBalance
        ) = perpsEngine.getAccountMarginBreakdown({ tradingAccountId: tradingAccountId });

        assertEq(marginBalanceUsdX18.intoUint256(), expectedMarginBalance, "getAccountMargin marginBalanceUsdX18");
        assertEq(availableBalance.intoUint256(), expectedAvailableBalance, "getAccountMargin availableBalance");
        assertEq(initialMarginUsdX18.intoUint256(), expectedInitialMargin, "getAccountMargin initialMarginUsdX18");
        assertEq(
            maintenanceMarginUsdX18.intoUint256(),
            expectedMaintenanceMargin,
            "getAccountMargin maintenanceMarginUsdX18"
        );
    }

    function testFuzz_AvailableBalance(uint128 marketId, uint256 amountToDeposit, bool isLong) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: users.naruto.account, give: amountToDeposit });

        uint256 initialMarginRate = fuzzMarketConfig.imr;
        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdc));

        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, amountToDeposit, isLong);

        (SD59x18 marginBalanceUsdX18, UD60x18 initialMarginUsdX18,, SD59x18 availableBalance) =
            perpsEngine.getAccountMarginBreakdown({ tradingAccountId: tradingAccountId });

        SD59x18 availableMarginSubByInitialMargin = marginBalanceUsdX18.sub((initialMarginUsdX18).intoSD59x18());

        assertGt(
            availableBalance.intoInt256(),
            availableMarginSubByInitialMargin.intoInt256(),
            "marginBalance substracted by maintenance margin > marginBalance substracted by initial margin"
        );
    }

    function testFuzz_GetAccountMarginMultipleCollateral(
        uint256 amountToDepositUsdc,
        uint256 amountToDepositWstEth
    )
        external
    {
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

        deal({ token: address(usdc), to: users.naruto.account, give: amountToDepositUsdc });
        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDepositWstEth });

        UD60x18 usdcEquityUsd = IPriceAdapter((marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter)).getPrice()
            .mul(convertTokenAmountToUd60x18(address(usdc), amountToDepositUsdc));

        UD60x18 wstEthEquityUsd = IPriceAdapter((marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceAdapter))
            .getPrice().mul(convertTokenAmountToUd60x18(address(wstEth), amountToDepositWstEth)).mul(
            ud60x18(WSTETH_LOAN_TO_VALUE)
        );

        uint256 expectedMarginBalance = usdcEquityUsd.add(wstEthEquityUsd).intoUint256();

        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint128 tradingAccountId = createAccountAndDeposit(amountToDepositUsdc, address(usdc));
        perpsEngine.depositMargin(tradingAccountId, address(wstEth), amountToDepositWstEth);

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableBalance
        ) = perpsEngine.getAccountMarginBreakdown({ tradingAccountId: tradingAccountId });

        assertEq(marginBalanceUsdX18.intoUint256(), expectedMarginBalance, "getAccountMargin marginBalanceUsdX18");
        assertEq(availableBalance.intoUint256(), expectedAvailableBalance, "getAccountMargin availableBalance");
        assertEq(initialMarginUsdX18.intoUint256(), expectedInitialMargin, "getAccountMargin initialMarginUsdX18");
        assertEq(
            maintenanceMarginUsdX18.intoUint256(),
            expectedMaintenanceMargin,
            "getAccountMargin maintenanceMarginUsdX18"
        );
    }
}
