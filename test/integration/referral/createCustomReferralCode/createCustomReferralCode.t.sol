// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Referral } from "@zaros/referral/Referral.sol";

contract Referral_CreateCustomReferralCode_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheRegisteredEngine(
        address referrer,
        string memory customReferralCode
    )
        external
    {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Referral.EngineNotRegistered.selector, users.naruto.account)
        });

        Referral(address(referralModule)).createCustomReferralCode(referrer, customReferralCode);
    }

    modifier givenTheSenderIsTheRegisteredEngine() {
        _;
    }

    function testFuzz_WhenCreateCustomReferralCodeIsCalled(
        address referrer,
        string memory customReferralCode
    )
        external
        givenTheSenderIsTheRegisteredEngine
    {
        changePrank({ msgSender: address(perpsEngine) });

        // it should emit {LogCreateCustomReferralCode} event
        address referralModule = perpsEngine.workaround_getReferralModule();
        vm.expectEmit({ emitter: referralModule });
        emit Referral.LogCreateCustomReferralCode(referrer, customReferralCode);

        Referral(address(referralModule)).createCustomReferralCode(referrer, customReferralCode);

        // it should the custom referral code and referrer on storage
        address referrerReceived = perpsEngine.getCustomReferralCodeReferrer(customReferralCode);
        assertEq(referrerReceived, referrer, "Referrer not set correctly");
    }
}
