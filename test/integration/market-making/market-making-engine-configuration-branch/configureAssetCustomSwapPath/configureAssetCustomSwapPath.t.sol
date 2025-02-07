// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureAssetCustomSwapPath_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwnerr(
        uint256 vaultId,
        uint256 adapterIndex,
        bool isEnabled
    )
        external
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        changePrank({ msgSender: users.sakura.account });

        uint128[] memory dewSwapStrategyIds = new uint128[](2);
        dewSwapStrategyIds[0] = adapter.STRATEGY_ID();
        dewSwapStrategyIds[1] = adapter.STRATEGY_ID();

        address[] memory assets = new address[](3);
        assets[0] = address(1);
        assets[1] = address(2);
        assets[2] = address(3);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureAssetCustomSwapPath(fuzzVaultConfig.asset, isEnabled, assets, dewSwapStrategyIds);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_SwapPathAssetAndDexIdsArraysLengthsDontMatch(
        uint256 vaultId,
        uint256 adapterIndex,
        bool isEnabled
    )
        external
        givenTheSenderIsTheOwner
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        changePrank({ msgSender: users.owner.account });

        uint128[] memory dewSwapStrategyIds = new uint128[](2);
        dewSwapStrategyIds[0] = adapter.STRATEGY_ID();
        dewSwapStrategyIds[1] = adapter.STRATEGY_ID();

        address[] memory assets = new address[](4);
        assets[0] = address(1);
        assets[1] = address(2);
        assets[2] = address(3);
        assets[3] = address(4);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidSwapPathParamsLength.selector) });

        marketMakingEngine.configureAssetCustomSwapPath(fuzzVaultConfig.asset, isEnabled, assets, dewSwapStrategyIds);
    }

    function testFuzz_WhenSwapPathAssetAndDexIdsArraysLengthsMatch(
        uint256 vaultId,
        uint256 adapterIndex,
        bool isEnabled
    )
        external
        givenTheSenderIsTheOwner
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        changePrank({ msgSender: users.owner.account });

        uint128[] memory dewSwapStrategyIds = new uint128[](2);
        dewSwapStrategyIds[0] = adapter.STRATEGY_ID();
        dewSwapStrategyIds[1] = adapter.STRATEGY_ID();

        address[] memory assets = new address[](3);
        assets[0] = address(1);
        assets[1] = address(2);
        assets[2] = address(3);

        // it should emit {LogConfiguredSwapPath} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfiguredSwapPath(
            fuzzVaultConfig.asset, assets, dewSwapStrategyIds, isEnabled
        );

        marketMakingEngine.configureAssetCustomSwapPath(fuzzVaultConfig.asset, isEnabled, assets, dewSwapStrategyIds);

        // it should update the dex swap strategy storage
        (address[] memory actualAssets, uint128[] memory actualStrategyIds) =
            marketMakingEngine.getAssetSwapPath(fuzzVaultConfig.asset);

        assertEq(assets, actualAssets);
        assertEq(abi.encode(dewSwapStrategyIds), abi.encode(actualStrategyIds));
    }
}
