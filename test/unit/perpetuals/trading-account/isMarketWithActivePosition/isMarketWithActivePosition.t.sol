// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract IsMarketWithActivePosition_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenTheMarketHasActivePositions(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint128 marketId,
        bool isLong
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // open an existing position to enter the if check
        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        // it should return true
        bool _isMarketWithActivePosition =
            perpsEngine.exposed_isMarketWithActivePosition(tradingAccountId, fuzzMarketConfig.marketId);

        assertEq(_isMarketWithActivePosition, true, "market should have active position");
    }

    function testFuzz_WhenTheMarketHasNoActivePositions(uint256 marginValueUsd, uint128 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // it should return false
        bool _isMarketWithActivePosition =
            perpsEngine.exposed_isMarketWithActivePosition(tradingAccountId, fuzzMarketConfig.marketId);

        assertEq(_isMarketWithActivePosition, false, "market should have active position");
    }
}
