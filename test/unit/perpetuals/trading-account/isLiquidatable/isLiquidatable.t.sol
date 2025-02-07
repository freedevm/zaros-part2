// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract isLiquidatable_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_WhenRequiredMaintenanceMarginUsdPlusLiquidationFeeUsdIsGreaterThanTheMarginBalanceUsd(
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd,
        uint256 liquidationFee
    )
        external
    {
        requiredMaintenanceMarginUsd =
            bound({ x: requiredMaintenanceMarginUsd, min: 1, max: MAX_MARGIN_REQUIREMENTS });

        liquidationFee = bound({ x: liquidationFee, min: 0, max: 100_000_000e18 });

        vm.assume(int256(requiredMaintenanceMarginUsd) + int256(liquidationFee) > marginBalanceUsd);

        UD60x18 requiredMaintenanceMarginUsdX18 = ud60x18(requiredMaintenanceMarginUsd);
        SD59x18 marginBalanceUsdX18 = sd59x18(marginBalanceUsd);
        UD60x18 liquidationFeeUsdX18 = ud60x18(liquidationFee);

        bool isLiquidatable = perpsEngine.exposed_isLiquidatable(
            requiredMaintenanceMarginUsdX18, marginBalanceUsdX18, liquidationFeeUsdX18
        );

        // it should return true
        assertEq(isLiquidatable, true, "isLiquidatable should return true");
    }

    function test_WhenRequiredMaintenanceMarginUsdPlusLiquidationFeeUsdIsLessThanOrEqualTheMarginBalanceUsd(
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd,
        uint256 liquidationFee
    )
        external
    {
        requiredMaintenanceMarginUsd =
            bound({ x: requiredMaintenanceMarginUsd, min: 1, max: MAX_MARGIN_REQUIREMENTS });

        liquidationFee = bound({ x: liquidationFee, min: 0, max: 100_000_000e18 });

        vm.assume(int256(requiredMaintenanceMarginUsd) + int256(liquidationFee) <= marginBalanceUsd);

        UD60x18 requiredMaintenanceMarginUsdX18 = ud60x18(requiredMaintenanceMarginUsd);
        SD59x18 marginBalanceUsdX18 = sd59x18(marginBalanceUsd);
        UD60x18 liquidationFeeUsdX18 = ud60x18(liquidationFee);

        bool isLiquidatable = perpsEngine.exposed_isLiquidatable(
            requiredMaintenanceMarginUsdX18, marginBalanceUsdX18, liquidationFeeUsdX18
        );

        // it should return false
        assertEq(isLiquidatable, false, "isLiquidatable should return false");
    }
}
