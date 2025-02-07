// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract Create_Unit_Test is Base_Test {
    function testFuzz_WhenTheCreateIsCalled(uint128 tradingAccountId, address owner) external {
        vm.assume(owner != address(0));

        changePrank({ msgSender: owner });

        perpsEngine.exposed_create(tradingAccountId, owner);

        // it should create the trading account
        perpsEngine.exposed_loadExistingAccountAndVerifySender(tradingAccountId);

        (uint128 tradingAccountIdReceived, address ownerReceived) =
            perpsEngine.workaround_getTradingAccountIdAndOwner(tradingAccountId);

        // it should save the trading account id
        assertEq(tradingAccountId, tradingAccountIdReceived, "trading account id is not correct");

        // it should save the owner
        assertEq(owner, ownerReceived, "owner is not correct");
    }
}
