// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

contract CreditDelegationBranch_UpdateMarketCreditDelegations_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureSystemParameters();
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenUpdateMarketCreditDelegationsIsCalled(uint256 marketId) external {
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // it should emit { LogUpdateVaultCreditCapacity } event
        vm.expectEmit();
        emit Vault.LogUpdateVaultCreditCapacity(INITIAL_VAULT_ID, 0, 0, 0, 0, 0);

        marketMakingEngine.updateMarketCreditDelegations(fuzzPerpMarketCreditConfig.marketId);
    }
}
