// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract GetIndexTokenSwapRate_Integration_Test is Base_Test {
    using SafeCast for uint256;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenGetIndexTokenSwapRateIsCalled(uint128 vaultId, uint256 amountToSwap) external {
        amountToSwap = bound({ x: amountToSwap, min: 0, max: uint256(type(int256).max) });
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        vaultId = fuzzVaultConfig.vaultId;

        UD60x18 swapRate = marketMakingEngine.getIndexTokenSwapRate(vaultId, amountToSwap, false);

        // it should return the swap rate
        assertAlmostEq(IERC4626(fuzzVaultConfig.indexToken).previewRedeem(amountToSwap), swapRate.intoUint256(), 1e17);
    }
}
