// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

contract UpdateVaultConfiguration_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
    }

    function testFuzz_RevertWhen_TheDepositCapIsZero(uint256 vaultId, bool isLive) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: 0,
            withdrawalDelay: fuzzVaultConfig.withdrawalDelay,
            isLive: isLive,
            lockedCreditRatio: 0
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "depositCap"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    modifier whenTheDepositCapIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_WithdrawalDelayIsZero(
        uint256 vaultId,
        bool isLive
    )
        external
        whenTheDepositCapIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: fuzzVaultConfig.depositCap,
            withdrawalDelay: 0,
            isLive: isLive,
            lockedCreditRatio: 0
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "withdrawDelay"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    modifier whenWithdrawalDelayIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_VaultIdIsZero(
        uint256 depositCap,
        uint256 withdrawDelay,
        bool isLive
    )
        external
        whenTheDepositCapIsNotZero
        whenWithdrawalDelayIsNotZero
    {
        depositCap = bound({ x: depositCap, min: 1, max: type(uint128).max });
        withdrawDelay = bound({ x: withdrawDelay, min: 1, max: type(uint128).max });

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: 0,
            depositCap: uint128(depositCap),
            withdrawalDelay: uint128(withdrawDelay),
            isLive: isLive,
            lockedCreditRatio: 0
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    function testFuzz_WhenVaultIdIsNotZero(
        uint256 vaultId,
        uint256 updatedDepositCap,
        uint256 updatedWithdrawDelay,
        bool isLive
    )
        external
        whenTheDepositCapIsNotZero
        whenWithdrawalDelayIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        updatedDepositCap = bound({ x: updatedDepositCap, min: 1, max: type(uint128).max });
        updatedWithdrawDelay = bound({ x: updatedWithdrawDelay, min: 1, max: type(uint128).max });

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: uint128(updatedDepositCap),
            withdrawalDelay: uint128(updatedWithdrawDelay),
            isLive: isLive,
            lockedCreditRatio: 0
        });

        // it should emit update event
        vm.expectEmit();
        emit MarketMakingEngineConfigurationBranch.LogUpdateVaultConfiguration(
            users.owner.account, fuzzVaultConfig.vaultId
        );
        marketMakingEngine.updateVaultConfiguration(params);

        // it should update vault
        assertEq(updatedDepositCap, marketMakingEngine.workaround_Vault_getDepositCap(fuzzVaultConfig.vaultId));
        assertEq(updatedWithdrawDelay, marketMakingEngine.workaround_Vault_getWithdrawDelay(fuzzVaultConfig.vaultId));
        assertEq(isLive, marketMakingEngine.workaround_Vault_getIsLive(fuzzVaultConfig.vaultId));
    }
}
