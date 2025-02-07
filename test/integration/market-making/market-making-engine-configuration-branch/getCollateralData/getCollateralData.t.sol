// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

contract MarketMakingEngineConfigurationBranch_GetCollateralData_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        changePrank({ msgSender: users.naruto.account });
    }

    function test_WhenGetCollateralDataIsCalled(uint256 vaultId) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateral = marketMakingEngine.getCollateralData(fuzzVaultConfig.asset);

        // it should return the collateral data
        assertEq(collateral.asset, fuzzVaultConfig.asset);
    }
}
