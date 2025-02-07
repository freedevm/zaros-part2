// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract ValidatePositionsLimit_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_UserActivePositionsIsGreaterThanOrEqualTheMaxPositionsPerAccount(
        uint256 marketId,
        bool isLong
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint256 maxPositionsPerAccount = perpsEngine.workaround_getMaxPositionsPerAccount();

        uint256 marginValueUsd = 10_000_000e18;
        uint256 marginValueUsdPerPosition = marginValueUsd / maxPositionsPerAccount;
        uint256 initialMarginRate = fuzzMarketConfig.imr;

        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        for (uint256 i; i < maxPositionsPerAccount - 1; i++) {
            openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsdPerPosition, isLong);

            fuzzMarketConfig = getFuzzMarketConfig(fuzzMarketConfig.marketId + 1);
            initialMarginRate = fuzzMarketConfig.imr;
        }

        uint256 activeMarketsLength = perpsEngine.workaround_getActiveMarketsIdsLength(tradingAccountId);

        assertEq(
            activeMarketsLength,
            maxPositionsPerAccount - 1,
            "active markets length should be equal to maxPositionsPerAccount - 1"
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.MaxPositionsPerAccountReached.selector, maxPositionsPerAccount - 1, maxPositionsPerAccount
            )
        });

        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsdPerPosition, isLong);
    }

    function testFuzz_WhenUserActivePositionsIsLessThanTheMaxPositionsPerAccount(
        uint256 marketId,
        bool isLong
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint256 maxPositionsPerAccount = perpsEngine.workaround_getMaxPositionsPerAccount();
        assertEq(maxPositionsPerAccount > 0, true, "maxPositionsPerAccount should be greater than 0");

        uint256 marginValueUsd = 10_000_000e18;
        uint256 initialMarginRate = fuzzMarketConfig.imr;

        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        // it should not revert
        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);
    }
}
