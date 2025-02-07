// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Sequencer Uptime Feeds
import { Arbitrum } from "./Arbitrum.sol";

contract SequencerUptimeFeeds is Arbitrum {
    mapping(uint256 chainId => address sequencerUptimeFeed) internal sequencerUptimeFeedByChainId;

    function setupSequencerUptimeFeeds() internal {
        // arbitrum sequencer uptime feed
        sequencerUptimeFeedByChainId[ARBITRUM_CHAIN_ID] = ARBITRUM_SEQUENCER_UPTIME_FEED;
    }
}
