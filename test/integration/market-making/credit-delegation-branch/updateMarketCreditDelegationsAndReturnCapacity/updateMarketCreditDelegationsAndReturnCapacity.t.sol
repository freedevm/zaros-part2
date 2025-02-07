// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

// PRB Math dependencies
import { SD59x18 } from "@prb-math/SD59x18.sol";
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract CreditDelegationBranch_UpdateMarketCreditDelegationsAndReturnCapacity_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureSystemParameters();
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenUpdateMarketCreditDelegationsAndReturnCapacityIsCalled(uint256 marketId) external {
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // it should emit { LogUpdateVaultCreditCapacity } event
        vm.expectEmit();
        emit Vault.LogUpdateVaultCreditCapacity(INITIAL_VAULT_ID, 0, 0, 0, 0, 0);

        SD59x18 creditCapacityX18 =
            marketMakingEngine.updateMarketCreditDelegationsAndReturnCapacity(fuzzPerpMarketCreditConfig.marketId);

        UD60x18 marketDelegatedCreditX18 =
            marketMakingEngine.workaround_getTotalDelegatedCreditUsd(fuzzPerpMarketCreditConfig.marketId);
        SD59x18 totalMarketDebtX18 =
            marketMakingEngine.workaround_getTotalMarketDebt(fuzzPerpMarketCreditConfig.marketId);
        SD59x18 expectedCreditCapacityX18 = marketDelegatedCreditX18.intoSD59x18().add(totalMarketDebtX18);

        // it should return market credit capacity
        assertEq(expectedCreditCapacityX18.intoInt256(), creditCapacityX18.intoInt256());
    }
}
