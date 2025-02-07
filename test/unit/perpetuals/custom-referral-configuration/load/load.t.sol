// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";

contract CustomReferralConfiguration_Load_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_WhenLoadIsCalled() external {
        changePrank({ msgSender: users.owner.account });

        string memory customReferralCode = "Madara Uchiha";

        perpsEngine.createCustomReferralCode(users.madara.account, customReferralCode);

        address referralCodeAddress =
            IReferral(perpsEngine.workaround_getReferralModule()).getCustomReferralCodeReferrer(customReferralCode);

        // it should return the referrer
        assertEq(referralCodeAddress, users.madara.account, "the address of referrer is not correct");
    }
}
