// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract MarketMakingEngineConfigurationBranch_UpdateVaultAssetAllowance_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(uint256 vaultId, uint256 allowance) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.updateVaultAssetAllowance(fuzzVaultConfig.vaultId, allowance);
    }

    function testFuzz_GivenTheSenderIsTheOwner(uint256 vaultId, uint256 allowance) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: users.owner.account });

        marketMakingEngine.updateVaultAssetAllowance(fuzzVaultConfig.vaultId, allowance);

        // it should update allowance

        uint256 actualAllowance =
            IERC20(fuzzVaultConfig.asset).allowance(fuzzVaultConfig.indexToken, address(marketMakingEngine));
        assertEq(actualAllowance, allowance);
    }
}
