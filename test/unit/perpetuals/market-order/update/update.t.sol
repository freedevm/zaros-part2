// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract Update_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenTheFunctionIsPassedZeroValues(uint128 tradingAccountId) external {
        MarketOrder.Data memory marketOrder = perpsEngine.exposed_MarketOrder_load(tradingAccountId);
        assertEq(marketOrder.marketId, 0);
        assertEq(marketOrder.sizeDelta, 0);
        assertEq(marketOrder.timestamp, 0);

        // it should do nothing
        perpsEngine.exposed_update(tradingAccountId, 0, 0);

        // assert that the values are updated
        marketOrder = perpsEngine.exposed_MarketOrder_load(tradingAccountId);
        assertEq(marketOrder.marketId, 0);
        assertEq(marketOrder.sizeDelta, 0);
        assertEq(marketOrder.timestamp, block.timestamp);
    }

    function testFuzz_WhenTheFunctionIsPassedNon_zeroValues(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId,
        bool isLong
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

        // it should update the values
        perpsEngine.exposed_update(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // assert that the values are updated
        MarketOrder.Data memory marketOrder = perpsEngine.exposed_MarketOrder_load(tradingAccountId);
        assertEq(marketOrder.marketId, fuzzMarketConfig.marketId);
        assertEq(marketOrder.sizeDelta, sizeDelta);
        assertEq(marketOrder.timestamp, block.timestamp);
    }
}
