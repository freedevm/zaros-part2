// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Referral } from "@zaros/referral/Referral.sol";

contract Referral_GetUserReferralData_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_WhenGetUserReferralDataIsCalled(bool isCustomReferralCode) external {
        string memory customReferralCode = "customReferralCode";
        bytes memory bytesReferralCode;

        if (isCustomReferralCode) {
            changePrank({ msgSender: address(perpsEngine) });
            Referral(address(referralModule)).createCustomReferralCode(users.owner.account, "customReferralCode");
            bytesReferralCode = bytes(customReferralCode);
        } else {
            bytesReferralCode = abi.encode(users.owner.account);
        }

        changePrank({ msgSender: users.naruto.account });

        uint128 tradingAccountId = perpsEngine.createTradingAccount(bytesReferralCode, isCustomReferralCode);

        changePrank({ msgSender: address(perpsEngine) });

        (bytes memory receivedReferralCode, bool receivedIsCustomReferralCode) =
            Referral(address(referralModule)).getUserReferralData(abi.encode(tradingAccountId));

        // it should return the referral code
        assertEq(bytesReferralCode, receivedReferralCode, "referral code is not correct");

        // it should return if the referal code is custom
        assertEq(isCustomReferralCode, receivedIsCustomReferralCode, "isCustomReferralCode is not correct");
    }
}
