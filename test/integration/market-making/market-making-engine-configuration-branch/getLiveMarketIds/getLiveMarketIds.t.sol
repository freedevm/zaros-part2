// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

contract MarketMakingEngineConfigurationBranch_GetLiveMarketIds_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        configureMarkets();
    }

    function test_WhenGetLiveMarketIdsIsCalled() external {
        uint128[] memory limeMarketIds = marketMakingEngine.getLiveMarketIds();

        // it should return the live market ids
        assertTrue(limeMarketIds.length > 0);
    }
}
