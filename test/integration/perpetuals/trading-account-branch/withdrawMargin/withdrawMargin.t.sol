// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract WithdrawMargin_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();

        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertGiven_TheAccountDoesNotExist(uint128 tradingAccountId) external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, tradingAccountId, users.naruto.account)
        });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdc), 0);
    }

    modifier givenTheAccountExists() {
        _;
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
    {
        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        amountToWithdraw = bound({ x: amountToWithdraw, min: USDC_MIN_DEPOSIT_MARGIN, max: amountToDeposit });
        deal({ token: address(usdc), to: users.naruto.account, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdc));
        changePrank({ msgSender: users.sasuke.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AccountPermissionDenied.selector, tradingAccountId, users.sasuke.account
            )
        });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdc), amountToWithdraw);
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(uint256 amountToDeposit)
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
    {
        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: users.naruto.account, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdc));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdc), 0);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_TheUserHasPendingMarketOrders(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 amountToWithdraw,
        uint256 marketId,
        bool isLong
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.exposed_update(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: marginValueUsd });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketOrderStillPending.selector, block.timestamp)
        });
        perpsEngine.depositMargin(tradingAccountId, address(usdc), amountToWithdraw);
    }

    function testFuzz_RevertGiven_TheUserHasActiveMarketOrders(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 amountToWithdraw,
        uint256 marketId,
        bool isLong
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        changePrank({ msgSender: users.owner.account });
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMinLifetime: 0,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD,
            marginCollateralRecipient: feeRecipients.marginCollateralRecipient,
            orderFeeRecipient: feeRecipients.orderFeeRecipient,
            settlementFeeRecipient: feeRecipients.settlementFeeRecipient,
            liquidationFeeRecipient: users.liquidationFeeRecipient.account,
            referralModule: address(referralModule),
            whitelist: address(whitelist),
            marketMakingEngine: address(marketMakingEngine),
            maxVerificationDelay: MAX_VERIFICATION_DELAY,
            isWhitelistMode: true
        });
        changePrank({ msgSender: users.naruto.account });

        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: marginValueUsd });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.ActiveMarketOrder.selector, tradingAccountId, fuzzMarketConfig.marketId, sizeDelta, block.timestamp
            )
        });

        perpsEngine.withdrawMargin(tradingAccountId, address(usdc), amountToWithdraw);
    }

    function testFuzz_RevertGiven_ThereIsntEnoughMarginCollateral(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
    {
        amountToDeposit = bound({
            x: amountToDeposit,
            min: WSTETH_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18)
        });
        vm.assume(amountToWithdraw > amountToDeposit);
        uint256 expectedMarginCollateralBalance =
            convertTokenAmountToUd60x18(address(wstEth), amountToDeposit).intoUint256();
        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientCollateralBalance.selector, amountToWithdraw, expectedMarginCollateralBalance
            )
        });
        perpsEngine.withdrawMargin(tradingAccountId, address(wstEth), amountToWithdraw);
    }

    modifier givenThereIsEnoughMarginCollateral() {
        _;
    }

    struct TestFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement_Context {
        MarketConfig fuzzMarketConfig;
        UD60x18 adjustedMarginRequirements;
        UD60x18 maxMarginValueUsd;
        uint256 amountToWithdraw;
        uint128 tradingAccountId;
        int128 sizeDelta;
        SD59x18 marginBalanceUsdX18;
        UD60x18 requiredInitialMarginUsdX18;
        UD60x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        bytes mockSignedReport;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirements(
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
    {
        TestFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement_Context memory ctx;
        ctx.fuzzMarketConfig = getFuzzMarketConfig(marketId);
        ctx.adjustedMarginRequirements = ud60x18(ctx.fuzzMarketConfig.imr).mul(ud60x18(1.001e18));

        // avoids very small rounding errors in super edge cases
        // ctx.adjustedMarginRequirements = ud60x18(ctx.fuzzMarketConfig.imr).mul(ud60x18(1.001e18));
        ctx.maxMarginValueUsd = ctx.adjustedMarginRequirements.mul(ud60x18(ctx.fuzzMarketConfig.maxSkew)).mul(
            ud60x18(ctx.fuzzMarketConfig.mockUsdPrice)
        );

        marginValueUsd =
            bound({ x: marginValueUsd, min: USD_TOKEN_MIN_DEPOSIT_MARGIN, max: ctx.maxMarginValueUsd.intoUint256() });
        ctx.amountToWithdraw = marginValueUsd;

        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        ctx.tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: ctx.tradingAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ctx.adjustedMarginRequirements,
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(ctx.fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(ctx.fuzzMarketConfig.minTradeSize),
                price: ud60x18(ctx.fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        (,,, ctx.orderFeeUsdX18, ctx.settlementFeeUsdX18,) = perpsEngine.simulateTrade(
            OrderBranch.SimulateTradeParams({
                tradingAccountId: ctx.tradingAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                sizeDelta: sizeDelta
            })
        );

        ctx.amountToWithdraw =
            ctx.amountToWithdraw - ctx.orderFeeUsdX18.intoUint256() - ctx.settlementFeeUsdX18.intoUint256();

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: ctx.tradingAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        (ctx.marginBalanceUsdX18, ctx.requiredInitialMarginUsdX18,, ctx.orderFeeUsdX18, ctx.settlementFeeUsdX18,) =
        perpsEngine.simulateTrade(
            OrderBranch.SimulateTradeParams({
                tradingAccountId: ctx.tradingAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                sizeDelta: sizeDelta
            })
        );

        ctx.mockSignedReport = getMockedSignedReport(ctx.fuzzMarketConfig.streamId, ctx.fuzzMarketConfig.mockUsdPrice);

        changePrank({ msgSender: marketOrderKeepers[ctx.fuzzMarketConfig.marketId] });

        perpsEngine.fillMarketOrder(ctx.tradingAccountId, ctx.fuzzMarketConfig.marketId, ctx.mockSignedReport);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientMargin.selector,
                ctx.tradingAccountId,
                int256(marginValueUsd) - int256(ctx.amountToWithdraw) - ctx.orderFeeUsdX18.intoSD59x18().intoInt256()
                    - ctx.settlementFeeUsdX18.intoSD59x18().intoInt256(),
                ctx.requiredInitialMarginUsdX18,
                0
            )
        });

        changePrank({ msgSender: users.naruto.account });
        perpsEngine.withdrawMargin({
            tradingAccountId: ctx.tradingAccountId,
            collateralType: address(usdToken),
            amount: ctx.amountToWithdraw
        });
    }

    modifier givenTheAccountMeetsTheMarginRequirements() {
        _;
    }

    modifier givenTheAccountHaveAnOpenPosition() {
        _;
    }

    function test_RevertWhen_TheMarginBalanceUsdWithoutUnrealizedIsLessThanTheLiquidationFeeUsd()
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
        givenTheAccountMeetsTheMarginRequirements
        givenTheAccountHaveAnOpenPosition
    {
        uint256 amountToDeposit = 100e18;

        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));
        uint128 marketId = 0;
        int128 amountToCreateOrder = 10e18;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams(tradingAccountId, fuzzMarketConfig.marketId, amountToCreateOrder)
        );
        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });

        perpsEngine.fillMarketOrder(tradingAccountId, fuzzMarketConfig.marketId, mockSignedReport);

        //Price updated to make the position with enough profit so collateral can be withdrawn
        updateMockPriceFeed(uint128(fuzzMarketConfig.marketId), 2e23);

        // it should transfer the withdrawn amount to the sender
        changePrank({ msgSender: users.naruto.account });

        uint256 newMarginCollateralBalance = convertUd60x18ToTokenAmount(
            address(wstEth), perpsEngine.getAccountMarginCollateralBalance(tradingAccountId, address(wstEth))
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.NotEnoughCollateralForLiquidationFee.selector, LIQUIDATION_FEE_USD)
        });

        perpsEngine.withdrawMargin(tradingAccountId, address(wstEth), newMarginCollateralBalance);
    }

    function test_WhenTheMarginBalanceUsdWithoutUnrealizedPnlIsGreaterThanOrEqualTheLiquidationFeeUsd()
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
        givenTheAccountMeetsTheMarginRequirements
        givenTheAccountHaveAnOpenPosition
    {
        uint256 amountToDeposit = 100e18;

        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));
        uint128 marketId = 0;
        int128 amountToCreateOrder = 10e18;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams(tradingAccountId, fuzzMarketConfig.marketId, amountToCreateOrder)
        );
        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });

        perpsEngine.fillMarketOrder(tradingAccountId, fuzzMarketConfig.marketId, mockSignedReport);

        //Price updated to make the position with enough profit so collateral can be withdrawn
        updateMockPriceFeed(uint128(fuzzMarketConfig.marketId), 2e23);

        // it should transfer the withdrawn amount to the sender
        changePrank({ msgSender: users.naruto.account });

        uint256 newMarginCollateralBalance = convertUd60x18ToTokenAmount(
            address(wstEth), perpsEngine.getAccountMarginCollateralBalance(tradingAccountId, address(wstEth))
        );

        uint256 amountToWithdraw = newMarginCollateralBalance - LIQUIDATION_FEE_USD;

        // it should emit a {LogWithdrawMargin} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogWithdrawMargin(
            users.naruto.account, tradingAccountId, address(wstEth), amountToWithdraw
        );

        // it should transfer the withdrawn amount to the sender
        expectCallToTransfer(wstEth, users.naruto.account, amountToWithdraw);
        perpsEngine.withdrawMargin(tradingAccountId, address(wstEth), amountToWithdraw);

        uint256 expectedMargin =
            convertTokenAmountToUd60x18(address(wstEth), newMarginCollateralBalance - amountToWithdraw).intoUint256();
        newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(tradingAccountId, address(wstEth)).intoUint256();

        // it should decrease the margin collateral balance
        assertEq(expectedMargin, newMarginCollateralBalance, "withdrawMargin");
    }

    function testFuzz_GivenTheAccountDoesntHaveAnOpenPosition(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
        givenTheAccountMeetsTheMarginRequirements
    {
        // Test with wstEth that has 18 decimals

        amountToDeposit = bound({
            x: amountToDeposit,
            min: WSTETH_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18)
        });
        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: amountToDeposit });
        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));

        // it should emit a {LogWithdrawMargin} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogWithdrawMargin(
            users.naruto.account, tradingAccountId, address(wstEth), amountToWithdraw
        );

        // it should transfer the withdrawn amount to the sender
        expectCallToTransfer(wstEth, users.naruto.account, amountToWithdraw);
        perpsEngine.withdrawMargin(tradingAccountId, address(wstEth), amountToWithdraw);

        uint256 expectedMargin =
            convertTokenAmountToUd60x18(address(wstEth), amountToDeposit - amountToWithdraw).intoUint256();
        uint256 newMarginCollateralBalance = convertUd60x18ToTokenAmount(
            address(wstEth), perpsEngine.getAccountMarginCollateralBalance(tradingAccountId, address(wstEth))
        );

        // it should decrease the margin collateral balance
        assertEq(expectedMargin, newMarginCollateralBalance, "withdrawMargin");

        // Test with usdc that has 6 decimals

        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: amountToDeposit });
        deal({ token: address(usdc), to: users.naruto.account, give: amountToDeposit });

        tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdc));

        // it should emit a {LogWithdrawMargin} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogWithdrawMargin(
            users.naruto.account, tradingAccountId, address(usdc), amountToWithdraw
        );

        // it should transfer the withdrawn amount to the sender
        expectCallToTransfer(usdc, users.naruto.account, amountToWithdraw);
        perpsEngine.withdrawMargin(tradingAccountId, address(usdc), amountToWithdraw);

        expectedMargin = convertTokenAmountToUd60x18(address(usdc), amountToDeposit - amountToWithdraw).intoUint256();
        newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(tradingAccountId, address(usdc)).intoUint256();

        // it should decrease the margin collateral balance
        assertEq(expectedMargin, newMarginCollateralBalance, "withdrawMargin");
    }
}
