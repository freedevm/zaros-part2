// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract Position_IsNotionalValueIncreasing_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenANewPositionIsBeingCreated(
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

        bool isIncreased =
            perpsEngine.exposed_isNotionalValueIncreasing(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);
        // it should assert true
        assertEq(isIncreased, true);
    }

    function testFuzz_WhenSizeDeltaIsPositiveAndPositionSizeIsPositive(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // isLong should be true, not fuzzed
        bool isLong = true;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be positive, not fuzzed
        int128 sizeDelta = 10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased =
            perpsEngine.exposed_isNotionalValueIncreasing(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // it should assert true
        assertEq(isIncreased, true);
    }

    function testFuzz_WhenSizeDeltaIsNegativeAndPositionSizeIsNegative(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // isLong should be false, not fuzzed
        bool isLong = false;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be negative, not fuzzed
        int128 sizeDelta = -10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased =
            perpsEngine.exposed_isNotionalValueIncreasing(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // it should assert true
        assertEq(isIncreased, true);
    }

    function testFuzz_WhenSizeDeltaIsPositiveAndPositionSizeIsNegative(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // isLong should be false, not fuzzed
        bool isLong = false;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be positive, not fuzzed
        int128 sizeDelta = 10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased =
            perpsEngine.exposed_isNotionalValueIncreasing(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // it should assert false
        assertEq(isIncreased, false);
    }

    function testFuzz_WhenSizeDeltaIsNegativeAndPositionSizeIsPositive(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // isLong should be false, not fuzzed
        bool isLong = false;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be positive, not fuzzed
        int128 sizeDelta = 10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased =
            perpsEngine.exposed_isNotionalValueIncreasing(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // it should assert false
        assertEq(isIncreased, false);
    }

    function test_WhenPositionSizeIsPositiveAndPositionSizePlusSizeDeltaAbsoluteIsGreaterThanThePositionSizeAbsolute(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId,
        uint256 sizeDeltaAbs
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

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: true
        });

        Position.Data memory position = perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

        sizeDeltaAbs =
            bound({ x: sizeDeltaAbs, min: uint256(position.size * 2 + 1), max: uint256(position.size * 10_000) });

        int128 sizeDelta = -int128(int256(sizeDeltaAbs));

        assertEq(position.size > 0, true, "position.size should be greater than zero");
        assertEq(sizeDelta < 0, true, "sizeDelta should be less than zero");

        bool isIncreased =
            perpsEngine.exposed_isNotionalValueIncreasing(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // it should return true
        assertEq(isIncreased, true);
    }

    function test_WhenPositionSizeIsNegativeAndPositionSizePlusSizeDeltaAbsoluteIsGreaterThanThePositionSizeAbsolute(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId,
        uint256 sizeDeltaAbs
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

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: false
        });

        Position.Data memory position = perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

        sizeDeltaAbs =
            bound({ x: sizeDeltaAbs, min: uint256(-position.size * 2 + 1), max: uint256(-position.size * 10_000) });

        int128 sizeDelta = int128(int256(sizeDeltaAbs));

        assertEq(position.size < 0, true, "position.size should be less than zero");
        assertEq(sizeDelta > 0, true, "sizeDelta should be greater than zero");

        bool isIncreased =
            perpsEngine.exposed_isNotionalValueIncreasing(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // it should return true
        assertEq(isIncreased, true);
    }
}
