// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// Openzeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract ConvertAccumulatedFeesToWeth_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
    {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            uint128(marketId), address(usdc), dexSwapStrategyId, bytes("")
        );
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesNotExist(uint128 dexSwapStrategyId)
        external
        givenTheSenderIsRegisteredEngine
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 invalidMarketId = FINAL_PERP_MARKET_CREDIT_CONFIG_ID + 1;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketId) });

        marketMakingEngine.convertAccumulatedFeesToWeth(invalidMarketId, address(usdc), dexSwapStrategyId, bytes(""));
    }

    modifier whenTheMarketExist() {
        _;
    }

    function testFuzz_RevertWhen_TheCollatealIsNotEnabled(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        address assetNotEnabled = address(0x123);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, assetNotEnabled, dexSwapStrategyId, bytes("")
        );
    }

    modifier whenTheCollateralIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesntHaveTheAsset(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketDoesNotContainTheAsset.selector, address(usdc))
        });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), dexSwapStrategyId, bytes("")
        );
    }

    modifier whenTheMarketHasTheAsset() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketHasTheAsset
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        marketMakingEngine.workaround_setReceivedMarketFees(fuzzPerpMarketCreditConfig.marketId, address(usdc), 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AssetAmountIsZero.selector, address(usdc)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), dexSwapStrategyId, bytes("")
        );
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheDexSwapStrategyHasAnInvalidDexAdapter(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketHasTheAsset
        whenTheAmountIsNotZero
    {
        uint128 wrongStrategyId = 0;

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.DexSwapStrategyHasAnInvalidDexAdapter.selector, wrongStrategyId)
        });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), wrongStrategyId, bytes("")
        );
    }

    modifier whenTheDexSwapStrategyHasAValidDexAdapter() {
        _;
    }

    function testFuzz_WhenTheDexSwapStrategyHasAMultiSwapPath(
        uint256 marketId,
        uint256 amount,
        uint256 adapterIndex
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketHasTheAsset
        whenTheAmountIsNotZero
        whenTheDexSwapStrategyHasAValidDexAdapter
    {
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        amount =
            bound({ x: amount, min: 1e12, max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) });

        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        address[] memory assets = new address[](3);
        assets[0] = address(usdc);
        assets[1] = address(wBtc);
        assets[2] = address(wEth);

        uint128[] memory dexSwapStrategyIds = new uint128[](2);
        dexSwapStrategyIds[0] = adapter.STRATEGY_ID();
        dexSwapStrategyIds[1] = adapter.STRATEGY_ID();

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureAssetCustomSwapPath(address(usdc), true, assets, dexSwapStrategyIds);
        changePrank({ msgSender: address(perpsEngine) });

        assertEq(IERC20(usdc).balanceOf(address(marketMakingEngine)), amount);
        assertEq(IERC20(wEth).balanceOf(address(marketMakingEngine)), 0);

        uint256 expectedTokenAmount = adapter.getExpectedOutput(address(usdc), address(wBtc), amount);
        uint256 amountOutMin = adapter.calculateAmountOutMin(expectedTokenAmount);

        expectedTokenAmount = adapter.getExpectedOutput(address(wBtc), address(wEth), amountOutMin);
        amountOutMin = adapter.calculateAmountOutMin(expectedTokenAmount);

        assertEq(
            marketMakingEngine.workaround_getIfReceivedMarketFeesContainsTheAsset(
                fuzzPerpMarketCreditConfig.marketId, address(usdc)
            ),
            true,
            "the asset should be in the received market fees"
        );

        // it should emit {LogConvertAccumulatedFeesToWeth} event
        // vm.expectEmit({ emitter: address(marketMakingEngine) });
        // emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(amountOutMin);

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), 0, bytes("")
        );

        // it should verify if the asset is different that weth and convert
        assertEq(IERC20(usdc).balanceOf(address(adapter)), 0, "the adapter should have 0 balance of usdc");
        assertEq(IERC20(wEth).balanceOf(address(adapter)), 0, "the adapter should have 0 balance of wEth");

        assertEq(
            IERC20(usdc).balanceOf(address(marketMakingEngine)),
            0,
            "the balance of the usdc in the market making engine after the convert should be zero"
        );
        assertEq(
            IERC20(wEth).balanceOf(address(marketMakingEngine)),
            amountOutMin,
            "the balance of the wEth in the market making engine after the convert is wrong"
        );

        // it should update the pending protocol weth reward
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedPendingProtocolWethRewardX18 =
            amountOutMinX18.mul(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()));

        assertEq(
            marketMakingEngine.workaround_getPendingProtocolWethReward(fuzzPerpMarketCreditConfig.marketId),
            expectedPendingProtocolWethRewardX18.intoUint256(),
            "the available fees to withdraw is wrong"
        );

        // it should remove the asset from receivedMarketFees
        assertEq(
            marketMakingEngine.workaround_getIfReceivedMarketFeesContainsTheAsset(
                fuzzPerpMarketCreditConfig.marketId, address(usdc)
            ),
            false,
            "the asset should be removed from the received market fees"
        );
    }

    function test_WhenTheDexSwapStrategyHasASingleOrMultihopSwapPath(
        uint256 marketId,
        uint256 amount,
        bool shouldSwapExactInputSingle,
        uint256 adapterIndex
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketHasTheAsset
        whenTheAmountIsNotZero
        whenTheDexSwapStrategyHasAValidDexAdapter
    {
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        assertEq(IERC20(usdc).balanceOf(address(adapter)), 0, "the adapter should have 0 balance of usdc");
        assertEq(IERC20(wEth).balanceOf(address(adapter)), 0, "the adapter should have 0 balance of wEth");

        assertEq(IERC20(usdc).balanceOf(address(marketMakingEngine)), amount);
        assertEq(IERC20(wEth).balanceOf(address(marketMakingEngine)), 0);

        uint256 expectedTokenAmount = adapter.getExpectedOutput(address(usdc), address(wEth), amount);
        uint256 amountOutMin = adapter.calculateAmountOutMin(expectedTokenAmount);

        assertEq(
            marketMakingEngine.workaround_getIfReceivedMarketFeesContainsTheAsset(
                fuzzPerpMarketCreditConfig.marketId, address(usdc)
            ),
            true,
            "the asset should be in the received market fees"
        );

        bytes memory path = shouldSwapExactInputSingle
            ? bytes("")
            : abi.encodePacked(address(usdc), UNI_V3_FEE, address(wBtc), UNI_V3_FEE, address(wEth));

        if (!shouldSwapExactInputSingle && adapter.STRATEGY_ID() == curveAdapter.STRATEGY_ID()) {
            path = abi.encodePacked(address(usdc), UNI_V3_FEE, address(wEth));
        }

        // it should emit {LogConvertAccumulatedFeesToWeth} event
        // vm.expectEmit({ emitter: address(marketMakingEngine) });
        // emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(amountOutMin);

        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), adapter.STRATEGY_ID(), path
        );

        // it should verify if the asset is different that weth and convert
        assertEq(IERC20(usdc).balanceOf(address(adapter)), 0, "the adapter should have 0 balance of usdc");
        assertEq(IERC20(wEth).balanceOf(address(adapter)), 0, "the adapter should have 0 balance of wEth");

        assertEq(
            IERC20(usdc).balanceOf(address(marketMakingEngine)),
            0,
            "the balance of the usdc in the market making engine after the convert should be zero"
        );
        assertEq(
            IERC20(wEth).balanceOf(address(marketMakingEngine)),
            amountOutMin,
            "the balance of the wEth in the market making engine after the convert is wrong"
        );

        // it should update the pending protocol weth reward
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedPendingProtocolWethRewardX18 =
            amountOutMinX18.mul(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()));

        assertEq(
            marketMakingEngine.workaround_getPendingProtocolWethReward(fuzzPerpMarketCreditConfig.marketId),
            expectedPendingProtocolWethRewardX18.intoUint256(),
            "the available fees to withdraw is wrong"
        );

        // it should remove the asset from receivedFees
        assertEq(
            marketMakingEngine.workaround_getIfReceivedMarketFeesContainsTheAsset(
                fuzzPerpMarketCreditConfig.marketId, address(usdc)
            ),
            false,
            "the asset should be removed from the received market fees"
        );
    }
}
