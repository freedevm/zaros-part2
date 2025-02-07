// SPDX-License-Identifier: UNLICENSE
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

import { FeeRecipients } from "@zaros/perpetuals/leaves/FeeRecipients.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract DeductAccountMargin_Unit_Test is Base_Test {
    /// @dev usually the funciton is called if pnl is < 0

    struct DeductAccountMarginContext {
        UD60x18 marginCollateralBalanceX18;
        UD60x18 marginCollateralPriceUsdX18;
        UD60x18 settlementFeeDeductedUsdX18;
        UD60x18 withdrawnMarginUsdX18;
        bool isMissingMargin;
        UD60x18 orderFeeDeductedUsdX18;
        UD60x18 pnlDeductedUsdX18;
    }

    struct FillOrderContext {
        address usdToken;
        uint128 marketId;
        uint128 tradingAccountId;
        UD60x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        SD59x18 sizeDelta;
        UD60x18 fillPrice;
        SD59x18 pnl;
        SD59x18 fundingFeePerUnit;
        SD59x18 fundingRate;
        Position.Data newPosition;
        UD60x18 newOpenInterest;
        SD59x18 newSkew;
    }

    uint256 usdcDepositCap;

    function setUp() public override {
        Base_Test.setUp();

        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });

        usdcDepositCap = convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18);
    }

    modifier whenThereIsCollateralLiquidationPriority() {
        _;
    }

    function test_GivenTheAccountHasAMarginBalanceOfZero(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
    {
        // it should continue to the next collateral

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        UD60x18 marginCollateralBalanceX18 =
            perpsEngine.exposed_getMarginCollateralBalance(tradingAccountId, address(usdc));

        perpsEngine.exposed_withdrawMarginUsd(
            tradingAccountId, address(usdc), ud60x18(marginValueUsd), marginCollateralBalanceX18, users.naruto.account
        );

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }

    modifier givenTheAccountHasAMarginBalanceDifferentFromZero() {
        _;
    }

    function testFuzz_WhenTheSettlementFeeUsdX18IsZero(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
        givenTheAccountHasAMarginBalanceDifferentFromZero
    {
        // it should skip the settlementFeeUsdX18 check
        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }

    function testFuzz_WhenSettlementFeeUsdX18IsGreaterThanZeroAndIfTheAlreadyDeductedSettlementFeeSettlementFeeDeductedUsdX18IsLessThanTheTotalSettlementFeeUsdX18(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
        givenTheAccountHasAMarginBalanceDifferentFromZero
    {
        // it should deduct the settlement fee from the account's margin balance
        // it should return isMissingMargin a boolean indicating whether there was insufficient margin to cover the
        // fee

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(feeAmount);

        UD60x18 pnlUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }

    function testFuzz_WhenTheOrderFeeUsdX18IsZero(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
        givenTheAccountHasAMarginBalanceDifferentFromZero
    {
        // it should skip the orderFeeUsdX18 check

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }

    function testFuzz_WhenTheOrderFeeUsdX18IsGreaterThanZeroAndIfTheAlreadyDeductedOrderFeeOrderFeeDeductedUsdX18IsLessThanTheTotalOrderFeeUsdX18(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
        givenTheAccountHasAMarginBalanceDifferentFromZero
    {
        // it should deduct the order fee from the account's margin balance
        // it should return isMissingMargin a boolean indicating whether there was insufficient margin to cover the
        // fee

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(randomFeeAmount2);

        UD60x18 orderFeeUsdX18 = ud60x18(feeAmount);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }

    function testFuzz_WhenPnlUsdX18IsZero(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
        givenTheAccountHasAMarginBalanceDifferentFromZero
    {
        // it should skip the pnlUsdX18 check

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(randomFeeAmount2);

        UD60x18 orderFeeUsdX18 = ud60x18(feeAmount);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }

    function testFuzz_WhenPnlUsdX18IsGreaterThanZeroAndIfTheAlreadyDeductedPnLPnlDeductedUsdX18IsLessThanTheTotalPnlUsdX18IndicatingRemainingPnLToBeAccountedFor(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
        givenTheAccountHasAMarginBalanceDifferentFromZero
    {
        // it should deduct the PnL from the account's margin balance
        // it should return isMissingMargin a boolean indicating whether there was insufficient margin to cover the
        // fee

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }

    function test_WhenTheMarginCollateralBalanceIsZeroAfterDeductingOneOfTheFees(uint256 marginValueUsd)
        external
        whenThereIsCollateralLiquidationPriority
        givenTheAccountHasAMarginBalanceDifferentFromZero
    {
        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap / 3 });

        changePrank({ msgSender: users.naruto.account });
        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
        uint128 narutoTradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        changePrank({ msgSender: users.sakura.account });
        deal({ token: address(usdc), to: users.sakura.account, give: marginValueUsd });
        createAccountAndDeposit(marginValueUsd, address(usdc));

        changePrank({ msgSender: users.madara.account });
        deal({ token: address(usdc), to: users.madara.account, give: marginValueUsd });
        createAccountAndDeposit(marginValueUsd, address(usdc));

        changePrank({ msgSender: users.naruto.account });

        UD60x18 marginValueUsdX18 = convertTokenAmountToUd60x18(address(usdc), marginValueUsd);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        uint256 marginDeductedUsd = perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: narutoTradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: marginValueUsdX18,
            orderFeeUsdX18: marginValueUsdX18,
            settlementFeeUsdX18: marginValueUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        }).intoUint256();

        uint256 totalDepositedOfUsdc = perpsEngine.workaround_getTotalDeposited(address(usdc));
        uint256 expectedTotalDepositedOfUsdc =
            convertTokenAmountToUd60x18(address(usdc), marginValueUsd * 2).intoUint256();

        uint256 expectedMarginDeductedUsd = marginValueUsdX18.intoUint256();

        // it should not update the totalDeposit when the margin collateral balance of user is zero
        assertEq(marginDeductedUsd, expectedMarginDeductedUsd, "margin deducted is not correct");
        assertEq(totalDepositedOfUsdc, expectedTotalDepositedOfUsdc, "total deposited is not correct");
    }

    function testFuzz_WhenThereIsNotCollateralLiquidationPriority(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
    {
        // it should calculate the total margin deducted in USD (by summing up three different types of deductions
        // from an account's margin balance)
        // it should return the new margin balance
        address[] memory collateralTypes;

        perpsEngine.exposed_configureCollateralLiquidationPriority(collateralTypes);

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: usdcDepositCap });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: usdcDepositCap - 1 });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = INITIAL_MARKET_ID;

        UD60x18[] memory accountPositionsNotionalValueX18 = new UD60x18[](1);
        accountPositionsNotionalValueX18[0] = ud60x18(1e18);

        perpsEngine.exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18,
            marketIds: marketIds,
            accountPositionsNotionalValueX18: accountPositionsNotionalValueX18
        });
    }
}
