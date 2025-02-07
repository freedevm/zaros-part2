// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract Referral_Load_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_WhenLoadIsCalled() external {
        changePrank({ msgSender: users.owner.account });

        uint128 tradingAccountId = perpsEngine.createTradingAccount(abi.encode(users.naruto.account), false);

        (bytes memory referralCode, bool isCustomReferralCode) = perpsEngine.getUserReferralData(tradingAccountId);

        // it should return the referral code
        assertEq(abi.decode(referralCode, (address)), users.naruto.account, "the referral code is not correct");

        // it should return if referral code is custom
        assertEq(isCustomReferralCode, false, "the flag `isCustomReferralCode` should be false");

        string memory customReferralCode = "Madara Uchiha";
        bytes memory bytesReferralCode = bytes(customReferralCode);

        perpsEngine.createCustomReferralCode(users.madara.account, customReferralCode);

        changePrank({ msgSender: users.sakura.account });

        tradingAccountId = perpsEngine.createTradingAccount(bytesReferralCode, true);

        (referralCode, isCustomReferralCode) = perpsEngine.getUserReferralData(tradingAccountId);

        // it should return the referral code
        assertEq(referralCode, bytesReferralCode, "the referral code is not correct");

        // it should return if referral code is custom
        assertEq(isCustomReferralCode, true, "the flag `isCustomReferralCode` should be trye");
    }
}
