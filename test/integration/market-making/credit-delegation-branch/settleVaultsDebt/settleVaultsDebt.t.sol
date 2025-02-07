// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Errors } from "@zaros/utils/Errors.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

contract CreditDelegationBranch_SettleVaultsDebt_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultIdIsInvalid() external {
        uint256[] memory invalidVaultIds = new uint256[](1);
        invalidVaultIds[0] = INVALID_VAULT_ID;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector, INVALID_VAULT_ID));

        changePrank({ msgSender: address(perpsEngine) });
        marketMakingEngine.settleVaultsDebt(invalidVaultIds);
    }

    modifier whenVaultIdIsValid() {
        _;
    }

    function testFuzz_WhenVaultUnsettledRealizedDebtIsZero(
        uint256 vaultId,
        uint256 marketId
    )
        external
        whenVaultIdIsValid
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = fuzzMarketConfig.marketId;

        uint256[] memory vaultIds = new uint256[](1);
        vaultIds[0] = fuzzVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.connectVaultsAndMarkets(vaultIds, marketIds);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: 1e18 });

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 1e10);
        marketMakingEngine.workaround_Vault_setTotalCreditDelegationWeight(fuzzVaultConfig.vaultId, 1e9);

        // it should continue
        changePrank({ msgSender: address(perpsEngine) });
        marketMakingEngine.settleVaultsDebt(vaultIds);
    }

    function testFuzz_WhenTheVaultUnsettledRealizedDebtIsLessThanZero(
        uint256 vaultId,
        uint256 marketId,
        int128 debtAmount,
        uint128 adapterIndex
    )
        external
        whenVaultIdIsValid
    {
        // vm.assume(debtAmount < -1e13); // reasonable debt amount needed or reverts with ZeroOutputTokens
        debtAmount = -1e30;

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = fuzzMarketConfig.marketId;

        uint256[] memory vaultIds = new uint256[](1);
        vaultIds[0] = fuzzVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.connectVaultsAndMarkets(vaultIds, marketIds);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: 1e18 });

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 1e10);
        marketMakingEngine.workaround_Vault_setTotalCreditDelegationWeight(fuzzVaultConfig.vaultId, 1e9);

        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        // it should emit { LogSettleVaultDebt } event
        // vm.expectEmit();
        // emit Vault.LogUpdateVaultCreditCapacity(fuzzVaultConfig.vaultId, 0, 0, 0 ,0 ,0);

        deal({ token: address(fuzzVaultConfig.asset), to: address(marketMakingEngine), give: type(uint128).max });

        marketMakingEngine.workaround_setVaultDebt(fuzzVaultConfig.vaultId, debtAmount);

        marketMakingEngine.updateVaultSwapStrategy(
            fuzzVaultConfig.vaultId, "", "", adapter.STRATEGY_ID(), adapter.STRATEGY_ID()
        );

        uint256 usdcAvailableForEngineBefore = marketMakingEngine.getUsdTokenAvailableForEngine(address(perpsEngine));

        changePrank({ msgSender: address(perpsEngine) });
        marketMakingEngine.settleVaultsDebt(vaultIds);

        uint256 usdcAvailableForEngineAfter = marketMakingEngine.getUsdTokenAvailableForEngine(address(perpsEngine));

        // it should increase the usdc available for engine amount
        assertGt(usdcAvailableForEngineAfter, usdcAvailableForEngineBefore);
    }

    function testFuzz_WhenTheVaultUnsettledRealizedDebtIsGreaterThanZero(
        uint256 vaultId,
        uint256 marketId,
        uint128 debtAmount,
        uint128 adapterIndex
    )
        external
        whenVaultIdIsValid
    {
        debtAmount = 1e30;

        uint128 depositedUsdc = 0.5e30;

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = fuzzMarketConfig.marketId;

        uint256[] memory vaultIds = new uint256[](1);
        vaultIds[0] = fuzzVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.connectVaultsAndMarkets(vaultIds, marketIds);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: 1e18 });

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 1e10);
        marketMakingEngine.workaround_Vault_setTotalCreditDelegationWeight(fuzzVaultConfig.vaultId, 1e9);

        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        // it should emit { LogSettleVaultDebt } event
        // vm.expectEmit();
        // emit Vault.LogUpdateVaultCreditCapacity(fuzzVaultConfig.vaultId, 0, 0, 0 ,0 ,0);

        deal({ token: address(fuzzVaultConfig.asset), to: address(marketMakingEngine), give: type(uint128).max });
        deal({ token: address(usdc), to: address(marketMakingEngine), give: type(uint128).max });

        marketMakingEngine.workaround_setVaultDebt(fuzzVaultConfig.vaultId, int128(debtAmount));
        marketMakingEngine.workaround_setVaultDepositedUsdc(fuzzVaultConfig.vaultId, depositedUsdc);

        marketMakingEngine.updateVaultSwapStrategy(
            fuzzVaultConfig.vaultId, "", "", adapter.STRATEGY_ID(), adapter.STRATEGY_ID()
        );

        uint256 vaultDepositedUsdcBefore =
            marketMakingEngine.workaround_getVaultDepositedUsdc(fuzzVaultConfig.vaultId);

        changePrank({ msgSender: address(perpsEngine) });
        marketMakingEngine.settleVaultsDebt(vaultIds);

        uint256 vaultDepositedUsdcAfter = marketMakingEngine.workaround_getVaultDepositedUsdc(fuzzVaultConfig.vaultId);

        // it should decrease vault deposited usd amount
        assertLt(vaultDepositedUsdcAfter, vaultDepositedUsdcBefore);
    }
}
