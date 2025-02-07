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

contract MarketMakingEngineConfigurationBranch_ConfigureEngine_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(address engine, address usdToken, bool isEnabled) external {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureEngine(engine, usdToken, isEnabled);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_TheEngineIsZero(
        address usdToken,
        bool isEnabled
    )
        external
        givenTheSenderIsTheOwner
    {
        // it should revert

        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "engine") });

        marketMakingEngine.configureEngine(address(0), usdToken, isEnabled);
    }

    function testFuzz_WhenTheShouldBeEnabledIsFalse(
        address engine,
        address usdToken
    )
        external
        givenTheSenderIsTheOwner
    {
        vm.assume(engine != address(0));

        bool shouldBeEnabled = false;

        // it should emit the {LogConfigureEngine} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfigureEngine(engine, address(0), shouldBeEnabled);

        marketMakingEngine.configureEngine(engine, usdToken, shouldBeEnabled);

        // it should update the isRegisteredEngine storage to false
        assertEq(
            marketMakingEngine.workaround_getIfEngineIsRegistered(engine),
            false,
            "the engine should be not registered"
        );

        // it should update the usdTokenOfEngine storage to zero
        assertEq(
            marketMakingEngine.workaround_getUsdTokenOfEngine(engine),
            address(0),
            "the usd token of the engine should be zero"
        );
    }

    modifier whenTheShouldBeEnabledIsTrue() {
        _;
    }

    function testFuzz_RevertWhen_TheUsdTokenIsZero(address engine)
        external
        givenTheSenderIsTheOwner
        whenTheShouldBeEnabledIsTrue
    {
        vm.assume(engine != address(0));

        bool shouldBeEnabled = true;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "usdToken") });

        marketMakingEngine.configureEngine(engine, address(0), shouldBeEnabled);
    }

    function testFuzz_WhenTheUsdTokenIsNotZero(
        address engine,
        address usdToken
    )
        external
        givenTheSenderIsTheOwner
        whenTheShouldBeEnabledIsTrue
    {
        vm.assume(engine != address(0) && usdToken != address(0));

        bool shouldBeEnabled = true;

        // it should emit the {LogConfigureEngine} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfigureEngine(engine, usdToken, shouldBeEnabled);

        marketMakingEngine.configureEngine(engine, usdToken, shouldBeEnabled);

        // it should update the isRegisteredEngine storage to true
        assertEq(
            marketMakingEngine.workaround_getIfEngineIsRegistered(engine), true, "the engine should be registered"
        );

        // it should update the usdTokenOfEngine to usdToken
        assertEq(
            marketMakingEngine.workaround_getUsdTokenOfEngine(engine),
            usdToken,
            "the usd token of the engine should be usdToken"
        );
    }
}
