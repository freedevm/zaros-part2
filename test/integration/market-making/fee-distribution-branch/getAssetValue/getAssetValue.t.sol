// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

contract MarketMakingEngineConfigurationBranch_GetAssetValue_Integration_Test is Base_Test {
    function test_WhenGetAssetValueIsCalled(uint256 amount) external {
        amount = bound({ x: amount, min: 1, max: type(uint96).max });

        uint256 value = marketMakingEngine.getAssetValue(address(usdc), amount);

        // it should return the asset value
        assertEq(value, amount * MOCK_USDC_USD_PRICE / 1e6);
    }
}
