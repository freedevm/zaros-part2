// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { SD59x18 } from "@prb-math/SD59x18.sol";
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract CreditDelegationBranch_GetCreditCapacityForMarketId_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_TheMarketDoesNotExists() external {
        uint128 invalidMarketId = 0;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketId) });

        marketMakingEngine.getCreditCapacityForMarketId(invalidMarketId);
    }

    function testFuzz_WhenTheMarketExists(uint256 marketId) external {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        SD59x18 creditCapacity = marketMakingEngine.getCreditCapacityForMarketId(fuzzMarketConfig.marketId);

        SD59x18 totalDebtUsdX18 = marketMakingEngine.workaround_getTotalMarketDebt(fuzzMarketConfig.marketId);
        UD60x18 totalDelegatedCreditX18 =
            marketMakingEngine.workaround_getTotalDelegatedCreditUsd(fuzzMarketConfig.marketId);

        SD59x18 creditCapacityUsdX18 = totalDelegatedCreditX18.intoSD59x18().add(totalDebtUsdX18);

        // it should return the credit capacity
        assertEq(creditCapacityUsdX18.intoInt256(), creditCapacity.intoInt256());
    }
}
