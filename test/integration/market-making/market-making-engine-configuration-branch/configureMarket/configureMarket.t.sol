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

contract MarketMakingEngineConfigurationBranch_ConfigureMarket_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleverageExponentZ
    )
        external
    {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_TheEngineIsZero(
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleverageExponentZ
    )
        external
        givenTheSenderIsTheOwner
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "engine") });

        address engine = address(0);

        marketMakingEngine.configureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );
    }

    modifier whenTheEngineIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketIdIsZero(
        address engine,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleverageExponentZ
    )
        external
        givenTheSenderIsTheOwner
        whenTheEngineIsNotZero
    {
        vm.assume(engine != address(0));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketId") });

        uint128 marketId = 0;

        marketMakingEngine.configureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );
    }

    modifier whenTheMarketIdIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheAutoDeleverageStartThresholdIsZero(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleverageExponentZ
    )
        external
        givenTheSenderIsTheOwner
        whenTheEngineIsNotZero
        whenTheMarketIdIsNotZero
    {
        vm.assume(engine != address(0) && marketId != 0);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "autoDeleverageStartThreshold")
        });

        uint128 autoDeleverageStartThreshold = 0;

        marketMakingEngine.configureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );
    }

    modifier whenTheAutoDeleverageStartThresholdIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheAutoDeleverageEndThresholdIsZero(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageExponentZ
    )
        external
        givenTheSenderIsTheOwner
        whenTheEngineIsNotZero
        whenTheMarketIdIsNotZero
        whenTheAutoDeleverageStartThresholdIsNotZero
    {
        vm.assume(engine != address(0) && marketId != 0 && autoDeleverageStartThreshold != 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "autoDeleverageEndThreshold") });

        uint128 autoDeleverageEndThreshold = 0;

        marketMakingEngine.configureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );
    }

    modifier whenTheAutoDeleverageEndThresholdIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheAutoDeleveragePowerScaleIsZero(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold
    )
        external
        givenTheSenderIsTheOwner
        whenTheEngineIsNotZero
        whenTheMarketIdIsNotZero
        whenTheAutoDeleverageStartThresholdIsNotZero
        whenTheAutoDeleverageEndThresholdIsNotZero
    {
        vm.assume(
            engine != address(0) && marketId != 0 && autoDeleverageStartThreshold != 0
                && autoDeleverageEndThreshold != 0
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "autoDeleverageExponentZ") });

        uint128 autoDeleverageExponentZ = 0;

        marketMakingEngine.configureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );
    }

    function testFuzz_WhenTheAutoDeleveragePowerScaleIsNotZero(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleverageExponentZ
    )
        external
        givenTheSenderIsTheOwner
        whenTheEngineIsNotZero
        whenTheMarketIdIsNotZero
        whenTheAutoDeleverageStartThresholdIsNotZero
        whenTheAutoDeleverageEndThresholdIsNotZero
    {
        vm.assume(
            engine != address(0) && marketId != 0 && autoDeleverageStartThreshold != 0
                && autoDeleverageEndThreshold != 0 && autoDeleverageExponentZ != 0
        );

        // it should emit {LogConfigureMarket} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfigureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );

        marketMakingEngine.configureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleverageExponentZ
        );

        // it should update market storage
        assertEq(
            marketMakingEngine.workaround_getMarketEngine(marketId), engine, "the market engine should be updated"
        );
        assertEq(
            marketMakingEngine.workaround_getAutoDeleverageStartThreshold(marketId),
            autoDeleverageStartThreshold,
            "the market autoDeleverageStartThreshold should be updated"
        );
        assertEq(
            marketMakingEngine.workaround_getAutoDeleverageEndThreshold(marketId),
            autoDeleverageEndThreshold,
            "the market autoDeleverageEndThreshold should be updated"
        );
        assertEq(
            marketMakingEngine.workaround_getAutoDeleveragePowerScale(marketId),
            autoDeleverageExponentZ,
            "the market autoDeleverageExponentZ should be updated"
        );
    }
}
