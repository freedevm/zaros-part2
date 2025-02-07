// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

contract MarketMakingEngineConfigurationBranch_GetDexSwapStrategy_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_WhenGetDexSwapStrategyIsCalled(uint128 adapterIndex) external {
        vm.assume(adapterIndex > 0);

        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        DexSwapStrategy.Data memory data = marketMakingEngine.getDexSwapStrategy(adapter.STRATEGY_ID());

        // it should return the dex swap strategy data
        assertEq(data.dexAdapter, address(adapter));
    }
}
