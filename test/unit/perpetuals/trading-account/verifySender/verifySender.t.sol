// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract VerifySender_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_RevertWhen_TheTradingAccountOwnerIsDifferentFromTheMsgSender(uint256 amountToDeposit)
        external
    {
        amountToDeposit = bound({
            x: amountToDeposit,
            min: WSTETH_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18)
        });

        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDeposit });

        changePrank({ msgSender: users.naruto.account });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AccountPermissionDenied.selector, tradingAccountId, users.madara.account
            )
        });

        changePrank({ msgSender: users.madara.account });

        perpsEngine.exposed_verifySender(tradingAccountId);
    }

    function testFuzz_WhenTheTradingAccountOwnerIsEqualToTheMsgSender(uint256 amountToDeposit) external {
        amountToDeposit = bound({
            x: amountToDeposit,
            min: WSTETH_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18)
        });

        deal({ token: address(wstEth), to: users.naruto.account, give: amountToDeposit });

        changePrank({ msgSender: users.naruto.account });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));

        // it should not revert
        perpsEngine.exposed_verifySender(tradingAccountId);
    }
}
