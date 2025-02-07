// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract Deposit_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_WhenDepositIsCalled(uint256 amountToDeposit) external {
        // Test with wstEth that has 18 decimals

        amountToDeposit = bound({
            x: amountToDeposit,
            min: WSTETH_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18)
        });

        UD60x18 amountToDepositX18 = convertTokenAmountToUd60x18(address(wstEth), amountToDeposit);

        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDeposit });

        uint128 tradingAccountId = perpsEngine.createTradingAccount(bytes(""), false);
        perpsEngine.exposed_deposit(tradingAccountId, address(wstEth), amountToDepositX18);

        bool marginCollateralBalanceX18ContainsTheCollateral = perpsEngine
            .workaround_getIfMarginCollateralBalanceX18ContainsTheCollateral(tradingAccountId, address(wstEth));

        uint256 actualTotalDeposited = perpsEngine.workaround_getTotalDeposited(address(wstEth));

        // it should set the margin collateral on user trading account
        assertEq(marginCollateralBalanceX18ContainsTheCollateral, true, "the collateral should be set");

        // it should update the total deposited
        assertEq(amountToDepositX18.intoUint256(), actualTotalDeposited, "total deposited is not correct");

        // Test with usdc that has 6 decimals

        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        amountToDepositX18 = convertTokenAmountToUd60x18(address(usdc), amountToDeposit);

        deal({ token: address(usdc), to: users.naruto.account, give: amountToDeposit });

        perpsEngine.exposed_deposit(tradingAccountId, address(usdc), amountToDepositX18);

        marginCollateralBalanceX18ContainsTheCollateral = perpsEngine
            .workaround_getIfMarginCollateralBalanceX18ContainsTheCollateral(tradingAccountId, address(usdc));

        actualTotalDeposited = perpsEngine.workaround_getTotalDeposited(address(usdc));

        // it should set the margin collateral on user trading account
        assertEq(marginCollateralBalanceX18ContainsTheCollateral, true, "the collateral should be set");

        // it should update the total deposited
        assertEq(amountToDepositX18.intoUint256(), actualTotalDeposited, "total deposited is not correct");
    }
}
