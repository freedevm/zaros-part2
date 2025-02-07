// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureCollateral_Integration_Test is Base_Test {
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

        marketMakingEngine.configureCollateral(
            address(usdc),
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter,
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            isEnabled,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals
        );
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_CollateralIsZero(bool isEnabled) external givenTheSenderIsTheOwner {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "collateral") });

        marketMakingEngine.configureCollateral(
            address(0),
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter,
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            isEnabled,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals
        );
    }

    modifier whenCollateralIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_PriceAdapterIsZero(bool isEnabled)
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "priceAdapter") });

        marketMakingEngine.configureCollateral(
            address(usdc),
            address(0),
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            isEnabled,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals
        );
    }

    modifier whenPriceAdapterIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_CreditRatioIsZero(bool isEnabled)
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
        whenPriceAdapterIsNotZero
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "creditRatio") });

        marketMakingEngine.configureCollateral(
            address(usdc),
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter,
            0,
            isEnabled,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals
        );
    }

    modifier whenCreditRatioIsNotZero() {
        _;
    }

    function test_RevertWhen_DecimalsIsZero(bool isEnabled)
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
        whenPriceAdapterIsNotZero
        whenCreditRatioIsNotZero
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "decimals") });

        marketMakingEngine.configureCollateral(
            address(usdc),
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter,
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            isEnabled,
            0
        );
    }

    function test_RevertWhen_DecimalsGreaterThanSystemDecimals(
        bool isEnabled,
        uint8 decimals
    )
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
        whenPriceAdapterIsNotZero
        whenCreditRatioIsNotZero
    {
        decimals = uint8(bound(decimals, Constants.SYSTEM_DECIMALS + 1, type(uint8).max));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector, address(usdc), decimals, address(0)
            )
        });

        marketMakingEngine.configureCollateral(
            address(usdc),
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter,
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            isEnabled,
            decimals
        );
    }

    function testFuzz_WhenDecimalsIsNotZero(bool isEnabled)
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
        whenPriceAdapterIsNotZero
        whenCreditRatioIsNotZero
    {
        // it should emit {LogConfigureCollateral} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfigureCollateral(
            address(usdc),
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter,
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            isEnabled,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals
        );

        marketMakingEngine.configureCollateral(
            address(usdc),
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter,
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            isEnabled,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals
        );

        // it should update collateral storage
        Collateral.Data memory collateral = marketMakingEngine.exposed_Collateral_load(address(usdc));

        assertEq(collateral.asset, address(usdc), "the asset should be equal to the USDC address");
        assertEq(
            collateral.creditRatio,
            MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO,
            "the asset should be have the credit ratio like MOCK_PERP_CREDIT_CONFIG_DEBT_CREDIT_RATIO"
        );
        assertEq(collateral.isEnabled, isEnabled, "the asset should be have the isEnabled like isEnabled in the test");
        assertEq(
            collateral.decimals,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals,
            "the asset should ba have the decimals equal to the USDC"
        );
    }
}
