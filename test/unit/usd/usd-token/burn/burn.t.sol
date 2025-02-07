// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { UsdToken } from "@zaros/usd/UsdToken.sol";

contract UsdToken_Burn_Test is Base_Test {
    UsdToken token;

    function setUp() public virtual override {
        Base_Test.setUp();

        token = new UsdToken(users.owner.account, "Zaros Perpetuals AMM USD", "USDz");
    }

    function test_RevertWhen_AmountIsZero() external {
        changePrank({ msgSender: users.owner.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        token.burn(0);

        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        token.burn(0);
    }

    function testFuzz_WhenAmountIsNotZero(uint256 amount) external {
        amount = bound({ x: amount, min: 1, max: 100_000_000e18 });

        changePrank({ msgSender: users.owner.account });

        token.mint(users.owner.account, amount);
        token.mint(users.naruto.account, amount);

        assertEq(amount, token.balanceOf(users.owner.account), "amount is not correct");
        assertEq(amount, token.balanceOf(users.naruto.account), "amount is not correct");

        changePrank({ msgSender: users.naruto.account });
        token.burn(amount);

        changePrank({ msgSender: users.owner.account });
        token.burn(amount);

        // it should burn
        assertEq(0, token.balanceOf(users.owner.account), "amount is not correct");
        assertEq(0, token.balanceOf(users.naruto.account), "amount is not correct");
    }
}
