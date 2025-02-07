// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureReferralModule_Integration_Test is Base_Test {
    function test_RevertGiven_TheSenderIsNotTheOwner() external {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureReferralModule(address(referralModule));
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function test_RevertWhen_TheReferralModuleIsTheZeroAddress() external givenTheSenderIsTheOwner {
        changePrank({ msgSender: users.owner.account });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "referralModule"));

        marketMakingEngine.configureReferralModule(address(0));
    }

    function test_WhenTheReferralModuleIsNotTheZeroAddress() external givenTheSenderIsTheOwner {
        changePrank({ msgSender: users.owner.account });

        // it should emit { LogConfigureReferralModule } event
        vm.expectEmit();
        emit MarketMakingEngineConfigurationBranch.LogConfigureReferralModule(
            users.owner.account, address(referralModule)
        );

        marketMakingEngine.configureReferralModule(address(referralModule));
    }
}
