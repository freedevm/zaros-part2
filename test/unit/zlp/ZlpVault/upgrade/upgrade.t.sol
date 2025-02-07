// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { ZlpVault } from "@zaros/zlp/ZlpVault.sol";

// Open Zeppelin dependencies
import { IERC1967 } from "@openzeppelin/interfaces/IERC1967.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

contract ZlpVault_Upgrade_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    function test_WhenUpgradeToAndCallIsCalled() external {
        // load existing vault config and get existing owner
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(1);
        address owner = OwnableUpgradeable(fuzzVaultConfig.indexToken).owner();

        // create new vault implementation
        address newImpl = address(new ZlpVault());

        // cast existing vault as UUPS and upgrade
        UUPSUpgradeable zlpVault = UUPSUpgradeable(fuzzVaultConfig.indexToken);
        vm.startPrank(owner);

        // it should emit an {IERC1967::Upgraded} event
        vm.expectEmit({ emitter: address(zlpVault) });
        emit IERC1967.Upgraded(newImpl);

        zlpVault.upgradeToAndCall(newImpl, "");
    }
}
