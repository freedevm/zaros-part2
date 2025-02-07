// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Referral } from "@zaros/referral/Referral.sol";

contract Referral_RegisterReferral_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertWhen_TheReferrerAlreadyHasAReferral() external {
        changePrank({ msgSender: address(perpsEngine) });

        bytes memory referralCode = abi.encode(users.madara.account);

        Referral(address(referralModule)).registerReferral(
            abi.encode(users.owner.account), users.owner.account, referralCode, false
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Referral.ReferralAlreadyExists.selector) });

        Referral(address(referralModule)).registerReferral(
            abi.encode(users.owner.account), users.owner.account, referralCode, false
        );
    }

    modifier whenTheReferrerDoesNotHaveAReferral() {
        _;
    }

    modifier whenTheReferralCodeIsCustom() {
        _;
    }

    function test_RevertWhen_TheReferralCodeIsInvalid()
        external
        whenTheReferrerDoesNotHaveAReferral
        whenTheReferralCodeIsCustom
    {
        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidReferralCode.selector) });

        Referral(address(referralModule)).registerReferral(
            abi.encode(users.naruto.account), users.naruto.account, bytes("customReferralCode"), true
        );
    }

    function test_WhenTheReferralCodeIsValid()
        external
        whenTheReferrerDoesNotHaveAReferral
        whenTheReferralCodeIsCustom
    {
        string memory customReferralCode = "customReferralCode";

        changePrank({ msgSender: address(perpsEngine) });

        Referral(address(referralModule)).createCustomReferralCode(users.owner.account, customReferralCode);

        // it should emit {LogReferralSet} event
        vm.expectEmit({ emitter: address(referralModule) });
        emit Referral.LogReferralSet(
            address(perpsEngine),
            abi.encode(users.naruto.account),
            users.naruto.account,
            bytes(customReferralCode),
            true
        );

        Referral(address(referralModule)).registerReferral(
            abi.encode(users.naruto.account), users.naruto.account, bytes(customReferralCode), true
        );
    }

    modifier whenTheReferralCodeIsNotCustom() {
        _;
    }

    function test_RevertWhen_TheReferralCodeIsEqualToMsgSender()
        external
        whenTheReferrerDoesNotHaveAReferral
        whenTheReferralCodeIsNotCustom
    {
        string memory customReferralCode = "customReferralCode";

        changePrank({ msgSender: address(perpsEngine) });

        Referral(address(referralModule)).createCustomReferralCode(users.naruto.account, customReferralCode);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidReferralCode.selector) });

        bytes memory referralCode = abi.encode(users.naruto.account);

        Referral(address(referralModule)).registerReferral(
            abi.encode(users.naruto.account), users.naruto.account, referralCode, false
        );
    }

    function test_WhenTheReferralCodeIsNotEqualToMsgSender()
        external
        whenTheReferrerDoesNotHaveAReferral
        whenTheReferralCodeIsNotCustom
    {
        string memory customReferralCode = "customReferralCode";

        changePrank({ msgSender: address(perpsEngine) });

        Referral(address(referralModule)).createCustomReferralCode(users.naruto.account, customReferralCode);

        bytes memory referralCode = abi.encode(users.sakura.account);

        // it should emit {LogReferralSet} event
        address referralModule = perpsEngine.workaround_getReferralModule();
        vm.expectEmit({ emitter: referralModule });
        emit Referral.LogReferralSet(
            address(perpsEngine), abi.encode(users.owner.account), users.owner.account, referralCode, false
        );

        Referral(address(referralModule)).registerReferral(
            abi.encode(users.owner.account), users.owner.account, referralCode, false
        );
    }
}
