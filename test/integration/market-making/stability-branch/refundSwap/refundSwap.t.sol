// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

// PRB Math dependencies
import { ud60x18, UD60x18 } from "@prb-math/UD60x18.sol";

contract RefundSwap_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
    }

    function testFuzz_RevertWhen_RequestIsAlreadyProcessed(uint256 vaultId, uint256 swapAmount) external {
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

        swapAmount = bound({ x: swapAmount, min: 1e18, max: maxSwapAmount });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 minAmountOut = 0;

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, assetPriceX18.intoUint256());
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        uint128 requestId = 1;
        changePrank({ msgSender: usdTokenSwapKeeper });

        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));

        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.RequestAlreadyProcessed.selector, users.naruto.account, requestId)
        );

        marketMakingEngine.refundSwap(requestId, address(marketMakingEngine));
    }

    modifier whenRequestIsNotProcessed() {
        _;
    }

    function testFuzz_RevertWhen_DeadlineHasNotPassed(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenRequestIsNotProcessed
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

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

        uint128 minAmountOut = 0;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureUsdTokenSwapConfig(0, 0, uint128(300));

        changePrank({ msgSender: users.naruto.account });

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), uint128(swapAmount), minAmountOut);

        uint128 requestId = 1;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.RequestNotExpired.selector, users.naruto.account, requestId));

        marketMakingEngine.refundSwap(requestId, address(marketMakingEngine));
    }

    function testFuzz_WhenDeadlineHasPassed(uint256 vaultId, uint256 swapAmount) external whenRequestIsNotProcessed {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

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

        uint128 minAmountOut = 0;
        changePrank({ msgSender: users.naruto.account });

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), uint128(swapAmount), minAmountOut);

        uint128 requestId = 1;

        skip(MAX_VERIFICATION_DELAY + 1);

        uint256 baseFeeUsd = UsdTokenSwapConfig.load().baseFeeUsd;
        uint256 refundAmount = swapAmount - baseFeeUsd;
        UsdTokenSwapConfig.SwapRequest memory request =
            marketMakingEngine.getSwapRequest(users.naruto.account, requestId);

        // it should emit {LogRefundSwap} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit StabilityBranch.LogRefundSwap(
            users.naruto.account,
            requestId,
            request.vaultId,
            request.amountIn,
            request.minAmountOut,
            request.assetOut,
            request.deadline,
            baseFeeUsd,
            refundAmount
        );

        marketMakingEngine.refundSwap(requestId, address(marketMakingEngine));
        // it should transfer usd back to user
    }
}
