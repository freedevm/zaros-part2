// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { IMockEngine } from "test/mocks/IMockEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// PRB Math dependencies
import { ud60x18, UD60x18 } from "@prb-math/UD60x18.sol";

contract FulfillSwap_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
    }

    function test_RevertWhen_CallerIsNotKeeper() external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account));

        marketMakingEngine.fulfillSwap(users.naruto.account, 1, new bytes(0), address(marketMakingEngine));
    }

    modifier whenCallerIsKeeper() {
        _;
    }

    function testFuzz_RevertWhen_RequestWasAlreadyProcessed(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenCallerIsKeeper
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: users.naruto.account });

        deal({
            token: address(fuzzVaultConfig.asset),
            to: fuzzVaultConfig.indexToken,
            give: fuzzVaultConfig.depositCap
        });

        UD60x18 assetPriceX18 = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(fuzzVaultConfig.indexToken).totalAssets());
        uint256 maxSwapAmount = assetAmountX18.mul(assetPriceX18).intoUint256();

        swapAmount = bound({ x: swapAmount, min: 1e6, max: maxSwapAmount });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 minAmountOut = 0;

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, assetPriceX18.intoUint256());
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        uint128 requestId = 1;
        changePrank({ msgSender: usdTokenSwapKeeper });
        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.RequestAlreadyProcessed.selector, users.naruto.account, requestId)
        );
        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
    }

    modifier whenRequestWasNotYetProcessed() {
        _;
    }

    function testFuzz_RevertWhen_SwapRequestHasExpired(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenCallerIsKeeper
        whenRequestWasNotYetProcessed
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        uint128 maxExecutionEndTime = 100;
        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureUsdTokenSwapConfig(1, 30, maxExecutionEndTime);

        changePrank({ msgSender: users.naruto.account });

        deal({
            token: address(fuzzVaultConfig.asset),
            to: fuzzVaultConfig.indexToken,
            give: fuzzVaultConfig.depositCap
        });

        UD60x18 assetPriceX18 = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(fuzzVaultConfig.indexToken).totalAssets());
        uint256 maxSwapAmount = assetAmountX18.mul(assetPriceX18).intoUint256();

        swapAmount = bound({ x: swapAmount, min: 1e6, max: maxSwapAmount });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 minAmountOut = 0;

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, assetPriceX18.intoUint256());
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        UsdTokenSwapConfig.SwapRequest memory request = marketMakingEngine.getSwapRequest(users.naruto.account, 1);

        // Fast forward time so request expires
        skip(maxExecutionEndTime + 1);

        uint128 requestId = 1;
        changePrank({ msgSender: usdTokenSwapKeeper });

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SwapRequestExpired.selector, users.naruto.account, 1, request.deadline)
        );

        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
    }

    modifier whenSwapRequestNotExpired() {
        _;
    }

    function testFuzz_RevertWhen_SlippageCheckFails(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenCallerIsKeeper
        whenRequestWasNotYetProcessed
        whenSwapRequestNotExpired
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: users.owner.account });
        uint128 bpsFee = 30;
        marketMakingEngine.configureUsdTokenSwapConfig(1, bpsFee, type(uint96).max);

        changePrank({ msgSender: users.naruto.account });

        deal({
            token: address(fuzzVaultConfig.asset),
            to: fuzzVaultConfig.indexToken,
            give: fuzzVaultConfig.depositCap
        });

        UD60x18 assetPriceX18 = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(fuzzVaultConfig.indexToken).totalAssets());
        uint256 maxSwapAmount = assetAmountX18.mul(assetPriceX18).intoUint256();

        swapAmount = bound({ x: swapAmount, min: 1e18, max: maxSwapAmount });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint256 assetPrice = assetPriceX18.intoUint256();
        UD60x18 amountOut =
            marketMakingEngine.getAmountOfAssetOut(fuzzVaultConfig.vaultId, ud60x18(swapAmount), ud60x18(assetPrice));

        uint256 minAmountOut = amountOut.intoUint256();

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        // increase price so slippage  check fails in fulfill swap
        assetPrice = assetPrice + 1e8;

        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, assetPrice + 1e8);
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        uint128 requestId = 1;
        changePrank({ msgSender: usdTokenSwapKeeper });

        amountOut = marketMakingEngine.getAmountOfAssetOut(
            fuzzVaultConfig.vaultId, ud60x18(swapAmount), ud60x18(assetPrice + 1e8)
        );

        (UD60x18 baseFeeX18, UD60x18 swapFeeX18) =
            marketMakingEngine.getFeesForAssetsAmountOut(amountOut, ud60x18(assetPrice + 1e8));

        uint256 amountOutAfterFee =
            convertUd60x18ToTokenAmount(fuzzVaultConfig.asset, amountOut.sub(baseFeeX18.add(swapFeeX18)));

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minAmountOut, amountOutAfterFee));

        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
    }

    struct TestFuzz_WhenSlippageCheckPassesAndThePremiumOrDiscountIsZero_Context {
        VaultConfig fuzzVaultConfig;
        uint256 swapAmount;
        uint128 minAmountOut;
        bytes priceData;
        address usdTokenSwapKeeper;
        UsdTokenSwapConfig.SwapRequest request;
        uint128 requestId;
        UD60x18 amountOut;
        uint256 amountOutAfterFee;
        UD60x18 baseFeeX18;
        UD60x18 swapFeeX18;
        UD60x18 protocolSwapFee;
        uint256 protocolReward;
        UD60x18 assetPriceX18;
        UD60x18 assetAmountX18;
    }

    function testFuzz_WhenSlippageCheckPassesAndThePremiumOrDiscountIsZero(uint256 vaultId)
        external
        whenCallerIsKeeper
        whenRequestWasNotYetProcessed
        whenSwapRequestNotExpired
    {
        TestFuzz_WhenSlippageCheckPassesAndThePremiumOrDiscountIsZero_Context memory ctx;
        ctx.fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureUsdTokenSwapConfig(1, 30, type(uint96).max);

        changePrank({ msgSender: users.naruto.account });

        deal({
            token: address(ctx.fuzzVaultConfig.asset),
            to: ctx.fuzzVaultConfig.indexToken,
            give: ctx.fuzzVaultConfig.depositCap
        });

        ctx.assetPriceX18 = IPriceAdapter(ctx.fuzzVaultConfig.priceAdapter).getPrice();
        ctx.assetAmountX18 = ud60x18(IERC4626(ctx.fuzzVaultConfig.indexToken).totalAssets());
        ctx.swapAmount = ctx.assetAmountX18.mul(ctx.assetPriceX18).intoUint256();

        deal({ token: address(usdToken), to: users.naruto.account, give: ctx.swapAmount });

        ctx.minAmountOut = 0;

        initiateUsdSwap(uint128(ctx.fuzzVaultConfig.vaultId), ctx.swapAmount, ctx.minAmountOut);

        ctx.priceData = getMockedSignedReport(ctx.fuzzVaultConfig.streamId, ctx.assetPriceX18.intoUint256());
        ctx.usdTokenSwapKeeper = usdTokenSwapKeepers[ctx.fuzzVaultConfig.asset];

        ctx.requestId = 1;
        ctx.request = marketMakingEngine.getSwapRequest(users.naruto.account, ctx.requestId);

        ctx.amountOut = marketMakingEngine.getAmountOfAssetOut(
            ctx.fuzzVaultConfig.vaultId, ud60x18(ctx.swapAmount), ctx.assetPriceX18
        );

        (ctx.baseFeeX18, ctx.swapFeeX18) =
            marketMakingEngine.getFeesForAssetsAmountOut(ctx.amountOut, ctx.assetPriceX18);

        ctx.amountOutAfterFee = convertUd60x18ToTokenAmount(
            ctx.fuzzVaultConfig.asset, ctx.amountOut.sub(ctx.baseFeeX18.add(ctx.swapFeeX18))
        );

        changePrank({ msgSender: ctx.usdTokenSwapKeeper });

        ctx.protocolSwapFee = ctx.swapFeeX18.mul(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()));
        ctx.protocolReward =
            convertUd60x18ToTokenAmount(ctx.fuzzVaultConfig.asset, ctx.baseFeeX18.add(ctx.protocolSwapFee));

        // it should emit {LogFulfillSwap} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit StabilityBranch.LogFulfillSwap(
            users.naruto.account,
            ctx.requestId,
            ctx.fuzzVaultConfig.vaultId,
            ctx.request.amountIn,
            ctx.request.minAmountOut,
            ctx.request.assetOut,
            ctx.request.deadline,
            ctx.amountOutAfterFee,
            ctx.baseFeeX18.intoUint256(),
            ctx.swapFeeX18.intoUint256(),
            ctx.protocolReward
        );

        marketMakingEngine.fulfillSwap(
            users.naruto.account, ctx.requestId, ctx.priceData, address(marketMakingEngine)
        );

        // it should transfer assets to user
        assertGt(IERC20(ctx.fuzzVaultConfig.asset).balanceOf(users.naruto.account), 0, "balance of user > 0 failed");

        // it should burn USD token from contract
        assertEq(IERC20(usdToken).balanceOf(ctx.fuzzVaultConfig.indexToken), 0, "balance of zlp vault == 0 failed");
    }

    struct TestFuzz_WhenSlippageCheckPassesAndThePremiumOrDiscountIsNotZero_Context {
        VaultConfig fuzzVaultConfig;
        uint256 oneAsset;
        PerpMarketCreditConfig fuzzPerpMarketCreditConfig;
        IMockEngine engine;
        uint128 minAmountOut;
        bytes priceData;
        address usdTokenSwapKeeper;
        UsdTokenSwapConfig.SwapRequest request;
        uint128 requestId;
        UD60x18 amountOut;
        uint256 amountOutAfterFee;
        UD60x18 baseFeeX18;
        UD60x18 swapFeeX18;
        UD60x18 protocolSwapFee;
        uint256 protocolReward;
    }

    function testFuzz_WhenSlippageCheckPassesAndThePremiumOrDiscountIsNotZero(
        uint256 vaultId,
        uint256 marketId,
        uint256 vaultAssetsBalance,
        uint256 swapAmount,
        uint256 vaultDebtAbsUsd,
        bool useCredit
    )
        external
        whenCallerIsKeeper
        whenRequestWasNotYetProcessed
        whenSwapRequestNotExpired
    {
        // working data
        TestFuzz_WhenSlippageCheckPassesAndThePremiumOrDiscountIsNotZero_Context memory ctx;

        ctx.fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        ctx.oneAsset = 10 ** ctx.fuzzVaultConfig.decimals;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureUsdTokenSwapConfig(1, 30, type(uint96).max);

        changePrank({ msgSender: users.naruto.account });

        // bound the vault assets balance to be between 1 asset unit and the deposit cap
        vaultAssetsBalance = bound({ x: vaultAssetsBalance, min: ctx.oneAsset, max: ctx.fuzzVaultConfig.depositCap });

        // bound the vault's total credit or debt
        vaultDebtAbsUsd = bound({ x: vaultDebtAbsUsd, min: ctx.oneAsset / 2, max: vaultAssetsBalance });

        deal({
            token: address(ctx.fuzzVaultConfig.asset),
            to: ctx.fuzzVaultConfig.indexToken,
            give: vaultAssetsBalance
        });

        swapAmount = vaultAssetsBalance / 1e9;
        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        ctx.fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);
        ctx.engine = IMockEngine(perpMarketsCreditConfig[ctx.fuzzPerpMarketCreditConfig.marketId].engine);
        // we update the mock engine's unrealized debt in order to update the vault's total debt state
        ctx.engine.setUnrealizedDebt(useCredit ? -int256(vaultDebtAbsUsd) : int256(vaultDebtAbsUsd));

        ctx.minAmountOut = 0;
        UD60x18 priceUsdX18 = IPriceAdapter(vaultsConfig[ctx.fuzzVaultConfig.vaultId].priceAdapter).getPrice();

        ctx.priceData = getMockedSignedReport(ctx.fuzzVaultConfig.streamId, priceUsdX18.intoUint256());
        ctx.usdTokenSwapKeeper = usdTokenSwapKeepers[ctx.fuzzVaultConfig.asset];

        ctx.amountOut =
            marketMakingEngine.getAmountOfAssetOut(ctx.fuzzVaultConfig.vaultId, ud60x18(swapAmount), priceUsdX18);

        vm.assume(ctx.amountOut.intoUint256() > 0);

        initiateUsdSwap(uint128(ctx.fuzzVaultConfig.vaultId), swapAmount, ctx.minAmountOut);

        (ctx.baseFeeX18, ctx.swapFeeX18) = marketMakingEngine.getFeesForAssetsAmountOut(ctx.amountOut, priceUsdX18);

        ctx.amountOutAfterFee = convertUd60x18ToTokenAmount(
            ctx.fuzzVaultConfig.asset, ctx.amountOut.sub(ctx.baseFeeX18.add(ctx.swapFeeX18))
        );

        changePrank({ msgSender: ctx.usdTokenSwapKeeper });

        ctx.protocolSwapFee = ctx.swapFeeX18.mul(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()));
        ctx.protocolReward =
            convertUd60x18ToTokenAmount(ctx.fuzzVaultConfig.asset, ctx.baseFeeX18.add(ctx.protocolSwapFee));

        ctx.requestId = 1;
        ctx.request = marketMakingEngine.getSwapRequest(users.naruto.account, ctx.requestId);

        // it should emit {LogFulfillSwap} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit StabilityBranch.LogFulfillSwap(
            users.naruto.account,
            ctx.requestId,
            ctx.fuzzVaultConfig.vaultId,
            ctx.request.amountIn,
            ctx.request.minAmountOut,
            ctx.request.assetOut,
            ctx.request.deadline,
            ctx.amountOutAfterFee,
            ctx.baseFeeX18.intoUint256(),
            ctx.swapFeeX18.intoUint256(),
            ctx.protocolReward
        );

        marketMakingEngine.fulfillSwap(
            users.naruto.account, ctx.requestId, ctx.priceData, address(marketMakingEngine)
        );

        // it should transfer assets to user
        assertEq(
            IERC20(ctx.fuzzVaultConfig.asset).balanceOf(users.naruto.account),
            ctx.amountOutAfterFee,
            "balance of user == amountOutAfterFee failed"
        );

        // it should burn USD token from contract
        assertEq(IERC20(usdToken).balanceOf(ctx.fuzzVaultConfig.indexToken), 0, "balance of zlp vault == 0 failed");
    }
}
