// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract Vault_Create_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertWhen_CreateIsPassedExistingVaultId(uint256 vaultId) external {
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateral = Collateral.Data({
            creditRatio: fuzzVaultConfig.creditRatio,
            priceAdapter: fuzzVaultConfig.priceAdapter,
            asset: fuzzVaultConfig.asset,
            isEnabled: fuzzVaultConfig.isEnabled,
            decimals: fuzzVaultConfig.decimals
        });

        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: fuzzVaultConfig.depositCap,
            withdrawalDelay: fuzzVaultConfig.withdrawalDelay,
            indexToken: fuzzVaultConfig.indexToken,
            collateral: collateral,
            depositFee: MOCK_DEPOSIT_FEE,
            redeemFee: MOCK_REDEEM_FEE,
            engine: address(perpsEngine)
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultAlreadyExists.selector, fuzzVaultConfig.vaultId));
        marketMakingEngine.exposed_Vault_create(params);
    }

    function testFuzz_WhenCreateIsPassedValidVaultId(uint256 vaultId) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateral = Collateral.Data({
            creditRatio: fuzzVaultConfig.creditRatio,
            priceAdapter: fuzzVaultConfig.priceAdapter,
            asset: fuzzVaultConfig.asset,
            isEnabled: fuzzVaultConfig.isEnabled,
            decimals: fuzzVaultConfig.decimals
        });

        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: fuzzVaultConfig.depositCap,
            withdrawalDelay: fuzzVaultConfig.withdrawalDelay,
            indexToken: fuzzVaultConfig.indexToken,
            collateral: collateral,
            depositFee: MOCK_DEPOSIT_FEE,
            redeemFee: MOCK_REDEEM_FEE,
            engine: address(perpsEngine)
        });

        // it should create new vault
        marketMakingEngine.exposed_Vault_create(params);
    }
}
