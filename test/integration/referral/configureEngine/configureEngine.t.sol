// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Referral } from "@zaros/referral/Referral.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract Referral_ConfigureEngine_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(address engine, bool isEnabled) external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.naruto.account)
        });

        referralModule.configureEngine(engine, isEnabled);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_TheEngineIsZero(bool isEnabled) external givenTheSenderIsTheOwner {
        address engine = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "engine") });

        referralModule.configureEngine(engine, isEnabled);
    }

    function testFuzz_WhenTheEngineIsNotZero(address engine, bool isEnabled) external givenTheSenderIsTheOwner {
        vm.assume(engine != address(0));

        // it should emit {LogConfigureEngine} event
        vm.expectEmit({ emitter: address(referralModule) });
        emit Referral.LogConfigureEngine(engine, isEnabled);

        referralModule.configureEngine(engine, isEnabled);

        // it should update the registered engines
        assertEq(
            Referral(address(referralModule)).registeredEngines(engine), isEnabled, "the engine should be updated"
        );
    }
}
