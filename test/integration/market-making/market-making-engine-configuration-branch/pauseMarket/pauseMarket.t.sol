// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_PauseMarket_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.pauseMarket(fuzzMarketConfig.marketId);
    }

    function testFuzz_GivenTheSenderIsTheOwner(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint128[] memory activeMarketIds = marketMakingEngine.getLiveMarketIds();

        // it should pause the market
        bool paused;

        for (uint256 i; i < activeMarketIds.length; i++) {
            if (activeMarketIds[i] == fuzzMarketConfig.marketId) {
                paused = true;
            }
        }

        assertFalse(paused);
    }
}
