// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { FeeConversionKeeper } from "@zaros/external/chainlink/keepers/fee-conversion-keeper/FeeConversionKeeper.sol";

contract FeeConversionKeeper_GetConfig_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureFeeConversionKeeper(uniswapV3Adapter.STRATEGY_ID(), 1);
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenInitializeContract() {
        _;
    }

    function test_WhenCallGetConfigFunction() external givenInitializeContract {
        (address keeperOwner, address mmEngine, uint128 minFeeDistributionValueUsd) =
            FeeConversionKeeper(feeConversionKeeper).getConfig();

        // it should return keeper owner
        assertEq(keeperOwner, users.owner.account, "owner is not correct");

        // it should return address of the market making engine
        assertEq(address(marketMakingEngine), mmEngine, "engine is not correct");

        // it should return min fee distribution value in usd
        assertEq(1, minFeeDistributionValueUsd);
    }
}
