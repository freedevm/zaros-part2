// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Referral } from "@zaros/referral/Referral.sol";

contract Referral_VerifyIfUserHasReferral_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_WhenTheUserHasAReferral() external {
        changePrank({ msgSender: address(perpsEngine) });

        bytes memory referralCode = abi.encode(users.madara.account);

        Referral(address(referralModule)).registerReferral(
            abi.encode(users.owner.account), users.owner.account, referralCode, false
        );

        // it should return true
        assertEq(
            true,
            Referral(address(referralModule)).verifyIfUserHasReferral(abi.encode(users.owner.account)),
            "The return should be true"
        );
    }

    function test_WhenTheUserDoesNotHaveAReferral() external {
        changePrank({ msgSender: address(perpsEngine) });

        // it should return false
        assertEq(
            false,
            Referral(address(referralModule)).verifyIfUserHasReferral(abi.encode(users.owner.account)),
            "The return should be false"
        );
    }
}
