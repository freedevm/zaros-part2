// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { ITradingAccountNFT } from "@zaros/trading-account-nft/interfaces/ITradingAccountNFT.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { TradingAccount } from "@zaros/perpetuals/leaves/TradingAccount.sol";
import { PerpsEngineConfiguration } from "@zaros/perpetuals/leaves/PerpsEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";

// Open Zeppelin dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract TradingAccountBranchTestnet is TradingAccountBranch, Initializable, OwnableUpgradeable {
    using TradingAccount for TradingAccount.Data;
    using PerpsEngineConfiguration for PerpsEngineConfiguration.Data;

    mapping(address user => bool accountCreated) internal isAccountCreated;

    error UserAlreadyHasAccount();
    error FaucetAlreadyDeposited();

    constructor() {
        _disableInitializers();
    }

    function isUserAccountCreated(address user) external view returns (bool) {
        return isAccountCreated[user];
    }

    function createTradingAccount(bytes memory referralCode, bool isCustomReferralCode) public override returns (uint128) {
        bool userHasAccount = isAccountCreated[msg.sender];
        if (userHasAccount) {
            revert UserAlreadyHasAccount();
        }

        return super.createTradingAccount(referralCode, isCustomReferralCode);
    }

    function createTradingAccountWithSender(address sender, bytes memory referralCode, bool isCustomReferralCode) public onlyOwner returns (uint128 tradingAccountId) {
        bool userHasAccount = isAccountCreated[sender];
        if (userHasAccount) {
            revert UserAlreadyHasAccount();
        }

        // fetch storage slot for perps engine configuration
        PerpsEngineConfiguration.Data storage perpsEngineConfiguration = PerpsEngineConfiguration.load();

        // increment next account id & output
        tradingAccountId = ++perpsEngineConfiguration.nextAccountId;

        // get refrence to account nft token
        ITradingAccountNFT tradingAccountToken = ITradingAccountNFT(perpsEngineConfiguration.tradingAccountToken);

        // create account record
        TradingAccount.create(tradingAccountId, sender);

        // mint nft token to account owner
        tradingAccountToken.mint(sender, tradingAccountId);

        emit LogCreateTradingAccount(tradingAccountId, sender);

        IReferral referralModule = IReferral(perpsEngineConfiguration.referralModule);

        if (referralCode.length != 0) {
            referralModule.registerReferral(
                abi.encode(tradingAccountId), msg.sender, referralCode, isCustomReferralCode
            );
        }

        isAccountCreated[sender] = true;

        return tradingAccountId;
    }
}
