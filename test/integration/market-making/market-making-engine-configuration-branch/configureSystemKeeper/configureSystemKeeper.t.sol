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

contract MarketMakingEngineConfigurationBranch_ConfigureSystemKeeper_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(bool isEnabled) external {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureSystemKeeper(address(0x123), isEnabled);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_SystemKeeperIsZero(bool isEnabled) external givenTheSenderIsTheOwner {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "systemKeeper") });

        marketMakingEngine.configureSystemKeeper(address(0), isEnabled);
    }

    function testFuzz_WhenSystemKeeperIsNotZero(bool isEnabled) external givenTheSenderIsTheOwner {
        address systemKeeper = address(0x123);

        // it should emit {LogConfigureSystemKeeper} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfigureSystemKeeper(systemKeeper, isEnabled);

        marketMakingEngine.configureSystemKeeper(systemKeeper, isEnabled);

        // it should update the marketMakingEngineConfiguration storage
        assertEq(
            marketMakingEngine.workaround_getIfSystemKeeperIsEnabled(systemKeeper),
            isEnabled,
            "system keeper permission should be update in the storage"
        );
    }
}
