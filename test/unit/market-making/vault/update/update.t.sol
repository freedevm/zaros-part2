// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract Vault_Update_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function test_RevertWhen_UpdateIsPassedZeroId() external {
        Vault.UpdateParams memory params =
            Vault.UpdateParams({ vaultId: 0, depositCap: 1, withdrawalDelay: 1, isLive: true, lockedCreditRatio: 0 });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId"));
        marketMakingEngine.exposed_Vault_update(params);
    }
}
