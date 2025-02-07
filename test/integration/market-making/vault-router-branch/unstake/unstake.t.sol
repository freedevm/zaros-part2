// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract Unstake_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_UserHasPendingRewards() external {
        uint128 vaultId = WETH_CORE_VAULT_ID;

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        uint128 assetsToDeposit = uint128(calculateMinOfSharesToStake(fuzzVaultConfig.vaultId));
        fundUserAndDepositInVault(users.naruto.account, fuzzVaultConfig.vaultId, assetsToDeposit);

        uint256 userShares = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);

        changePrank({ msgSender: users.naruto.account });
        IERC20(fuzzVaultConfig.indexToken).approve(address(marketMakingEngine), userShares);
        marketMakingEngine.stake(fuzzVaultConfig.vaultId, uint128(userShares));

        uint256 marketFees = 1e18;
        deal(fuzzVaultConfig.asset, address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine), marketFees);
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });

        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        changePrank({ msgSender: users.naruto.account });

        bytes32 actorId = bytes32(uint256(uint160(address(users.naruto.account))));

        uint256 earnedFees = marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.UserHasPendingRewards.selector, actorId, earnedFees));

        marketMakingEngine.unstake(fuzzVaultConfig.vaultId, userShares);
    }

    modifier whenUserDoesntHavePendingRewards() {
        _;
    }

    function testFuzz_RevertWhen_UserDoesNotHaveEnoughStakedShares(
        uint256 vaultId,
        uint256 depositAmount
    )
        external
        whenUserDoesntHavePendingRewards
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        depositAmount = bound({
            x: depositAmount,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });

        depositAndStakeInVault(fuzzVaultConfig.vaultId, uint128(depositAmount));

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.NotEnoughShares.selector));
        marketMakingEngine.unstake(fuzzVaultConfig.vaultId, type(uint128).max);
    }

    function testFuzz_WhenUserHasEnoughStakedShares(
        uint256 vaultId,
        uint256 depositAmount
    )
        external
        whenUserDoesntHavePendingRewards
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        depositAmount = bound({
            x: depositAmount,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });

        depositAndStakeInVault(fuzzVaultConfig.vaultId, uint128(depositAmount));

        uint256 actorShares =
            marketMakingEngine.getStakedSharesOfAccount(fuzzVaultConfig.vaultId, users.naruto.account);

        // it should log unstake event
        vm.expectEmit();
        emit VaultRouterBranch.LogUnstake(fuzzVaultConfig.vaultId, users.naruto.account, actorShares);
        marketMakingEngine.unstake(fuzzVaultConfig.vaultId, actorShares);

        uint256 userBalanceAfter = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);
        assertEq(userBalanceAfter, actorShares);
    }

    struct UnstakeState {
        // asset balances
        uint256 stakerAssetBal;
        uint256 vaultAssetBal;
        uint256 marketEngineAssetBal;
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

    function _getUnstakeState(
        address staker,
        uint128 vaultId,
        IERC20 assetToken,
        IERC20 vault
    )
        internal
        view
        returns (UnstakeState memory state)
    {
        state.stakerAssetBal = assetToken.balanceOf(staker);
        state.vaultAssetBal = assetToken.balanceOf(address(vault));
        state.marketEngineAssetBal = assetToken.balanceOf(address(marketMakingEngine));

        state.stakerVaultBal = uint128(vault.balanceOf(staker));
        state.marketEngineVaultBal = uint128(vault.balanceOf(address(marketMakingEngine)));

        (state.totalShares, state.valuePerShare, state.stakerShares, state.stakerLastValuePerShare) =
            marketMakingEngine.getTotalAndAccountStakingData(vaultId, staker);
    }

    // a staker's unclaimed rewards appear to double every time
    // `Vault.recalculateVaultsCreditCapacity` is called
    function test_stakerUnclaimedRewardsNoDoubleAfterDeposit() external {
        // ensure valid vault and load vault config
        uint128 vaultId = WETH_CORE_VAULT_ID;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        uint128 assetsToDeposit = uint128(calculateMinOfSharesToStake(vaultId));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre state
        UnstakeState memory preStakeState =
            _getUnstakeState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertGt(preStakeState.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, preStakeState.stakerVaultBal);

        // sent WETH market fees from PerpsEngine -> MarketEngine
        uint256 marketFees = 1e18;
        deal(fuzzVaultConfig.asset, address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine), marketFees);
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(fuzzVaultConfig.asset, ETH_USD_MARKET_ID, marketFees);
        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // verify the staker has earned rewards which are not yet claimed
        uint256 user1PendingRewards = 899_999_999_999_999_999;
        changePrank({ msgSender: user });
        assertEq(marketMakingEngine.getEarnedFees(vaultId, user), user1PendingRewards, "Staker has pending rewards");
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0, "Staker has no asset tokens prior to unstake");

        // second user makes a deposit, triggers a call to `Vault.recalculateVaultsCreditCapacity`
        fundUserAndDepositInVault(users.sasuke.account, vaultId, assetsToDeposit);

        // original staker's pending rewards just doubled + 1!
        assertEq(
            marketMakingEngine.getEarnedFees(vaultId, user),
            user1PendingRewards,
            "Staker pending rewards should maintain the same!"
        );

        // third user makes a deposit, triggers a call to `Vault.recalculateVaultsCreditCapacity`
        fundUserAndDepositInVault(users.sakura.account, vaultId, assetsToDeposit);

        // original staker's pending rewards increased again, they are 3x + 2 the original amount
        assertEq(
            marketMakingEngine.getEarnedFees(vaultId, user),
            user1PendingRewards,
            "Staker pending rewards should maintain the same!"
        );
    }

    // if a staker unstakes before claiming, they lose all their unclaimed rewards!
    // a staker can easily forget to claim before unstaking (I have seen this exact flaw
    // play out in other protocols); when a staker unstakes the protocol should credit
    // any unclaimed rewards prior to unstaking them
    function test_stakerLosesUnclaimedRewardsWhenUnstakingBeforeClaiming() external {
        // ensure valid vault and load vault config
        uint128 vaultId = WETH_CORE_VAULT_ID;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        uint128 assetsToDeposit = uint128(calculateMinOfSharesToStake(vaultId));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre state
        UnstakeState memory preStakeState =
            _getUnstakeState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertGt(preStakeState.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, preStakeState.stakerVaultBal);

        // sent WETH market fees from PerpsEngine -> MarketEngine
        uint256 marketFees = 1e18;
        deal(fuzzVaultConfig.asset, address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine), marketFees);
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(fuzzVaultConfig.asset, ETH_USD_MARKET_ID, marketFees);
        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // verify the staker has earned rewards which are not yet claimed
        changePrank({ msgSender: user });
        assertEq(
            marketMakingEngine.getEarnedFees(vaultId, user), 899_999_999_999_999_999, "Staker has pending rewards"
        );
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0, "Staker has no asset tokens prior to unstake");

        // save snapshot of current state prior to unstake
        uint256 snapshotId = vm.snapshot();

        {
            changePrank({ msgSender: user });

            // claim fees
            marketMakingEngine.claimFees(vaultId);

            // staker unstakes
            marketMakingEngine.unstake(vaultId, preStakeState.stakerVaultBal);

            assertGt(
                IERC20(fuzzVaultConfig.indexToken).balanceOf(user),
                0,
                "Staker has shares/index tokens after full unstake"
            );
            assertEq(
                marketMakingEngine.getEarnedFees(vaultId, user), 0, "Staker has lost pending rewards after unstake"
            );

            vm.expectRevert(Errors.NoSharesAvailable.selector);
            marketMakingEngine.claimFees(vaultId);

            UnstakeState memory postUnstakeState =
                _getUnstakeState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
            assertEq(postUnstakeState.stakerLastValuePerShare, 0);

            // they can try to re-stake since they got their vault shares back
            assertEq(
                postUnstakeState.stakerVaultBal,
                preStakeState.stakerVaultBal,
                "Staker received back vault shares after unstake"
            );
            marketMakingEngine.stake(vaultId, postUnstakeState.stakerVaultBal);

            // but they have no earned fees anymore
            assertEq(marketMakingEngine.getEarnedFees(vaultId, user), 0);

            // attempting to claim fees fails
            vm.expectRevert(Errors.NoFeesToClaim.selector);
            marketMakingEngine.claimFees(vaultId);
        }

        // restore snapshot state prior to unstake
        vm.revertTo(snapshotId);

        // verify user has pending rewards and no asset tokens once again
        assertEq(
            marketMakingEngine.getEarnedFees(vaultId, user), 899_999_999_999_999_999, "Staker has pending rewards"
        );
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0, "Staker has no asset tokens prior to unstake");

        marketMakingEngine.claimFees(vaultId);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 899_999_999_999_999_999, "Staker claimed fees");
    }
}
