// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { CustomReferralConfiguration } from "@zaros/referral/leaves/CustomReferralConfiguration.sol";

library ReferralConfiguration {
    /// @notice ERC7201 storage location.
    bytes32 internal constant REFERRAL_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.referral.ReferralConfiguration")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice {Referral} namespace storage structure.
    /// @param referralCode ABI encoded referral code, may be a string or address.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    struct ConfigurationData {
        bytes referralCode;
        bool isCustomReferralCode;
    }

    struct Data {
        mapping(bytes referrer => ConfigurationData configurationData) listOfReferrals;
    }

    /// @notice Loads a {Referral}.
    /// @param engine The engine address.
    /// @return referral The user referral data.
    function load(address engine) internal pure returns (Data storage referral) {
        bytes32 slot = keccak256(abi.encode(REFERRAL_LOCATION, engine));
        assembly {
            referral.slot := slot
        }
    }

    /// @notice Returns the address of the referrer according to the referral code.
    /// @return referrer The referrer address.
    function getReferrerAddress(
        Data storage self,
        bytes memory referrerCode
    )
        internal
        view
        returns (address referrer)
    {
        bytes memory referralCode = self.listOfReferrals[referrerCode].referralCode;

        if (!self.listOfReferrals[referrerCode].isCustomReferralCode) {
            referrer = abi.decode(referralCode, (address));
        } else {
            referrer = CustomReferralConfiguration.load(string(referralCode)).referrer;
        }
    }
}
