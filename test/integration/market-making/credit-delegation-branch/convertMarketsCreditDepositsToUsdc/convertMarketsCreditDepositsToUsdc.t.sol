// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract CreditDelegationBranch_ConvertMarketsCreditDepositsToUsdc_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_AssetsAndDexSwapStrategyIdArraysLengthMismatch(uint256 marketId) external {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        address[] memory assets = new address[](1);
        uint128[] memory dexSwapStrategyIds = new uint128[](2);
        bytes[] memory paths = new bytes[](2);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ArrayLengthMismatch.selector, 0, 0));

        marketMakingEngine.convertMarketsCreditDepositsToUsdc(
            fuzzMarketConfig.marketId, assets, dexSwapStrategyIds, paths
        );
    }

    modifier whenAssetsAndDexSwapStrategyIdArraysLengthMatch() {
        _;
    }

    function testFuzz_RevertWhen_AssetsAndPathsArraysLengthMismatch(uint256 marketId)
        external
        whenAssetsAndDexSwapStrategyIdArraysLengthMatch
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        address[] memory assets = new address[](2);
        uint128[] memory dexSwapStrategyIds = new uint128[](2);
        bytes[] memory paths = new bytes[](1);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ArrayLengthMismatch.selector, 0, 0));

        marketMakingEngine.convertMarketsCreditDepositsToUsdc(
            fuzzMarketConfig.marketId, assets, dexSwapStrategyIds, paths
        );
    }

    modifier whenAssetsAndPathsArraysLengthMatch() {
        _;
    }

    function test_RevertWhen_TheMarketIdIsInvalid()
        external
        whenAssetsAndDexSwapStrategyIdArraysLengthMatch
        whenAssetsAndPathsArraysLengthMatch
    {
        changePrank({ msgSender: address(perpsEngine) });
        address[] memory assets;
        uint128[] memory dexSwapStrategyIds;
        bytes[] memory paths;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, 0));

        marketMakingEngine.convertMarketsCreditDepositsToUsdc(0, assets, dexSwapStrategyIds, paths);
    }

    modifier whenTheMarketIdIsValid() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesNotContainAnAssetFromTheArray(uint256 marketId)
        external
        whenAssetsAndDexSwapStrategyIdArraysLengthMatch
        whenAssetsAndPathsArraysLengthMatch
        whenTheMarketIdIsValid
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        address fakeAsset = address(123);

        address[] memory assets = new address[](1);
        assets[0] = fakeAsset;
        uint128[] memory dexSwapStrategyIds = new uint128[](1);
        bytes[] memory paths = new bytes[](1);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketDoesNotContainTheAsset.selector, fakeAsset));

        marketMakingEngine.convertMarketsCreditDepositsToUsdc(
            fuzzMarketConfig.marketId, assets, dexSwapStrategyIds, paths
        );
    }

    function testFuzz_WhenTheMarketContainsAllAssetsFromTheArray(
        uint128 marketId,
        uint256 adapterIndex,
        uint256 depositAmount
    )
        external
        whenAssetsAndDexSwapStrategyIdArraysLengthMatch
        whenAssetsAndPathsArraysLengthMatch
        whenTheMarketIdIsValid
    {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        IDexAdapter dexAdapter = getFuzzDexAdapter(adapterIndex);

        depositAmount = bound({ x: depositAmount, min: 100, max: type(uint16).max });
        deal({ token: address(wBtc), to: address(fuzzMarketConfig.engine), give: depositAmount });

        address[] memory assets = new address[](1);
        assets[0] = address(wBtc);

        uint128[] memory dexSwapStrategyIds = new uint128[](1);
        dexSwapStrategyIds[0] = dexAdapter.STRATEGY_ID();

        bytes[] memory paths = new bytes[](1);
        paths[0] = bytes("");

        changePrank({ msgSender: address(fuzzMarketConfig.engine) });
        IERC20(wBtc).approve(address(marketMakingEngine), depositAmount);

        // load collateral data
        Collateral.Data memory wbtcCollateral = marketMakingEngine.exposed_Collateral_load(address(wBtc));

        // verify market has $0 usd value deposited
        assertEq(marketMakingEngine.workaround_getCreditDepositsValueUsd(marketId), 0);

        // perform the credit deposit
        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, address(wBtc), depositAmount);

        // verify that the deposited amount is stored internally using 18 decimals
        uint256 internalDepositAmount =
            marketMakingEngine.workaround_getMarketCreditDeposit(fuzzMarketConfig.marketId, address(wBtc));
        assertEq(internalDepositAmount, depositAmount * 10 ** (Constants.SYSTEM_DECIMALS - wbtcCollateral.decimals));

        uint256 expectedAmountOut = dexAdapter.getExpectedOutput(address(wBtc), address(usdc), depositAmount);
        uint256 usdcOut = dexAdapter.calculateAmountOutMin(expectedAmountOut);

        changePrank({ msgSender: address(perpsEngine) });

        // it should emit { LogConvertMarketCreditDepositsToUsdc } event
        vm.expectEmit();
        emit CreditDelegationBranch.LogConvertMarketCreditDepositsToUsdc(
            fuzzMarketConfig.marketId, address(wBtc), internalDepositAmount, usdcOut
        );

        marketMakingEngine.convertMarketsCreditDepositsToUsdc(
            fuzzMarketConfig.marketId, assets, dexSwapStrategyIds, paths
        );
    }
}
