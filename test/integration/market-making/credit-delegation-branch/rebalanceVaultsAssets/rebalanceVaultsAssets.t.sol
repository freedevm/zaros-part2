// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

contract CreditDelegationBranch_RebalanceVaultsAssets_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    function testFuzz_RevertWhen_TheIndebtVaultAndIncreditVaultsEnginesMismatch(
        uint256 inCreditVaultId,
        uint256 inDebtVaultId
    )
        external
    {
        VaultConfig memory inCreditVaultConfig = getFuzzVaultConfig(inCreditVaultId);
        VaultConfig memory inDebtVaultConfig = getFuzzVaultConfig(inDebtVaultId);

        vm.assume(inCreditVaultConfig.vaultId != inDebtVaultConfig.vaultId);

        uint128[2] memory vaultIds;

        vaultIds[0] = inCreditVaultConfig.vaultId;
        vaultIds[1] = inDebtVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.setVaultEngine(inCreditVaultConfig.vaultId, address(1));
        marketMakingEngine.setVaultEngine(inDebtVaultConfig.vaultId, address(2));

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultsConnectedToDifferentEngines.selector));

        marketMakingEngine.rebalanceVaultsAssets(vaultIds);
    }

    modifier whenTheIndebtVaultAndIncreditVaultsEnginesMatch() {
        _;
    }

    function testFuzz_RevertWhen_TheIncreditVaultUnsettledRealizedDebtIsLessThanZero(
        uint256 inCreditVaultId,
        uint256 inDebtVaultId
    )
        external
        whenTheIndebtVaultAndIncreditVaultsEnginesMatch
    {
        VaultConfig memory inCreditVaultConfig = getFuzzVaultConfig(inCreditVaultId);
        VaultConfig memory inDebtVaultConfig = getFuzzVaultConfig(inDebtVaultId);

        vm.assume(inCreditVaultConfig.vaultId != inDebtVaultConfig.vaultId);

        uint128[2] memory vaultIds;

        vaultIds[0] = inCreditVaultConfig.vaultId;
        vaultIds[1] = inDebtVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.setVaultEngine(inCreditVaultConfig.vaultId, address(1));
        marketMakingEngine.setVaultEngine(inDebtVaultConfig.vaultId, address(1));

        marketMakingEngine.workaround_setVaultDebt(inCreditVaultConfig.vaultId, 0);
        marketMakingEngine.workaround_setVaultDepositedUsdc(inCreditVaultConfig.vaultId, 1e11);

        marketMakingEngine.workaround_setVaultDebt(inDebtVaultConfig.vaultId, -1e11);
        marketMakingEngine.workaround_setVaultDepositedUsdc(inDebtVaultConfig.vaultId, 0);

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidVaultDebtSettlementRequest.selector));

        marketMakingEngine.rebalanceVaultsAssets(vaultIds);
    }

    modifier whenTheIncreditVaultUnsettledRealizedDebtIsMoreThanZero() {
        _;
    }

    function testFuzz_RevertWhen_TheIndebtVaultUnsettledRealizedDebtIsMoreThanOrEqualToZero(
        uint256 inCreditVaultId,
        uint256 inDebtVaultId
    )
        external
        whenTheIndebtVaultAndIncreditVaultsEnginesMatch
        whenTheIncreditVaultUnsettledRealizedDebtIsMoreThanZero
    {
        VaultConfig memory inCreditVaultConfig = getFuzzVaultConfig(inCreditVaultId);
        VaultConfig memory inDebtVaultConfig = getFuzzVaultConfig(inDebtVaultId);

        vm.assume(inCreditVaultConfig.vaultId != inDebtVaultConfig.vaultId);

        uint128[2] memory vaultIds;

        vaultIds[0] = inCreditVaultConfig.vaultId;
        vaultIds[1] = inDebtVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.setVaultEngine(inCreditVaultConfig.vaultId, address(1));
        marketMakingEngine.setVaultEngine(inDebtVaultConfig.vaultId, address(1));

        marketMakingEngine.workaround_setVaultDebt(inCreditVaultConfig.vaultId, 1e11);
        marketMakingEngine.workaround_setVaultDepositedUsdc(inCreditVaultConfig.vaultId, 0);

        marketMakingEngine.workaround_setVaultDebt(inDebtVaultConfig.vaultId, 1e11);
        marketMakingEngine.workaround_setVaultDepositedUsdc(inDebtVaultConfig.vaultId, 0);

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidVaultDebtSettlementRequest.selector));

        marketMakingEngine.rebalanceVaultsAssets(vaultIds);
    }

    function testFuzz_WhenTheIndebtVaultUnsettledRealizedDebtIsLessThanZero(
        uint256 inCreditVaultId,
        uint256 inDebtVaultId,
        uint256 adapterIndex
    )
        external
        whenTheIndebtVaultAndIncreditVaultsEnginesMatch
        whenTheIncreditVaultUnsettledRealizedDebtIsMoreThanZero
    {
        VaultConfig memory inCreditVaultConfig = getFuzzVaultConfig(inCreditVaultId);
        VaultConfig memory inDebtVaultConfig = getFuzzVaultConfig(inDebtVaultId);

        vm.assume(inCreditVaultConfig.vaultId != inDebtVaultConfig.vaultId);

        uint128[2] memory vaultIds;

        vaultIds[0] = inCreditVaultConfig.vaultId;
        vaultIds[1] = inDebtVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });

        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);
        marketMakingEngine.updateVaultSwapStrategy(
            inCreditVaultConfig.vaultId, "", "", adapter.STRATEGY_ID(), adapter.STRATEGY_ID()
        );
        marketMakingEngine.updateVaultSwapStrategy(
            inDebtVaultConfig.vaultId, "", "", adapter.STRATEGY_ID(), adapter.STRATEGY_ID()
        );

        marketMakingEngine.setVaultEngine(inCreditVaultConfig.vaultId, address(1));
        marketMakingEngine.setVaultEngine(inDebtVaultConfig.vaultId, address(1));

        marketMakingEngine.workaround_setVaultDebt(inCreditVaultConfig.vaultId, 2e24);
        marketMakingEngine.workaround_setVaultDepositedUsdc(inCreditVaultConfig.vaultId, 0);

        marketMakingEngine.workaround_setVaultDebt(inDebtVaultConfig.vaultId, -1e24);
        marketMakingEngine.workaround_setVaultDepositedUsdc(inDebtVaultConfig.vaultId, 2e24);

        deal({
            token: address(inDebtVaultConfig.asset),
            to: address(inDebtVaultConfig.indexToken),
            give: type(uint96).max
        });

        deal({ token: address(inDebtVaultConfig.asset), to: address(marketMakingEngine), give: type(uint96).max });

        changePrank({ msgSender: address(perpsEngine) });

        uint128 inDebtVaultDepositedUsdcBefore =
            marketMakingEngine.workaround_getVaultDepositedUsdc(inDebtVaultConfig.vaultId);
        uint128 inCreditVaultDepositedUsdcBefore =
            marketMakingEngine.workaround_getVaultDepositedUsdc(inCreditVaultConfig.vaultId);

        int128 inDebtVaultDeptBefore = marketMakingEngine.workaround_getVaultDebt(inDebtVaultConfig.vaultId);
        int128 inCreditVaultDebtBefore = marketMakingEngine.workaround_getVaultDebt(inCreditVaultConfig.vaultId);

        // it should emit { LogRebalanceVaultsAssets } event
        vm.expectEmit();
        emit CreditDelegationBranch.LogRebalanceVaultsAssets(
            inCreditVaultConfig.vaultId, inDebtVaultConfig.vaultId, 2e24
        );

        marketMakingEngine.rebalanceVaultsAssets(vaultIds);

        uint128 inDebtVaultDepositedUsdcAfter =
            marketMakingEngine.workaround_getVaultDepositedUsdc(inDebtVaultConfig.vaultId);
        uint128 inCreditVaultDepositedUsdcAfter =
            marketMakingEngine.workaround_getVaultDepositedUsdc(inCreditVaultConfig.vaultId);

        int128 inDebtVaultDeptAfter = marketMakingEngine.workaround_getVaultDebt(inDebtVaultConfig.vaultId);
        int128 inCreditVaultDebtAfter = marketMakingEngine.workaround_getVaultDebt(inCreditVaultConfig.vaultId);

        // it should update vaults deposited usd and markets realized debt
        assertEq(
            inDebtVaultDepositedUsdcBefore - convertTokenAmountToUd60x18(address(usdc), 2e12).intoUint256(),
            inDebtVaultDepositedUsdcAfter
        );
        assertEq(inCreditVaultDepositedUsdcBefore + 2e24, inCreditVaultDepositedUsdcAfter);

        assertEq(inDebtVaultDeptBefore - 2e24, inDebtVaultDeptAfter, "inDebtvault debt mismatch");
        assertEq(inCreditVaultDebtBefore + 2e24, inCreditVaultDebtAfter, "inCreditVault debt mismatch");
    }
}
