// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract GetAccountLeverage_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_GivenTheMarginBalanceUsdX18IsZero(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
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

        UD60x18 accountLeverage = perpsEngine.getAccountLeverage(tradingAccountId);

        // it should stop execution and return zero in UD60x18 format
        assertEq(accountLeverage.intoUint256(), 0);
    }

    function testFuzz_GivenTheMarginBalanceUsdX18IsNotZero(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 numOfActiveMarkets
    )
        external
    {
        numOfActiveMarkets = bound({ x: numOfActiveMarkets, min: 1, max: (FINAL_MARKET_ID - INITIAL_MARKET_ID) + 1 });

        MarketConfig memory fuzzMarketConfig;

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN * numOfActiveMarkets,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        uint256 amountPerPosition = marginValueUsd / numOfActiveMarkets;

        UD60x18 totalPositionsNotionalValue;

        uint256[2] memory marketsIdsRange;

        for (uint256 i = 1; i <= numOfActiveMarkets; i++) {
            marketsIdsRange[0] = i;
            marketsIdsRange[1] = i;

            fuzzMarketConfig = getFilteredMarketsConfig(marketsIdsRange)[0];

            initialMarginRate =
                bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

            openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, amountPerPosition, isLong);

            Position.Data memory position =
                perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

            UD60x18 indexPrice = perpsEngine.exposed_getIndexPrice(fuzzMarketConfig.marketId);

            UD60x18 markPrice =
                perpsEngine.exposed_getMarkPrice(fuzzMarketConfig.marketId, sd59x18(position.size), indexPrice);

            UD60x18 positionNotionalValueX18 =
                perpsEngine.exposed_getNotionalValue(tradingAccountId, fuzzMarketConfig.marketId, markPrice);

            totalPositionsNotionalValue = totalPositionsNotionalValue.add(positionNotionalValueX18);
        }

        UD60x18 accountLeverage = perpsEngine.getAccountLeverage(tradingAccountId);

        (SD59x18 marginBalanceUsdX18,,,) = perpsEngine.getAccountMarginBreakdown(tradingAccountId);

        UD60x18 expectedAccountLeverage =
            totalPositionsNotionalValue.intoSD59x18().div(marginBalanceUsdX18).intoUD60x18();

        // it should continue execution and return the current leverage of trading account account
        assertAlmostEq(
            accountLeverage.intoUint256(), expectedAccountLeverage.intoUint256(), 15 * 10 ** 10, "account leverage"
        );
    }
}
