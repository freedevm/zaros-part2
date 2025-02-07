// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract GetEarnedFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    function testFuzz_WhenGetEarnedFeesIsCalled(
        uint256 vaultId,
        uint256 marketId,
        uint256 amountToDepositMarketFee,
        uint256 assetsToDepositVault,
        uint256 adapterIndex
    )
        external
    {
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

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

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        amountToDepositMarketFee = bound({
            x: amountToDepositMarketFee,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amountToDepositMarketFee });

        marketMakingEngine.receiveMarketFee(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), amountToDepositMarketFee
        );

        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), adapter.STRATEGY_ID(), bytes("")
        );

        changePrank({ msgSender: users.naruto.account });

        assertEq(IERC20(wEth).balanceOf(users.naruto.account), 0);

        uint256 expectedTokenAmount =
            adapter.getExpectedOutput(address(usdc), address(wEth), amountToDepositMarketFee);
        uint256 amountOutMin = adapter.calculateAmountOutMin(expectedTokenAmount);
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedWethRewardX18 = amountOutMinX18.mul(
            ud60x18(Constants.MAX_SHARES).sub(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()))
        );

        // it should return the earned fees
        assertAlmostEq(
            marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account),
            expectedWethRewardX18.intoUint256(),
            2,
            "the earned fees was returned incorrectly"
        );

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);

        assertEq(
            marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account),
            0,
            "the earned fees should be zero"
        );
    }
}
