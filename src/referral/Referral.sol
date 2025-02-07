// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { ReferralConfiguration } from "@zaros/referral/leaves/ReferralConfiguration.sol";
import { CustomReferralConfiguration } from "@zaros/referral/leaves/CustomReferralConfiguration.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Referral contract.
/// @dev This contract is responsible for managing referrals.
/// @dev Referrals are used to track the referrer of a user.
/// @dev In the current version of the contract each user can have only one referrer per engine.
contract Referral is IReferral, OwnableUpgradeable, UUPSUpgradeable {
    using ReferralConfiguration for ReferralConfiguration.Data;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Mapping of registered engines.
    mapping(address engine => bool isAllowed) public registeredEngines;

    /*//////////////////////////////////////////////////////////////////////////
                                     EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a referral is set.
    /// @param engine The engine address.
    /// @param referrerCode The referral code used by the referrer.
    /// @param referrerAddress The address of the referrer.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    event LogReferralSet(
        address indexed engine,
        bytes referrerCode,
        address referrerAddress,
        bytes referralCode,
        bool isCustomReferralCode
    );

    /// @notice Emitted when a custom referral code is created.
    /// @param referrer The address of the referrer.
    /// @param customReferralCode The custom referral code.
    event LogCreateCustomReferralCode(address referrer, string customReferralCode);

    /// @notice Emitted when an engine is configured.
    /// @param engine The engine address.
    /// @param isEnabled True if the engine is enabled.
    event LogConfigureEngine(address engine, bool isEnabled);

    /*//////////////////////////////////////////////////////////////////////////
                                     ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the engine tries to set a new referral to a referrer that already has a referral.
    error ReferralAlreadyExists();

    /// @notice Emitted when the engine tries to set a referral with an invalid referral code.
    error InvalidReferralCode();

    /// @notice Emitted when the engine is not registered.
    error EngineNotRegistered(address engine);

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if the engine is registered.
    modifier onlyRegisteredEngines() {
        if (registeredEngines[msg.sender] == false) {
            revert EngineNotRegistered(msg.sender);
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INITIALIZE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Disables initialize functions at the implementation.
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IReferral
    function getReferrerAddress(address engine, bytes calldata referrerCode) public view returns (address referrer) {
        // load the referral configuration from storage
        ReferralConfiguration.Data storage referralConfiguration = ReferralConfiguration.load(engine);

        // get the referrer address
        referrer = referralConfiguration.getReferrerAddress(referrerCode);
    }

    /// @inheritdoc IReferral
    function getCustomReferralCodeReferrer(string calldata customReferralCode)
        external
        view
        returns (address referrer)
    {
        referrer = CustomReferralConfiguration.load(customReferralCode).referrer;
    }

    /// @inheritdoc IReferral
    function createCustomReferralCode(
        address referrer,
        string calldata customReferralCode
    )
        external
        onlyRegisteredEngines
    {
        CustomReferralConfiguration.load(customReferralCode).referrer = referrer;

        emit LogCreateCustomReferralCode(referrer, customReferralCode);
    }

    /// @inheritdoc IReferral
    function getUserReferralData(bytes calldata referrer)
        external
        view
        returns (bytes memory referralCode, bool isCustomReferralCode)
    {
        // load the referral configuration from storage
        ReferralConfiguration.Data storage referralConfiguration = ReferralConfiguration.load(msg.sender);

        // get the referral code
        referralCode = referralConfiguration.listOfReferrals[referrer].referralCode;

        // get the custom referral code flag
        isCustomReferralCode = referralConfiguration.listOfReferrals[referrer].isCustomReferralCode;
    }

    /// @inheritdoc IReferral
    function verifyIfUserHasReferral(bytes memory referrer) public view returns (bool) {
        // load the referral configuration from storage
        ReferralConfiguration.Data storage referralConfiguration = ReferralConfiguration.load(msg.sender);

        // check if the referrer has a referral
        return referralConfiguration.listOfReferrals[referrer].referralCode.length > 0;
    }

    /// @inheritdoc IReferral
    function registerReferral(
        bytes calldata referrerCode,
        address referrerAddress,
        bytes calldata referralCode,
        bool isCustomReferralCode
    )
        external
        onlyRegisteredEngines
    {
        // load the referral configuration from storage
        ReferralConfiguration.Data storage referralConfiguration = ReferralConfiguration.load(msg.sender);

        // revert if the referrer already has a referral
        if (verifyIfUserHasReferral(referrerCode)) {
            revert ReferralAlreadyExists();
        }

        // verify if the referral code is not empty
        if (referralCode.length != 0) {
            // verify if the referral code is a custom referral code
            if (isCustomReferralCode) {
                // load the custom referral configuration from storage
                CustomReferralConfiguration.Data storage customReferral =
                    CustomReferralConfiguration.load(string(referralCode));

                // revert if the custom referral code is not valid
                address referrerCache = customReferral.referrer;
                if (referrerCache == address(0) || referrerCache == referrerAddress) {
                    revert InvalidReferralCode();
                }

                // set the custom referral code flag
                referralConfiguration.listOfReferrals[referrerCode].isCustomReferralCode = true;
            } else {
                // revert if the referral code decoded is the same as the referrer address
                if (referrerAddress == abi.decode(referralCode, (address))) {
                    revert InvalidReferralCode();
                }

                // set the custom referral code flag
                referralConfiguration.listOfReferrals[referrerCode].isCustomReferralCode = false;
            }

            // set the referral code
            referralConfiguration.listOfReferrals[referrerCode].referralCode = referralCode;

            // emit the LogReferralSet event
            emit LogReferralSet(msg.sender, referrerCode, referrerAddress, referralCode, isCustomReferralCode);
        }
    }

    /// @inheritdoc IReferral
    /// @dev Only the owner can update the implementation.
    function configureEngine(address engine, bool isEnabled) external onlyOwner {
        // revert if the engine address is zero
        if (engine == address(0)) {
            revert Errors.ZeroInput("engine");
        }

        // set the engine status
        registeredEngines[engine] = isEnabled;

        // emit the LogEngineConfigured event
        emit LogConfigureEngine(engine, isEnabled);
    }

    /// @notice Upgrades the implementation of the contract.
    /// @dev Only the owner can update the implementation.
    /// @param newImplementation The new implementation address.
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }
}
