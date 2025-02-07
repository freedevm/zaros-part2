// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeConversionKeeper } from "@zaros/external/chainlink/keepers/fee-conversion-keeper/FeeConversionKeeper.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract FeeConversionKeeper_Initialize_Integration_Test is Base_Test {
    function testFuzz_RevertWhen_AddressOfMarketMakingEngineIsZero(uint128 minFeeDistributionValueUsd) external {
        address feeConversionKeeperImplementation = address(new FeeConversionKeeper());

        uint128 dexSwapStrategyId = 1;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketMakingEngine") });

        new ERC1967Proxy(
            feeConversionKeeperImplementation,
            abi.encodeWithSelector(
                FeeConversionKeeper.initialize.selector,
                users.owner.account,
                address(0),
                dexSwapStrategyId,
                minFeeDistributionValueUsd
            )
        );
    }

    modifier whenAddressOfEngineIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_DexSwapStrategyAdapterIsAddressZero(uint128 minFeeDistributionValueUsd)
        external
        whenAddressOfEngineIsNotZero
    {
        address feeConversionKeeperImplementation = address(new FeeConversionKeeper());

        uint128 dexSwapStrategyId = 0;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.DexSwapStrategyHasAnInvalidDexAdapter.selector, dexSwapStrategyId)
        });

        new ERC1967Proxy(
            feeConversionKeeperImplementation,
            abi.encodeWithSelector(
                FeeConversionKeeper.initialize.selector,
                users.owner.account,
                marketMakingEngine,
                dexSwapStrategyId,
                minFeeDistributionValueUsd
            )
        );
    }

    modifier whenDexSwapStrategyAdapterIsNotAddressZero() {
        _;
    }

    function test_RevertWhen_MinFeeDistributionValueIsZero()
        external
        whenAddressOfEngineIsNotZero
        whenDexSwapStrategyAdapterIsNotAddressZero
    {
        address feeConversionKeeperImplementation = address(new FeeConversionKeeper());

        uint128 dexSwapStrategyId = 1;
        uint128 minFeeDistributionValueUsd = 0;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketMakingEngine") });

        new ERC1967Proxy(
            feeConversionKeeperImplementation,
            abi.encodeWithSelector(
                FeeConversionKeeper.initialize.selector,
                users.owner.account,
                address(0),
                dexSwapStrategyId,
                minFeeDistributionValueUsd
            )
        );
    }

    function testFuzz_WhenMinFeeDistributionValueIsNotZero(uint128 minFeeDistributionValueUsd)
        external
        whenAddressOfEngineIsNotZero
        whenDexSwapStrategyAdapterIsNotAddressZero
    {
        vm.assume(minFeeDistributionValueUsd > 0);
        address feeConversionKeeperImplementation = address(new FeeConversionKeeper());

        uint128 dexSwapStrategyId = 1;

        // it should initialize
        new ERC1967Proxy(
            feeConversionKeeperImplementation,
            abi.encodeWithSelector(
                FeeConversionKeeper.initialize.selector,
                users.owner.account,
                marketMakingEngine,
                dexSwapStrategyId,
                minFeeDistributionValueUsd
            )
        );
    }
}
