// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract Stake_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_QualityOfSharesIsLessThanMinAmount(uint128 vaultId, uint128 assetsToDeposit) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap));

        fundUserAndDepositInVault(users.naruto.account, fuzzVaultConfig.vaultId, assetsToDeposit);

        uint128 stakeAmount = uint128(IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account));

        stakeAmount = uint128(bound(assetsToDeposit, 0, Constants.MIN_OF_SHARES_TO_STAKE - 1));

        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.QuantityOfSharesLessThanTheMinimumAllowed.selector,
                Constants.MIN_OF_SHARES_TO_STAKE,
                stakeAmount
            )
        );

        marketMakingEngine.stake(fuzzVaultConfig.vaultId, stakeAmount);
    }

    modifier whenQualityOfSharesIsMoreThanMinAmount() {
        _;
    }

    function testFuzz_RevertWhen_VaultIsInvalid(uint128 sharesToStake)
        external
        whenQualityOfSharesIsMoreThanMinAmount
    {
        // it should revert
        vm.expectRevert();
        marketMakingEngine.stake(INVALID_VAULT_ID, sharesToStake);
    }

    struct StakeState {
        // vault balances
        uint128 stakerVaultBal;
        uint128 marketEngineVaultBal;
        // Distribution stake total balances
        uint128 totalShares;
        int256 valuePerShare;
        // Distribution stake individual balances
        uint128 stakerShares;
        int256 stakerLastValuePerShare;
    }

    function _getStakeState(
        address staker,
        uint128 vaultId,
        IERC20 vault
    )
        internal
        view
        returns (StakeState memory state)
    {
        state.stakerVaultBal = uint128(vault.balanceOf(staker));
        state.marketEngineVaultBal = uint128(vault.balanceOf(address(marketMakingEngine)));

        (state.totalShares, state.valuePerShare, state.stakerShares, state.stakerLastValuePerShare) =
            marketMakingEngine.getTotalAndAccountStakingData(vaultId, staker);
    }

    function test_WhenVaultIdIsValid(
        uint128 vaultId,
        uint128 assetsToDeposit
    )
        external
        whenQualityOfSharesIsMoreThanMinAmount
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre state
        StakeState memory pre = _getStakeState(user, vaultId, IERC20(fuzzVaultConfig.indexToken));
        assertGt(pre.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");
        assertEq(pre.marketEngineVaultBal, 0, "MarketEngine has no vault shares");
        assertEq(pre.totalShares, 0, "Staking totalShares 0 as no stakers");
        assertEq(pre.valuePerShare, 0, "Staking valuePerShare 0 as no stakers and no value distributed");
        assertEq(pre.stakerShares, 0, "Staker has no staking shares prior to staking");
        assertEq(pre.stakerLastValuePerShare, 0, "Staker has no value per share prior to staking");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, pre.stakerVaultBal);

        // save and verify post state
        StakeState memory post = _getStakeState(user, vaultId, IERC20(fuzzVaultConfig.indexToken));
        assertEq(post.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(post.marketEngineVaultBal, pre.stakerVaultBal, "MarketEngine received stakers vault shares");
        assertEq(post.totalShares, pre.stakerVaultBal, "Staking totalShares == staked vault balance");
        assertEq(post.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");
        assertEq(post.stakerShares, pre.stakerVaultBal, "Staker shares == staked vault balance");
        assertEq(post.stakerLastValuePerShare, 0, "Staker has no value per share as no value distributed");
    }
}
