// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockERC20WithNoDecimals } from "test/mocks/MockERC20WithNoDecimals.sol";
import { MockERC20WithZeroDecimals } from "test/mocks/MockERC20WithZeroDecimals.sol";

contract ConfigureMarginCollateral_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_CollateralThatDoesNotHaveDecimals(
        uint128 depositCap,
        uint120 loanToValue,
        address priceAdapter
    )
        external
    {
        changePrank({ msgSender: users.owner.account });

        MockERC20WithNoDecimals collateralWithNoDecimals =
            new MockERC20WithNoDecimals({ name: "Collateral", symbol: "COL", deployerBalance: 100_000_000e18 });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector, address(collateralWithNoDecimals), 0, priceAdapter
            )
        });

        perpsEngine.configureMarginCollateral(
            address(collateralWithNoDecimals), depositCap, loanToValue, priceAdapter
        );

        MockERC20WithZeroDecimals collateralWithZeroDecimals =
            new MockERC20WithZeroDecimals({ name: "Collateral", symbol: "COL", deployerBalance: 100_000_000e18 });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector, address(collateralWithZeroDecimals), 0, priceAdapter
            )
        });

        perpsEngine.configureMarginCollateral(
            address(collateralWithZeroDecimals), depositCap, loanToValue, priceAdapter
        );
    }

    modifier whenCollateralThatHasDecimals() {
        _;
    }

    function testFuzz_RevertWhen_CollateralDecimalsIsGreaterThanSystemDecimals(
        uint128 depositCap,
        uint120 loanToValue
    )
        external
        whenCollateralThatHasDecimals
    {
        changePrank({ msgSender: users.owner.account });

        uint8 decimals = Constants.SYSTEM_DECIMALS + 1;
        address priceAdapter = address(0x20);

        MockERC20 collateral =
            new MockERC20({ name: "Collateral", symbol: "COL", decimals_: decimals, deployerBalance: 100_000_000e18 });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector, address(collateral), decimals, priceAdapter
            )
        });

        perpsEngine.configureMarginCollateral(address(collateral), depositCap, loanToValue, priceAdapter);
    }

    modifier whenCollateralDecimalsIsNotGreaterThanSystemDecimals() {
        _;
    }

    function testFuzz_RevertWhen_PriceAdapterIsZero(
        uint128 depositCap,
        uint120 loanToValue
    )
        external
        whenCollateralThatHasDecimals
        whenCollateralDecimalsIsNotGreaterThanSystemDecimals
    {
        changePrank({ msgSender: users.owner.account });

        address priceAdapter = address(0);

        MockERC20 collateral = new MockERC20({
            name: "Collateral",
            symbol: "COL",
            decimals_: Constants.SYSTEM_DECIMALS,
            deployerBalance: 100_000_000e18
        });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector,
                address(collateral),
                Constants.SYSTEM_DECIMALS,
                priceAdapter
            )
        });

        perpsEngine.configureMarginCollateral(address(collateral), depositCap, loanToValue, priceAdapter);
    }

    function testFuzz_WhenPriceAdapterIsNotZero(
        uint128 depositCap,
        uint120 loanToValue
    )
        external
        whenCollateralThatHasDecimals
        whenCollateralDecimalsIsNotGreaterThanSystemDecimals
    {
        changePrank({ msgSender: users.owner.account });

        address priceAdapter = address(0x20);

        MockERC20 collateral = new MockERC20({
            name: "Collateral",
            symbol: "COL",
            decimals_: Constants.SYSTEM_DECIMALS,
            deployerBalance: 100_000_000e18
        });

        // it should emit {LogConfigureMarginCollateral} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit PerpsEngineConfigurationBranch.LogConfigureMarginCollateral(
            users.owner.account, address(collateral), depositCap, loanToValue, Constants.SYSTEM_DECIMALS, priceAdapter
        );

        // it should configure
        perpsEngine.configureMarginCollateral(address(collateral), depositCap, loanToValue, priceAdapter);
    }
}
