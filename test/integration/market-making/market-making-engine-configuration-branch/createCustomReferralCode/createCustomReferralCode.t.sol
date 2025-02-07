// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Referral } from "@zaros/referral/Referral.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_CreateCustomReferralCode_Integration_Test is Base_Test {
    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(address referrer) external {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.createCustomReferralCode(referrer, "");
    }

    function test_GivenTheSenderIsTheOwner(address referrer) external {
        changePrank({ msgSender: users.owner.account });

        // it should emit { LogCreateCustomReferralCode } event
        vm.expectEmit();
        emit Referral.LogCreateCustomReferralCode(referrer, "");

        marketMakingEngine.createCustomReferralCode(referrer, "");
    }
}
