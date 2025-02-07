// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// PRB Math dependencies
import { ud60x18, UD60x18 } from "@prb-math/UD60x18.sol";

contract UsdTokenSwapKeeper_PerformUpkeep_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenInitializeContract() {
        _;
    }

    struct TestFuzz_GivenCallPerformUpkeepFunction_Context {
        uint256 assetsToDeposit;
        address usdTokenSwapKeeper;
        uint256 mockPrice;
        uint256 amountInUsd;
        uint128 minAmountOut;
        uint128 requestId;
        UD60x18 baseFeeX18;
        UD60x18 swapFeeX18;
        UD60x18 amountOut;
        uint256 amountOutAfterFee;
        UD60x18 protocolSwapFee;
        uint256 protocolReward;
    }

    function testFuzz_GivenCallPerformUpkeepFunction(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
        givenInitializeContract
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        TestFuzz_GivenCallPerformUpkeepFunction_Context memory ctx;

        ctx.assetsToDeposit = bound({ x: assetsToDeposit, min: 1e18, max: fuzzVaultConfig.depositCap });

        deal({
            token: address(fuzzVaultConfig.asset),
            to: fuzzVaultConfig.indexToken,
            give: fuzzVaultConfig.depositCap
        });

        ctx.usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        changePrank({ msgSender: users.owner.account });

        UsdTokenSwapKeeper(ctx.usdTokenSwapKeeper).setForwarder(users.keepersForwarder.account);

        marketMakingEngine.configureSystemKeeper(ctx.usdTokenSwapKeeper, true);

        changePrank({ msgSender: users.naruto.account });

        ctx.mockPrice = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice().intoUint256();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(fuzzVaultConfig.indexToken).totalAssets());
        ctx.amountInUsd = assetAmountX18.mul(ud60x18(ctx.mockPrice)).intoUint256();

        deal({ token: address(usdToken), to: users.naruto.account, give: ctx.amountInUsd });

        IERC20(usdToken).approve(address(marketMakingEngine), ctx.amountInUsd);

        ctx.minAmountOut = 0;

        initiateUsdSwap(fuzzVaultConfig.vaultId, ctx.amountInUsd, ctx.minAmountOut);

        bytes memory mockSignedReport = getMockedSignedReport(fuzzVaultConfig.streamId, ctx.mockPrice);

        bytes memory performData = abi.encode(mockSignedReport, abi.encode(users.naruto.account, 1));

        ctx.requestId = 1;
        UsdTokenSwapConfig.SwapRequest memory request =
            marketMakingEngine.getSwapRequest(users.naruto.account, ctx.requestId);

        ctx.amountOut = marketMakingEngine.getAmountOfAssetOut(
            fuzzVaultConfig.vaultId, ud60x18(ctx.amountInUsd), ud60x18(ctx.mockPrice)
        );

        (ctx.baseFeeX18, ctx.swapFeeX18) =
            marketMakingEngine.getFeesForAssetsAmountOut(ctx.amountOut, ud60x18(ctx.mockPrice));

        ctx.amountOutAfterFee =
            convertUd60x18ToTokenAmount(fuzzVaultConfig.asset, ctx.amountOut.sub(ctx.baseFeeX18.add(ctx.swapFeeX18)));

        ctx.protocolSwapFee = ctx.swapFeeX18.mul(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()));
        ctx.protocolReward =
            convertUd60x18ToTokenAmount(fuzzVaultConfig.asset, ctx.baseFeeX18.add(ctx.protocolSwapFee));

        // it should emit {LogFulfillSwap} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit StabilityBranch.LogFulfillSwap(
            users.naruto.account,
            ctx.requestId,
            fuzzVaultConfig.vaultId,
            request.amountIn,
            request.minAmountOut,
            request.assetOut,
            request.deadline,
            ctx.amountOutAfterFee,
            ctx.baseFeeX18.intoUint256(),
            ctx.swapFeeX18.intoUint256(),
            ctx.protocolReward
        );

        changePrank({ msgSender: users.keepersForwarder.account });
        UsdTokenSwapKeeper(ctx.usdTokenSwapKeeper).performUpkeep(performData);
    }
}
