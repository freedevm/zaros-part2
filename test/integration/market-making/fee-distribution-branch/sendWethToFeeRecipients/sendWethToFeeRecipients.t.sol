// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, convert as convertToUd60x18 } from "@prb-math/UD60x18.sol";

contract SendWethToFeeRecipients_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(uint256 marketId) external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });
        marketMakingEngine.sendWethToFeeRecipients(uint128(marketId));
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function test_RevertWhen_TheMarketDoesNotExist() external givenTheSenderIsRegisteredEngine {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 invalidMarketId = FINAL_PERP_MARKET_CREDIT_CONFIG_ID + 1;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, perpsEngine) });

        marketMakingEngine.sendWethToFeeRecipients(invalidMarketId);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function testFuzz_RevertWhen_ThereIsNoAvailableFeesToWithdraw(uint256 marketId)
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoWethFeesCollected.selector) });

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId);
    }

    modifier whenThereIsAvailableFeesToWithdraw() {
        _;
    }

    function testFuzz_RevertWhen_ThereAreNoFeeRecipientsShares(
        uint256 marketId,
        uint256 amount,
        uint256 adapterIndex
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenThereIsAvailableFeesToWithdraw
    {
        // get fuzz dex adapter
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        // get fuzz perp market credit config
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // receive market fee
        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });
        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amount });
        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        // convert accumulated fees to weth
        changePrank({ msgSender: address(perpsEngine) });
        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), adapter.STRATEGY_ID(), bytes("")
        );

        // remove all fee recipients
        changePrank({ msgSender: address(users.owner.account) });
        marketMakingEngine.configureFeeRecipient(address(perpsEngine), 0);
        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoSharesAvailable.selector) });

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId);
    }

    struct TestFuzz_WhenThereAreFeeRecipientsShares_Context {
        uint256 amount;
        uint256 quantityOfFeeRecipients;
        uint256 totalFeeRecipientsShares;
        UD60x18 totalFeeRecipientsSharesX18;
    }

    function testFuzz_WhenThereAreFeeRecipientsShares(
        uint256 marketId,
        uint256 amount,
        uint256 quantityOfFeeRecipients,
        uint256 totalFeeRecipientsShares,
        uint256 adapterIndex
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenThereIsAvailableFeesToWithdraw
    {
        // create context variable
        TestFuzz_WhenThereAreFeeRecipientsShares_Context memory ctx;

        // get fuzz dex adapter
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        // get fuzz perp market credit config
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        // fuzz the usdc amount
        ctx.amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        // deposit the usdc to the perps engine
        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: ctx.amount });

        // perps engine deposit the usdc
        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), ctx.amount);

        // fuzz the quantity of fee recipients
        ctx.quantityOfFeeRecipients = bound({ x: quantityOfFeeRecipients, min: 1, max: 10 });

        // uint256 -> UD60x18
        UD60x18 quantityOfFeeRecipientsX18 = convertToUd60x18(ctx.quantityOfFeeRecipients);

        // fuzz the total fee recipients shares
        ctx.totalFeeRecipientsShares = bound({
            x: totalFeeRecipientsShares,
            min: 0.001e18,
            max: Constants.MAX_CONFIGURABLE_PROTOCOL_FEE_SHARES / 2
        });

        // uint256 -> UD60x18
        ctx.totalFeeRecipientsSharesX18 = ud60x18(ctx.totalFeeRecipientsShares);

        // get the share value per fee recipient
        UD60x18 sharePerFeeRecipientX18 = ctx.totalFeeRecipientsSharesX18.div(quantityOfFeeRecipientsX18);

        // create an array of fee recipeints
        address[] memory feeRecipients = new address[](ctx.quantityOfFeeRecipients);

        changePrank({ msgSender: address(users.owner.account) });

        // set perps engine to not receive fees
        marketMakingEngine.configureFeeRecipient(address(perpsEngine), 0);

        // configure the fee recipients
        for (uint256 i = 0; i < ctx.quantityOfFeeRecipients; i++) {
            feeRecipients[i] = address(uint160(i + 1));
            marketMakingEngine.configureFeeRecipient(feeRecipients[i], sharePerFeeRecipientX18.intoUint256());
        }

        changePrank({ msgSender: address(perpsEngine) });

        // calculate the expected pending protocol weth reward
        uint256 expectedTokenAmount = adapter.getExpectedOutput(address(usdc), address(wEth), ctx.amount);
        uint256 amountOutMin = adapter.calculateAmountOutMin(expectedTokenAmount);
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedPendingProtocolWethRewardX18 =
            amountOutMinX18.mul(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()));

        // convert accumulated fees to weth
        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), adapter.STRATEGY_ID(), bytes("")
        );

        // get pending protocol weth reward
        uint256 amountWeth =
            marketMakingEngine.workaround_getPendingProtocolWethReward(fuzzPerpMarketCreditConfig.marketId);

        UD60x18 expectedFeePerRecipientX18 =
            ud60x18(amountWeth).mul(sharePerFeeRecipientX18).div(ctx.totalFeeRecipientsSharesX18);

        for (uint256 i = 0; i < ctx.quantityOfFeeRecipients; i++) {
            assertEq(
                IERC20(address(wEth)).balanceOf(feeRecipients[i]),
                0,
                "the balance of the fee recipient before the send is wrong"
            );
        }

        // it should emit {LogSendWethToFeeRecipients} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });

        emit FeeDistributionBranch.LogSendWethToFeeRecipients(
            uint128(fuzzPerpMarketCreditConfig.marketId), expectedPendingProtocolWethRewardX18.intoUint256()
        );

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId);

        // it should transfer the fees to the fee recipients
        for (uint256 i = 0; i < ctx.quantityOfFeeRecipients; i++) {
            assertAlmostEq(
                IERC20(address(wEth)).balanceOf(feeRecipients[i]),
                expectedFeePerRecipientX18.intoUint256(),
                1e7,
                "the balance of the fee recipient after the send is wrong"
            );
        }

        // it should decrement the available fees to withdraw
        assertAlmostEq(
            marketMakingEngine.workaround_getPendingProtocolWethReward(fuzzPerpMarketCreditConfig.marketId),
            0,
            ctx.quantityOfFeeRecipients + 1,
            "the available fees to withdraw after the send are wrong"
        );
    }
}
