// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CheckLiquidatableAccounts_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_WhenTheBoundsAreZero() external {
        uint256 lowerBound = 0;
        uint256 upperBound = 0;

        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        // it should return an empty array
        assertEq(liquidatableAccountIds.length, 0);
    }

    function testFuzz_WhenTheresNoLiquidatableAccount(
        uint256 marketId,
        bool isLong,
        uint256 amountOfTradingAccounts
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 10 });
        uint256 marginValueUsd = 1_000_000e18 / amountOfTradingAccounts;
        uint256 initialMarginRate = fuzzMarketConfig.imr;

        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        for (uint256 i; i < amountOfTradingAccounts; i++) {
            uint256 accountMarginValueUsd = marginValueUsd / amountOfTradingAccounts;
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));
            openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);
        }

        uint256 lowerBound = 0;
        uint256 upperBound = amountOfTradingAccounts;

        // it should return an empty array
        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        // it should return an empty array
        for (uint256 i; i < liquidatableAccountIds.length; i++) {
            assertEq(liquidatableAccountIds[i], 0);
        }
    }

    function testFuzz_WhenThereAreOneOrManyLiquidatableAccounts(
        uint256 marketId,
        bool isLong,
        uint256 amountOfTradingAccounts,
        uint256 lowerBound,
        uint256 upperBound
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 10 });

        upperBound = bound({ x: upperBound, min: 1, max: amountOfTradingAccounts });

        lowerBound = bound({ x: lowerBound, min: 1, max: upperBound });

        uint256 marginValueUsd = 10_000e18 / amountOfTradingAccounts;
        uint256 initialMarginRate = fuzzMarketConfig.imr;

        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        for (uint256 i; i < amountOfTradingAccounts; i++) {
            uint256 accountMarginValueUsd = marginValueUsd / amountOfTradingAccounts;
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));

            openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);
        }
        setAccountsAsLiquidatable(fuzzMarketConfig, isLong);

        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        assertEq(liquidatableAccountIds.length, (upperBound - lowerBound) + 1);
        for (uint256 i; i < liquidatableAccountIds.length; i++) {
            // it should return an array with the liquidatable accounts ids
            assertEq(liquidatableAccountIds[i], lowerBound + i);
        }

        // create more trading accounts that will not open positions
        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        for (uint256 i; i < amountOfTradingAccounts; i++) {
            uint256 accountMarginValueUsd = marginValueUsd / amountOfTradingAccounts;
            createAccountAndDeposit(accountMarginValueUsd, address(usdToken));
        }

        // check to prevent panic array out of bounds
        liquidatableAccountIds =
            perpsEngine.checkLiquidatableAccounts(amountOfTradingAccounts + 1, amountOfTradingAccounts * 2);

        for (uint256 i; i < liquidatableAccountIds.length; i++) {
            assertEq(liquidatableAccountIds[i], 0);
        }
    }
}
