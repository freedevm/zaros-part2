// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";

contract GetReferrerAddress_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function test_WhenReferralCodeIsCustom() external {
        changePrank({ msgSender: users.owner.account });

        string memory customReferralCode = "Naruto Uzumaki";
        bytes memory bytesReferralCode = bytes(customReferralCode);

        perpsEngine.createCustomReferralCode(users.naruto.account, customReferralCode);

        uint128 tradingAccountId = perpsEngine.createTradingAccount(bytesReferralCode, true);

        address referralCodeAddress = IReferral(perpsEngine.workaround_getReferralModule()).getReferrerAddress(
            address(perpsEngine), abi.encode(tradingAccountId)
        );

        // it should return the address of referrer
        assertEq(referralCodeAddress, users.naruto.account, "the referrer is not correct");
    }

    function test_WhenReferralCodeIsNotCustom() external {
        changePrank({ msgSender: users.owner.account });

        uint128 tradingAccountId = perpsEngine.createTradingAccount(abi.encode(users.naruto.account), false);

        (bytes memory referralCode,) = perpsEngine.getUserReferralData(tradingAccountId);

        // it should return the address of referrer
        assertEq(abi.decode(referralCode, (address)), users.naruto.account, "the referrer is not correct");
    }
}
