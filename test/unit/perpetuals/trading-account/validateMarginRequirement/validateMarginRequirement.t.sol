// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract ValidateMarginRequirement_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertWhen_RequiredMarginPlusTotalFeesIsGreaterThanTheMarginBalance() external {
        uint256 requiredMarginUsdUint = 100;
        uint256 totalFeesUsdUint = 100;
        int256 marginBalanceUsdXUint = 0;

        uint128 tradingAccountId;
        UD60x18 requiredMarginUsdX18 = ud60x18(requiredMarginUsdUint);
        SD59x18 marginBalanceUsdX18 = sd59x18(marginBalanceUsdXUint);
        UD60x18 totalFeesUsdX18 = ud60x18(totalFeesUsdUint);

        //  when requiredMarginUsdX18 + totalFeesUsdX18 > marginBalanceUsdX18 -> revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientMargin.selector,
                tradingAccountId,
                marginBalanceUsdX18.intoInt256(),
                requiredMarginUsdX18.intoUint128(),
                totalFeesUsdX18.intoUint128()
            )
        });

        // it should revert
        perpsEngine.exposed_validateMarginRequirements(
            tradingAccountId, requiredMarginUsdX18, marginBalanceUsdX18, totalFeesUsdX18
        );
    }

    function test_WhenRequiredMarginPlusTotalFeesIsEqualToTheMarginBalance() external view {
        //  when requiredMarginUsdX18 + totalFeesUsdX18 = marginBalanceUsdX18 -> continue
        int256 marginBalanceUsdXUint = 200;
        uint256 requiredMarginUsdUint = 100;
        uint256 totalFeesUsdUint = 100;

        uint128 tradingAccountId;
        UD60x18 requiredMarginUsdX18 = ud60x18(requiredMarginUsdUint);
        SD59x18 marginBalanceUsdX18 = sd59x18(marginBalanceUsdXUint);
        UD60x18 totalFeesUsdX18 = ud60x18(totalFeesUsdUint);

        // it should continue execution

        perpsEngine.exposed_validateMarginRequirements(
            tradingAccountId, requiredMarginUsdX18, marginBalanceUsdX18, totalFeesUsdX18
        );
    }

    function test_WhenRequiredMarginPlusTotalFeesIsLessThanTheMarginBalance() external view {
        //  when requiredMarginUsdX18 + totalFeesUsdX18 < marginBalanceUsdX18 -> continue
        int256 marginBalanceUsdXUint = 300;
        uint256 requiredMarginUsdUint = 100;
        uint256 totalFeesUsdUint = 100;

        uint128 tradingAccountId;
        UD60x18 requiredMarginUsdX18 = ud60x18(requiredMarginUsdUint);
        SD59x18 marginBalanceUsdX18 = sd59x18(marginBalanceUsdXUint);
        UD60x18 totalFeesUsdX18 = ud60x18(totalFeesUsdUint);

        // it should continue execution

        perpsEngine.exposed_validateMarginRequirements(
            tradingAccountId, requiredMarginUsdX18, marginBalanceUsdX18, totalFeesUsdX18
        );
    }
}
