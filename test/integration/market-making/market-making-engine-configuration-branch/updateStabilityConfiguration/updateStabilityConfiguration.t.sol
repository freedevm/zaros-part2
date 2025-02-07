// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityConfiguration } from "@zaros/market-making/leaves/StabilityConfiguration.sol";

contract MarketMakingEngineConfigurationBranch_UpdateStabilityConfiguration_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertWhen_ChainlinkVerifierIsAddressZero(uint128 maxVerificationDelay) external {
        address chainlinkVerifier = address(0);

        maxVerificationDelay = uint128(bound({ x: maxVerificationDelay, min: 1, max: uint256(type(uint128).max) }));

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "chainlinkVerifier"));
        marketMakingEngine.updateStabilityConfiguration(chainlinkVerifier, maxVerificationDelay);
    }

    modifier whenChainlinkVerifierIsNotAddressZero() {
        _;
    }

    function testFuzz_RevertWhen_MaxVerificationDelayIsZero(address chailinkVerifier)
        external
        whenChainlinkVerifierIsNotAddressZero
    {
        vm.assume(chailinkVerifier != address(0));

        uint128 maxVerificationDelay = 0;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "maxVerificationDelay"));
        marketMakingEngine.updateStabilityConfiguration(chailinkVerifier, maxVerificationDelay);
    }

    function testFuzz_WhenMaxVerificationDelayIsNotZero(
        address chailinkVerifier,
        uint128 maxVerificationDelay
    )
        external
        whenChainlinkVerifierIsNotAddressZero
    {
        vm.assume(chailinkVerifier != address(0));
        maxVerificationDelay = uint128(bound({ x: maxVerificationDelay, min: 1, max: uint256(type(uint128).max) }));

        marketMakingEngine.updateStabilityConfiguration(chailinkVerifier, maxVerificationDelay);

        // it should update data
        StabilityConfiguration.Data memory stabilityConfig = marketMakingEngine.exposed_StabilityConfiguration_load();

        assertEq(address(stabilityConfig.chainlinkVerifier), chailinkVerifier);
        assertEq(stabilityConfig.maxVerificationDelay, maxVerificationDelay);
    }
}
