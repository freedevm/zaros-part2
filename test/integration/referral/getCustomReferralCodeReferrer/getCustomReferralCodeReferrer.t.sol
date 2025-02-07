// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Referral } from "@zaros/referral/Referral.sol";

contract Referral_GetCustomReferralCode_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_WhenGetCustomReferralCodeIsCalled(
        address referrer,
        string memory customReferralCode
    )
        external
    {
        changePrank({ msgSender: address(perpsEngine) });
        Referral(address(referralModule)).createCustomReferralCode(referrer, customReferralCode);

        changePrank({ msgSender: users.naruto.account });

        // it should the address of the referrer
        address referrerReceived = Referral(address(referralModule)).getCustomReferralCodeReferrer(customReferralCode);
        assertEq(referrerReceived, referrer, "Referrer not set correctly");
    }
}
