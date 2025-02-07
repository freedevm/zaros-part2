// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

/// @dev This script creates a list of custom referral codes for a list of referrers
contract CreateListOfCustomReferrals is BaseScript {
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        address[] memory referrers = new address[](4);

        referrers[0] = address(0xeA6930f85b5F52507AbE7B2c5aF1153391BEb2b8);
        referrers[1] = address(0x3aba3AAb97accFBB51B2e97186ED647775352878);
        referrers[2] = address(0x28F4a9a2E747ec2cb1b4E235a55DFF5bE2EF48D6);
        referrers[3] = address(0x73436522e6193f2980b0a3210E22Abe5ed4F09b9);

        string[] memory customReferralCodes = new string[](4);

        customReferralCodes[0] = "0x3078506564726f";
        customReferralCodes[1] = "0x61666978797a";
        customReferralCodes[2] = "0x53746b";
        customReferralCodes[3] = "0x677569";

        for (uint256 i; i < referrers.length; i++) {
            perpsEngine.createCustomReferralCode(referrers[i], customReferralCodes[i]);
        }

        console.log("Custom referral codes created successfully");
    }
}
