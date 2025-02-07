// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { FeeConversionKeeper } from "@zaros/external/chainlink/keepers/fee-conversion-keeper/FeeConversionKeeper.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract FeeConversionKeeper_UpdateConfig_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureFeeConversionKeeper(uniswapV3Adapter.STRATEGY_ID(), 1);
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenInitializeContract() {
        _;
    }

    function test_RevertWhen_AddressOfMarketMakingEngineIsZero() external givenInitializeContract {
        changePrank({ msgSender: users.owner.account });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "marketMakingEngine"));

        FeeConversionKeeper(feeConversionKeeper).updateConfig(address(0), 100);
    }

    modifier whenAddressOfMarketMakingEngineIsValid() {
        _;
    }

    function test_RevertWhen_MinFeeDistributionValueIsZero()
        external
        givenInitializeContract
        whenAddressOfMarketMakingEngineIsValid
    {
        changePrank({ msgSender: users.owner.account });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "minFeeDistributionValueUsd"));

        FeeConversionKeeper(feeConversionKeeper).updateConfig(address(marketMakingEngine), 0);
    }

    function test_WhenMinFeeDistributionValueIsNotZero()
        external
        givenInitializeContract
        whenAddressOfMarketMakingEngineIsValid
    {
        changePrank({ msgSender: users.owner.account });

        FeeConversionKeeper(feeConversionKeeper).updateConfig(address(marketMakingEngine), 100);

        // it should update the config
        (, address mmEngine, uint128 minFeeDistributionValueUsd) =
            FeeConversionKeeper(feeConversionKeeper).getConfig();

        assertEq(address(marketMakingEngine), mmEngine);
        assertEq(minFeeDistributionValueUsd, 100);
    }
}
