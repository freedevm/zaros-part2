// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract GetAccountMarginRequirementUsdAndUnrealizedPnlUsd_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenPositionIsOpenedAndTargetMarketIdIsNotZero(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
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

        // open an existing position to enter the if check
        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        int256 sizeDelta = 100;

        // it should update cumulative outputs
        (
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 accountTotalUnrealizedPnlUsdX18
        ) = perpsEngine.exposed_getAccountMarginRequirementUsdAndUnrealizedPnlUsd(
            tradingAccountId, fuzzMarketConfig.marketId, sd59x18(sizeDelta)
        );

        assertNotEq(requiredInitialMarginUsdX18.intoUint256(), 0);
        assertNotEq(requiredMaintenanceMarginUsdX18.intoUint256(), 0);
        assertNotEq(accountTotalUnrealizedPnlUsdX18.intoUint256(), 0);
    }

    function testFuzz_WhenPositionIsOpenedAndTargetMarketIdIsZero(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
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

        // open an existing position to enter the if check
        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        int256 sizeDelta = 10_000;

        // it should update cumulative outputs
        (
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 accountTotalUnrealizedPnlUsdX18
        ) = perpsEngine.exposed_getAccountMarginRequirementUsdAndUnrealizedPnlUsd(
            tradingAccountId, 0, sd59x18(sizeDelta)
        );

        assertNotEq(requiredInitialMarginUsdX18.intoUint256(), 0);
        assertNotEq(requiredMaintenanceMarginUsdX18.intoUint256(), 0);
        assertEq(accountTotalUnrealizedPnlUsdX18.intoUint256(), 0);
    }

    function testFuzz_WhenPositionIsNotOpenedAndMarketIdIsNotZero(
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        int256 sizeDelta = 10_000;

        // it should update cumulative outputs
        (
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 accountTotalUnrealizedPnlUsdX18
        ) = perpsEngine.exposed_getAccountMarginRequirementUsdAndUnrealizedPnlUsd(
            tradingAccountId, fuzzMarketConfig.marketId, sd59x18(sizeDelta)
        );

        assertNotEq(requiredInitialMarginUsdX18.intoUint256(), 0);
        assertNotEq(requiredMaintenanceMarginUsdX18.intoUint256(), 0);
        assertEq(accountTotalUnrealizedPnlUsdX18.intoUint256(), 0);
    }

    function testFuzz_WhenPositionIsNotOpenedAndMarketIdIsZero(uint256 marginValueUsd) external {
        // it should update cumulative outputs and return zero

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        int256 sizeDelta = 100;

        // passing targetMarketId as 0
        // it should update cumulative outputs
        (
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 accountTotalUnrealizedPnlUsdX18
        ) = perpsEngine.exposed_getAccountMarginRequirementUsdAndUnrealizedPnlUsd(
            tradingAccountId, 0, sd59x18(sizeDelta)
        );

        assertEq(requiredInitialMarginUsdX18.intoUint256(), 0);
        assertEq(requiredMaintenanceMarginUsdX18.intoUint256(), 0);
        assertEq(accountTotalUnrealizedPnlUsdX18.intoUint256(), 0);
    }
}
