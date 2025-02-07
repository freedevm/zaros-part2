// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { UniswapV3Adapter } from "@zaros/utils/dex-adapters/UniswapV3Adapter.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureDexSwapStrategy_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(uint128 dexSwapStrategyId) external {
        vm.assume(dexSwapStrategyId > 0);

        changePrank({ msgSender: users.sakura.account });

        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureDexSwapStrategy(dexSwapStrategyId, address(uniswapV3Adapter));
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_DexSwapStrategyIdIsZero(address adapter) external givenTheSenderIsTheOwner {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "dexSwapStrategyId") });

        marketMakingEngine.configureDexSwapStrategy(0, adapter);
    }

    modifier whenDexSwapStrategyIdIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_DexAdapterIsZero(uint128 dexSwapStrategyId)
        external
        givenTheSenderIsTheOwner
        whenDexSwapStrategyIdIsNotZero
    {
        vm.assume(dexSwapStrategyId > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "dexAdapter") });

        marketMakingEngine.configureDexSwapStrategy(dexSwapStrategyId, address(0));
    }

    function testFuzz_WhenDexAdapterIsNotZero(uint128 dexSwapStrategyId)
        external
        givenTheSenderIsTheOwner
        whenDexSwapStrategyIdIsNotZero
    {
        vm.assume(dexSwapStrategyId > 0);

        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();

        // it should emit {LogConfigureDexSwapStrategy} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfigureDexSwapStrategy(
            dexSwapStrategyId, address(uniswapV3Adapter)
        );

        marketMakingEngine.configureDexSwapStrategy(dexSwapStrategyId, address(uniswapV3Adapter));

        // it should update the dex swap strategy storage
        assertEq(
            marketMakingEngine.exposed_dexSwapStrategy_load(dexSwapStrategyId).id,
            dexSwapStrategyId,
            "the dex swap strategy should be have the id equal to the dexSwapStrategyId variable"
        );
        assertEq(
            marketMakingEngine.exposed_dexSwapStrategy_load(dexSwapStrategyId).dexAdapter,
            address(uniswapV3Adapter),
            "the dex swap strategy should be have the dex adapter equal to the uniswapV3Adapter variable"
        );
    }
}
