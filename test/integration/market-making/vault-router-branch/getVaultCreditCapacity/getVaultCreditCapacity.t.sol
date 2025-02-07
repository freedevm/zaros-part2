// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IPriceAdapter } from "@zaros/utils/interfaces/IPriceAdapter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

contract GetVaultCreditCapacity_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenGetVaultCreditCapacityIsCalled(uint256 vaultId, uint256 assetsToDeposit) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // perform the deposit
        assetsToDeposit = bound({ x: assetsToDeposit, min: 1e6, max: fuzzVaultConfig.depositCap });
        address user = users.naruto.account;
        fundUserAndDepositInVault(user, fuzzVaultConfig.vaultId, uint128(assetsToDeposit));

        SD59x18 totalAssetsX18 = Math.convertTokenAmountToSd59x18(
            fuzzVaultConfig.decimals, int256(IERC4626(fuzzVaultConfig.indexToken).totalAssets())
        );

        SD59x18 vaultDebtUsdX18 = marketMakingEngine.workaround_getVaultTotalDebt(fuzzVaultConfig.vaultId);

        UD60x18 assetPriceX18 = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice();

        SD59x18 vaultDebtInAssetsX18 = vaultDebtUsdX18.div(assetPriceX18.intoSD59x18());

        uint8 decimalOffset = Constants.SYSTEM_DECIMALS - ERC20(fuzzVaultConfig.asset).decimals();

        SD59x18 totalAssetsMinusVaultDebtX18 =
            totalAssetsX18.add(sd59x18(int256(10 ** uint256(decimalOffset)))).sub(vaultDebtInAssetsX18);

        uint256 expectedDebt =
            Math.convertSd59x18ToTokenAmount(fuzzVaultConfig.decimals, totalAssetsMinusVaultDebtX18);

        // it should return the vault credit capacity
        uint256 capacity = marketMakingEngine.getVaultCreditCapacity(fuzzVaultConfig.vaultId);

        assertEq(capacity, expectedDebt);
    }
}
