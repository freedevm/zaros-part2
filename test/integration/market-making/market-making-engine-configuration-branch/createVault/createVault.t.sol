// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

contract MarketMakingEngineConfigurationBranch_CreateVault_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertWhen_TheIndexTokenAddressIsZero(uint128 vaultId) external {
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
            indexToken: address(0),
            collateral: collateral,
            depositFee: MOCK_DEPOSIT_FEE,
            redeemFee: MOCK_REDEEM_FEE,
            engine: address(perpsEngine)
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "indexToken"));
        marketMakingEngine.createVault(params);
    }

    modifier whenTheIndexTokenAddressIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheDepositCapIsZero(uint128 vaultId) external whenTheIndexTokenAddressIsNotZero {
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
            depositCap: 0,
            withdrawalDelay: fuzzVaultConfig.withdrawalDelay,
            indexToken: fuzzVaultConfig.indexToken,
            collateral: collateral,
            depositFee: MOCK_DEPOSIT_FEE,
            redeemFee: MOCK_REDEEM_FEE,
            engine: address(perpsEngine)
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "depositCap"));
        marketMakingEngine.createVault(params);
    }

    modifier whenTheDepositCapIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_WithdrawalDelayIsZero(uint128 vaultId)
        external
        whenTheIndexTokenAddressIsNotZero
        whenTheDepositCapIsNotZero
    {
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
            withdrawalDelay: 0,
            indexToken: fuzzVaultConfig.indexToken,
            collateral: collateral,
            depositFee: MOCK_DEPOSIT_FEE,
            redeemFee: MOCK_REDEEM_FEE,
            engine: address(perpsEngine)
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "withdrawDelay"));
        marketMakingEngine.createVault(params);
    }

    modifier whenWithdrawalDelayIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_VaultIdIsZero(uint128 vaultId)
        external
        whenTheIndexTokenAddressIsNotZero
        whenTheDepositCapIsNotZero
        whenWithdrawalDelayIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateral = Collateral.Data({
            creditRatio: fuzzVaultConfig.creditRatio,
            priceAdapter: fuzzVaultConfig.priceAdapter,
            asset: fuzzVaultConfig.asset,
            isEnabled: fuzzVaultConfig.isEnabled,
            decimals: fuzzVaultConfig.decimals
        });

        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: 0,
            depositCap: fuzzVaultConfig.depositCap,
            withdrawalDelay: fuzzVaultConfig.withdrawalDelay,
            indexToken: fuzzVaultConfig.indexToken,
            collateral: collateral,
            depositFee: MOCK_DEPOSIT_FEE,
            redeemFee: MOCK_REDEEM_FEE,
            engine: address(perpsEngine)
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId"));
        marketMakingEngine.createVault(params);
    }

    modifier whenVaultIdIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_EngineIsZero(uint128 vaultId)
        external
        whenTheIndexTokenAddressIsNotZero
        whenTheDepositCapIsNotZero
        whenWithdrawalDelayIsNotZero
        whenVaultIdIsNotZero
    {
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
            engine: address(0)
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "engine"));
        marketMakingEngine.createVault(params);
    }

    modifier whenEngineIsNotZero() {
        _;
    }

    function test_RevertGiven_VaultWithThatIdAlreadyExists(uint128 vaultId)
        external
        whenTheIndexTokenAddressIsNotZero
        whenTheDepositCapIsNotZero
        whenWithdrawalDelayIsNotZero
        whenVaultIdIsNotZero
        whenEngineIsNotZero
    {
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
        marketMakingEngine.createVault(params);
    }

    function test_GivenTheVaultDoesNotExist(uint128 vaultId)
        external
        whenTheIndexTokenAddressIsNotZero
        whenTheDepositCapIsNotZero
        whenWithdrawalDelayIsNotZero
        whenVaultIdIsNotZero
        whenEngineIsNotZero
    {
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

        // it should emit event
        vm.expectEmit();
        emit MarketMakingEngineConfigurationBranch.LogCreateVault(users.owner.account, fuzzVaultConfig.vaultId);
        marketMakingEngine.createVault(params);

        // it should create vault
        assertEq(
            fuzzVaultConfig.indexToken, marketMakingEngine.workaround_Vault_getIndexToken(fuzzVaultConfig.vaultId)
        );
    }
}
