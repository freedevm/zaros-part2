// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Math } from "@zaros/utils/Math.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract ClaimFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    function testFuzz_RevertWhen_TheUserDoesNotHaveAvailableShares(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoSharesAvailable.selector) });

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);
    }

    modifier whenTheUserDoesHaveAvailableShares() {
        _;
    }

    function testFuzz_RevertWhen_AmountToClaimIsZero(
        uint256 vaultId,
        uint256 assetsToDepositVault
    )
        external
        whenTheUserDoesHaveAvailableShares
    {
        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDepositVault = bound({
            x: assetsToDepositVault,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDepositVault);

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDepositVault), 0, "", false);

        uint256 sharesToStake = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);

        marketMakingEngine.stake(fuzzVaultConfig.vaultId, uint128(sharesToStake));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoFeesToClaim.selector) });

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);
    }

    function testFuzz_WhenAmountToClaimIsGreaterThenZero(
        uint256 vaultId,
        uint256 marketId,
        uint256 amountToDepositMarketFee,
        uint256 assetsToDepositVault,
        uint256 adapterIndex
    )
        external
        whenTheUserDoesHaveAvailableShares
    {
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        amountToDepositMarketFee = bound({
            x: amountToDepositMarketFee,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDepositVault = bound({
            x: assetsToDepositVault,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDepositVault);

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDepositVault), 0, "", false);

        uint256 sharesToStake = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);

        marketMakingEngine.stake(fuzzVaultConfig.vaultId, uint128(sharesToStake));

        assertEq(IERC20(wEth).balanceOf(users.naruto.account), 0);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amountToDepositMarketFee });

        marketMakingEngine.receiveMarketFee(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), amountToDepositMarketFee
        );

        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), adapter.STRATEGY_ID(), bytes("")
        );
        changePrank({ msgSender: users.naruto.account });

        uint256 earnedFees = marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account);

        // it should emit {LogClaimFees} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogClaimFees(users.naruto.account, fuzzVaultConfig.vaultId, earnedFees);

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);

        uint256 amountUserFeesReceived = IERC20(wEth).balanceOf(users.naruto.account);

        // it should transfer the fees to the sender
        uint256 expectedTokenAmount =
            adapter.getExpectedOutput(address(usdc), address(wEth), amountToDepositMarketFee);
        uint256 amountOutMin = adapter.calculateAmountOutMin(expectedTokenAmount);
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedWethRewardX18 = amountOutMinX18.mul(
            ud60x18(Constants.MAX_SHARES).sub(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()))
        );
        assertAlmostEq(
            amountUserFeesReceived,
            expectedWethRewardX18.intoUint256(),
            2,
            "the user should have the expected wEth reward"
        );

        // it should update accumulate actor
        earnedFees = marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account);
        assertEq(earnedFees, 0, "the user should have zero fees to claim");
    }

    struct ClaimFeesState {
        // fee balances
        uint256 stakerFeesBal;
        uint256 vaultFeesBal;
        uint256 marketEngineFeesBal;
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

    function _getClaimFeesState(
        address staker,
        uint128 vaultId,
        IERC20 feeToken,
        IERC20 vault
    )
        internal
        view
        returns (ClaimFeesState memory state)
    {
        state.stakerFeesBal = feeToken.balanceOf(staker);
        state.vaultFeesBal = feeToken.balanceOf(address(vault));
        state.marketEngineFeesBal = feeToken.balanceOf(address(marketMakingEngine));

        state.stakerVaultBal = uint128(vault.balanceOf(staker));
        state.marketEngineVaultBal = uint128(vault.balanceOf(address(marketMakingEngine)));

        (state.totalShares, state.valuePerShare, state.stakerShares, state.stakerLastValuePerShare) =
            marketMakingEngine.getTotalAndAccountStakingData(vaultId, staker);
    }

    //
    //
    //

    // only for WETH vault & associated market at the moment
    function testFuzz_WhenAmountToClaimIsGreaterThenZero_Passing(
        uint128 assetsToDeposit,
        uint128 marketFees
    )
        external
    {
        // ensure valid vault and load vault config
        uint128 vaultId = WETH_CORE_VAULT_ID;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // all fees paid in WETH
        IERC20 wethFeeToken = IERC20(getFuzzVaultConfig(WETH_CORE_VAULT_ID).asset);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap / 2));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre stake state
        ClaimFeesState memory preStakeState =
            _getClaimFeesState(user, vaultId, wethFeeToken, IERC20(fuzzVaultConfig.indexToken));
        assertGt(preStakeState.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, preStakeState.stakerVaultBal);

        // save and verify post stake state
        ClaimFeesState memory postStakeState =
            _getClaimFeesState(user, vaultId, wethFeeToken, IERC20(fuzzVaultConfig.indexToken));
        assertEq(postStakeState.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(
            postStakeState.marketEngineVaultBal,
            preStakeState.stakerVaultBal,
            "MarketEngine received stakers vault shares"
        );
        assertEq(
            postStakeState.totalShares, preStakeState.stakerVaultBal, "Staking totalShares == staked vault balance"
        );
        assertEq(postStakeState.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");
        assertEq(postStakeState.stakerShares, preStakeState.stakerVaultBal, "Staker shares == staked vault balance");
        assertEq(postStakeState.stakerLastValuePerShare, 0, "Staker has no value per share as no value distributed");

        // sent WETH market fees from PerpsEngine -> MarketEngine
        marketFees = uint128(bound(marketFees, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap / 2));
        deal(fuzzVaultConfig.asset, address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine), marketFees);
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(fuzzVaultConfig.asset, ETH_USD_MARKET_ID, marketFees);
        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // verify the staker has earned rewards which are not yet claimed
        uint256 stakerEarnedFees = marketMakingEngine.getEarnedFees(vaultId, user);
        assertGt(stakerEarnedFees, 0, "Staker has earned fees");
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0, "Staker has no asset tokens prior to unstake");

        // staker claims rewards
        changePrank({ msgSender: user });
        marketMakingEngine.claimFees(vaultId);

        // save and verify post claim fees state
        ClaimFeesState memory postClaimFeesState =
            _getClaimFeesState(user, vaultId, wethFeeToken, IERC20(fuzzVaultConfig.indexToken));
        assertEq(
            postClaimFeesState.stakerFeesBal, stakerEarnedFees, "Staker received asset tokens after claiming fees"
        );

        // attempting to claim again fails
        vm.expectRevert(Errors.NoFeesToClaim.selector);
        marketMakingEngine.claimFees(vaultId);
    }

    // generic one for any vault & market, failing when swapping
    // from asset -> weth as getPrice() returns 0. If this can be fixed it should
    // ideally replace both the weth-only working version and testFuzz_WhenAmountToClaimIsGreaterThenZero
    // which is currently failing
    function testFuzz_WhenAmountToClaimIsGreaterThenZero(
        uint128 vaultId,
        uint128 marketId,
        uint128 assetsToDeposit,
        uint128 marketFees,
        uint128 adapterIndex
    )
        external
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // all fees paid in WETH
        IERC20 wethFeeToken = IERC20(getFuzzVaultConfig(WETH_CORE_VAULT_ID).asset);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap / 2));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre stake state
        ClaimFeesState memory preStakeState =
            _getClaimFeesState(user, vaultId, wethFeeToken, IERC20(fuzzVaultConfig.indexToken));
        assertGt(preStakeState.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, preStakeState.stakerVaultBal);

        // save and verify post stake state
        ClaimFeesState memory postStakeState =
            _getClaimFeesState(user, vaultId, wethFeeToken, IERC20(fuzzVaultConfig.indexToken));
        assertEq(postStakeState.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(
            postStakeState.marketEngineVaultBal,
            preStakeState.stakerVaultBal,
            "MarketEngine received stakers vault shares"
        );
        assertEq(
            postStakeState.totalShares, preStakeState.stakerVaultBal, "Staking totalShares == staked vault balance"
        );
        assertEq(postStakeState.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");
        assertEq(postStakeState.stakerShares, preStakeState.stakerVaultBal, "Staker shares == staked vault balance");
        assertEq(postStakeState.stakerLastValuePerShare, 0, "Staker has no value per share as no value distributed");

        // sent market fees from PerpsEngine -> MarketEngine
        marketFees = uint128(bound(marketFees, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap / 2));

        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);
        deal(fuzzVaultConfig.asset, address(fuzzPerpMarketCreditConfig.engine), marketFees);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(
            fuzzVaultConfig.asset, fuzzPerpMarketCreditConfig.marketId, marketFees
        );
        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // optionally convert asset to WETH if not on WETH vault
        if (fuzzVaultConfig.asset != address(wEth)) {
            changePrank({ msgSender: address(perpsEngine) });

            marketMakingEngine.convertAccumulatedFeesToWeth(
                fuzzPerpMarketCreditConfig.marketId, fuzzVaultConfig.asset, adapter.STRATEGY_ID(), bytes("")
            );
        }

        // verify the staker has earned rewards which are not yet claimed
        uint256 stakerEarnedFees = marketMakingEngine.getEarnedFees(vaultId, user);
        assertGt(stakerEarnedFees, 0, "Staker has earned fees");
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0, "Staker has no asset tokens prior to unstake");

        // staker claims rewards
        changePrank({ msgSender: user });
        marketMakingEngine.claimFees(vaultId);

        // save and verify post claim fees state
        ClaimFeesState memory postClaimFeesState =
            _getClaimFeesState(user, vaultId, wethFeeToken, IERC20(fuzzVaultConfig.indexToken));
        assertEq(
            postClaimFeesState.stakerFeesBal, stakerEarnedFees, "Staker received asset tokens after claiming fees"
        );

        // attempting to claim again fails
        vm.expectRevert(Errors.NoFeesToClaim.selector);
        marketMakingEngine.claimFees(vaultId);
    }

    struct MarketWethRewards {
        // Market weth rewards
        uint128 availableProtocolWethReward;
        uint128 wethRewardPerVaultShare;
    }

    function _getMarketWethRewards(uint128 marketId) internal view returns (MarketWethRewards memory state) {
        (state.availableProtocolWethReward, state.wethRewardPerVaultShare) =
            marketMakingEngine.getWethRewardDataRaw(marketId);
    }

    function test_stakerLosesRewardsDueToRounding() external {
        // ensure valid vault and load vault config
        uint128 vaultId = WETH_CORE_VAULT_ID;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        uint128 assetsToDeposit = uint128(calculateMinOfSharesToStake(vaultId));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre state
        ClaimFeesState memory pre1 =
            _getClaimFeesState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertGt(pre1.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");
        assertEq(pre1.marketEngineVaultBal, 0, "MarketEngine has no vault shares");
        assertEq(pre1.totalShares, 0, "Staking totalShares 0 as no stakers");
        assertEq(pre1.valuePerShare, 0, "Staking valuePerShare 0 as no stakers and no value distributed");
        assertEq(pre1.stakerShares, 0, "Staker has no staking shares prior to staking");
        assertEq(pre1.stakerLastValuePerShare, 0, "Staker has no value per share prior to staking");

        assertEq(pre1.stakerVaultBal, IERC20(fuzzVaultConfig.indexToken).balanceOf(user), "balances differ");
        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, pre1.stakerVaultBal);

        // save and verify post state
        ClaimFeesState memory post1 =
            _getClaimFeesState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertEq(post1.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(post1.marketEngineVaultBal, pre1.stakerVaultBal, "MarketEngine received stakers vault shares");

        assertEq(post1.totalShares, pre1.stakerVaultBal, "Staking totalShares == staked vault balance");
        assertEq(post1.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");
        assertEq(post1.stakerShares, pre1.stakerVaultBal, "Staker shares == staked vault balance");
        assertEq(post1.stakerLastValuePerShare, 0, "Staker has no value per share as no value distributed");

        // sent WETH market fees from PerpsEngine -> MarketEngine
        uint256 marketFees = 1_000_000_000_000_000_001;
        deal(fuzzVaultConfig.asset, address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine), marketFees);
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(fuzzVaultConfig.asset, ETH_USD_MARKET_ID, marketFees);
        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // verify the staker has earned rewards which are not yet claimed
        uint256 stakerEarnedFees = marketMakingEngine.getEarnedFees(vaultId, user);
        assertEq(stakerEarnedFees, 9e17, "Staker has earned fees");
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0, "Staker has no asset tokens prior to unstake");

        ClaimFeesState memory post2 =
            _getClaimFeesState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertEq(post2.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(post2.marketEngineVaultBal, pre1.stakerVaultBal, "MarketEngine received stakers vault shares");
        assertEq(post2.totalShares, pre1.stakerVaultBal, "Staking totalShares == staked vault balance");
        assertEq(post2.valuePerShare, 8_999_820_003_599_928_011_439_771_204_575);

        MarketWethRewards memory marketWethRewards1 = _getMarketWethRewards(ETH_USD_MARKET_ID);
        assertEq(marketWethRewards1.availableProtocolWethReward, 100_000_000_000_000_000);
        assertEq(marketWethRewards1.wethRewardPerVaultShare, 900_000_000_000_000_001);

        // staker claims rewards
        uint256 stakerWethBalBefore = IERC20(fuzzVaultConfig.asset).balanceOf(user);
        changePrank({ msgSender: user });
        marketMakingEngine.claimFees(vaultId);

        // verify staker received correct rewards
        uint256 stakerReceivedRewards = IERC20(fuzzVaultConfig.asset).balanceOf(user) - stakerWethBalBefore;
        assertEq(stakerReceivedRewards, marketWethRewards1.wethRewardPerVaultShare - 1, "staker reward");

        MarketWethRewards memory marketWethRewards2 = _getMarketWethRewards(ETH_USD_MARKET_ID);
        assertEq(marketWethRewards2.availableProtocolWethReward, 100_000_000_000_000_000);

        assertEq(marketWethRewards2.wethRewardPerVaultShare, 900_000_000_000_000_001);

        // claim protocol rewards
        uint256 perpEngineWethBalBefore = IERC20(fuzzVaultConfig.asset).balanceOf(address(perpsEngine));
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });
        marketMakingEngine.sendWethToFeeRecipients(ETH_USD_MARKET_ID);

        // verify protocol reward recipient received correct rewards
        uint256 perpEngineReceivedRewards =
            IERC20(fuzzVaultConfig.asset).balanceOf(address(perpsEngine)) - perpEngineWethBalBefore;
        assertEq(perpEngineReceivedRewards, marketWethRewards2.availableProtocolWethReward);

        MarketWethRewards memory marketWethRewards3 = _getMarketWethRewards(ETH_USD_MARKET_ID);
        // available protocol rewards are correctly reset after protocol rewards are paid
        assertEq(marketWethRewards3.availableProtocolWethReward, 0);

        // in total 1 wei was lost from the rewards;
        assertEq(stakerReceivedRewards + perpEngineReceivedRewards, marketFees - 1, "total reward");
    }

    function test_protocolFeesLostDueToRounding() external {
        // ensure valid vault and load vault config
        uint128 vaultId = WETH_CORE_VAULT_ID;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        uint128 assetsToDeposit = uint128(calculateMinOfSharesToStake(vaultId));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, uint128(IERC20(fuzzVaultConfig.indexToken).balanceOf(user)));

        // sent WETH market fees from PerpsEngine -> MarketEngine
        uint256 marketFees = 1_000_000_000_000_000_001;
        deal(fuzzVaultConfig.asset, address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine), marketFees);
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(fuzzVaultConfig.asset, ETH_USD_MARKET_ID, marketFees);
        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // verify protocol rewards available
        MarketWethRewards memory marketWethRewards1 = _getMarketWethRewards(ETH_USD_MARKET_ID);
        assertEq(marketWethRewards1.availableProtocolWethReward, 100_000_000_000_000_000);
        assertEq(marketWethRewards1.wethRewardPerVaultShare, 900_000_000_000_000_001);

        // Base.t configures address(perpsEngine) to receive 0.1e18 of protocol rewards
        // we'll configure another address to receive some rewards too
        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureFeeRecipient(users.sasuke.account, 0.1e17);

        // save previous balances for protocol fee recipients
        uint256 perpEngineWethBalPre = IERC20(fuzzVaultConfig.asset).balanceOf(address(perpsEngine));
        uint256 sasukeWethBalPre = IERC20(fuzzVaultConfig.asset).balanceOf(users.sasuke.account);

        // send the protocol fees to our two recipients
        changePrank({ msgSender: address(perpMarketsCreditConfig[ETH_USD_MARKET_ID].engine) });
        marketMakingEngine.sendWethToFeeRecipients(ETH_USD_MARKET_ID);

        uint256 prepEngineFeesReceived =
            IERC20(fuzzVaultConfig.asset).balanceOf(address(perpsEngine)) - perpEngineWethBalPre;
        uint256 sasukeFeesReceived = IERC20(fuzzVaultConfig.asset).balanceOf(users.sasuke.account) - sasukeWethBalPre;

        // 0 wei remained stuck in the contract
        assertEq(prepEngineFeesReceived + sasukeFeesReceived, 100_000_000_000_000_000);
        assertEq(marketWethRewards1.availableProtocolWethReward, 100_000_000_000_000_000);
    }
}
