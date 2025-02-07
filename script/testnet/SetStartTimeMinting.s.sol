// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { ProtocolConfiguration } from "../utils/ProtocolConfiguration.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

/// @dev This script is used to set the start time minting for the LimitedMintingERC20 token.
contract SetStartTimeMinting is BaseScript, ProtocolConfiguration {
    function run() public broadcaster {
        uint256 startTimeMinting = 1_725_380_400; // 03st Sep 2024 16:20:00 UTC

        LimitedMintingERC20(USDC_ADDRESS).setStartTimeMinting(startTimeMinting);

        console.log("Start time minting set to: ", startTimeMinting);
    }
}
