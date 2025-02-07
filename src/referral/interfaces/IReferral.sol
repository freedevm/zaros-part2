// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice The interface for the Referral contract.
interface IReferral {
    /// @notice Gets the referrer address for a referral code.
    /// @param engine The engine address.
    /// @param referralCode The referral code.
    /// @return referrer The referrer address.
    function getReferrerAddress(address engine, bytes memory referralCode) external view returns (address referrer);

    /// @notice Gets the custom referral code address.
    /// @param customReferralCode The custom referral code.
    /// @return referrer The referrer address.
    function getCustomReferralCodeReferrer(string memory customReferralCode)
        external
        view
        returns (address referrer);

    /// @notice Creates a custom referral code.
    /// @param referrer The address of the referrer.
    /// @param customReferralCode The custom referral code.
    function createCustomReferralCode(address referrer, string memory customReferralCode) external;

    /// @notice Configures an engine to be allowed to interact with the referral contract.
    /// @param engine The engine address.
    /// @param isEnabled True if the engine is allowed to interact with the referral contract.
    function configureEngine(address engine, bool isEnabled) external;

    /// @notice Gets the referral data for a referrer.
    /// @param referrer The referrer identifier.
    /// @return referralCode The referral code used by the referrer.
    /// @return isCustomReferralCode True if the referral code is a custom referral code.
    function getUserReferralData(bytes memory referrer)
        external
        view
        returns (bytes memory referralCode, bool isCustomReferralCode);

    /// @notice Verifies if a referrer has a referral and returns a boolean.
    /// @param referrer The referrer identifier.
    /// @return True if the referrar has a referral or false otherwise.
    function verifyIfUserHasReferral(bytes memory referrer) external view returns (bool);

    /// @notice Registers a referral for a referrer.
    /// @dev This will revert if the referrer already has a referral.
    /// @param referrerCode The referrer identifier.
    /// @param referrerAddres The address of the referrer.
    /// @param referralCode The referral code used by the referrer.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    function registerReferral(
        bytes memory referrerCode,
        address referrerAddres,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external;
}
