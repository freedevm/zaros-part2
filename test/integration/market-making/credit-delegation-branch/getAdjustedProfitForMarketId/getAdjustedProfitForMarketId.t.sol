// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { SD59x18 } from "@prb-math/SD59x18.sol";
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract CreditDelegationBranch_GetAdjustedProfitForMarketId_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_TheMarketIsNotLive(uint256 profitUsd) external {
        uint128 invalidMarketId = 0;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketId));

        marketMakingEngine.getAdjustedProfitForMarketId(invalidMarketId, profitUsd);
    }

    modifier whenTheMarketIsLive() {
        _;
    }

    function test_RevertWhen_TheCreditCapacityIsLessThanOrEqualToZero(
        uint256 marketId,
        uint256 profitUsd
    )
        external
        whenTheMarketIsLive
    {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        // set the market delegated credit to zero
        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 0);

        SD59x18 creditCapacityUsdX18 = marketMakingEngine.getCreditCapacityForMarketId(fuzzMarketConfig.marketId);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InsufficientCreditCapacity.selector,
                fuzzMarketConfig.marketId,
                creditCapacityUsdX18.intoInt256()
            )
        );

        marketMakingEngine.getAdjustedProfitForMarketId(fuzzMarketConfig.marketId, profitUsd);
    }

    modifier whenTheCreditCapacityIsGreaterThanZero() {
        _;
    }

    function test_WhenTheAutoDeleverageFactorIsNotTriggered(
        uint256 marketId,
        uint256 profitUsd
    )
        external
        whenTheMarketIsLive
        whenTheCreditCapacityIsGreaterThanZero
    {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        UD60x18 adjustedProfitUsdX18 =
            marketMakingEngine.getAdjustedProfitForMarketId(fuzzMarketConfig.marketId, profitUsd);

        // it should return the adjusted profit
        assertEq(profitUsd, adjustedProfitUsdX18.intoUint256());
    }

    function test_WhenTheAutoDeleverageFactorIsTriggered(
        uint256 marketId,
        uint256 profitUsd
    )
        external
        whenTheMarketIsLive
        whenTheCreditCapacityIsGreaterThanZero
    {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        marketMakingEngine.workaround_setMarketUsdTokenIssuance(fuzzMarketConfig.marketId, 5e9 + 10);

        UD60x18 delegatedCreditUsdX18 =
            marketMakingEngine.workaround_getTotalDelegatedCreditUsd(fuzzMarketConfig.marketId);
        SD59x18 totalDebtUsdX18 = marketMakingEngine.workaround_getTotalMarketDebt(fuzzMarketConfig.marketId);

        UD60x18 autoDeleverageFactorX18 = marketMakingEngine.workaround_getAutoDeleverageFactor(
            fuzzMarketConfig.marketId, delegatedCreditUsdX18, totalDebtUsdX18
        );

        UD60x18 adjustedProfitUsdX18 =
            marketMakingEngine.getAdjustedProfitForMarketId(fuzzMarketConfig.marketId, profitUsd);

        // it should return the adjusted profit
        assertEq(ud60x18(profitUsd).mul(autoDeleverageFactorX18).intoUint256(), adjustedProfitUsdX18.intoUint256());
    }
}
