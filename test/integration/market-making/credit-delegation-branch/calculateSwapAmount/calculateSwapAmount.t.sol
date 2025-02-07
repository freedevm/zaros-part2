// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract CreditDelegationBranch_CalculateSwapAmount_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenCalculateSwapAmountIsCalled_orig(uint256 adapterIndex, uint256 vaultDebt) external {
        IDexAdapter dexAdapter = getFuzzDexAdapter(adapterIndex);

        vaultDebt = bound({ x: vaultDebt, min: 100, max: type(uint96).max });

        UD60x18 vaultDebtX18 = convertTokenAmountToUd60x18(address(wBtc), vaultDebt);

        uint256 actualAmountOut = marketMakingEngine.calculateSwapAmount(
            address(dexAdapter),
            address(wBtc),
            address(usdc),
            convertUd60x18ToTokenAmount(address(usdc), vaultDebtX18)
        );

        uint256 amountOut = convertUd60x18ToTokenAmount(address(usdc), vaultDebtX18);

        uint256 expectedAmountOut = IDexAdapter(dexAdapter).getExpectedOutput(address(wBtc), address(usdc), amountOut);

        // it should return the expected asset amount out
        assertEq(expectedAmountOut, actualAmountOut);
    }
}
