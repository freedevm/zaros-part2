// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract UsdTokenSwapKeeper_UpdateConfig_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_RevertWhen_AddressOfMarketMakingEngineIsZero(uint256 vaultId)
        external
        givenInitializeContract
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeper = deployUsdTokenSwapKeeper(
            users.owner.account, address(marketMakingEngine), fuzzVaultConfig.asset, fuzzVaultConfig.streamIdString
        );

        address newMarketMakingEngine = address(0);
        address newAsset = address(123);
        string memory newStreamId = "0x123";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketMakingEngine") });

        changePrank({ msgSender: users.owner.account });
        UsdTokenSwapKeeper(usdTokenSwapKeeper).updateConfig(newMarketMakingEngine, newAsset, newStreamId);
    }

    modifier whenAddressOfMarketMakingEngineIsValid() {
        _;
    }

    function testFuzz_RevertWhen_AddressOfAssetIsZero(uint256 vaultId)
        external
        givenInitializeContract
        whenAddressOfMarketMakingEngineIsValid
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeper = deployUsdTokenSwapKeeper(
            users.owner.account, address(marketMakingEngine), fuzzVaultConfig.asset, fuzzVaultConfig.streamIdString
        );

        address newMarketMakingEngine = address(123);
        address newAsset = address(0);
        string memory newStreamId = "0x123";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "asset") });

        changePrank({ msgSender: users.owner.account });
        UsdTokenSwapKeeper(usdTokenSwapKeeper).updateConfig(newMarketMakingEngine, newAsset, newStreamId);
    }

    modifier whenAddressOfAssetIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_StreamIdIsZero(uint256 vaultId)
        external
        givenInitializeContract
        whenAddressOfMarketMakingEngineIsValid
        whenAddressOfAssetIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeper = deployUsdTokenSwapKeeper(
            users.owner.account, address(marketMakingEngine), fuzzVaultConfig.asset, fuzzVaultConfig.streamIdString
        );

        address newMarketMakingEngine = address(123);
        address newAsset = address(1234);
        string memory newStreamId = "";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "streamId") });

        changePrank({ msgSender: users.owner.account });
        UsdTokenSwapKeeper(usdTokenSwapKeeper).updateConfig(newMarketMakingEngine, newAsset, newStreamId);
    }

    function testFuzz_WhenStreamIdIsNotZero(uint256 vaultId)
        external
        givenInitializeContract
        whenAddressOfMarketMakingEngineIsValid
        whenAddressOfAssetIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeper = deployUsdTokenSwapKeeper(
            users.owner.account, address(marketMakingEngine), fuzzVaultConfig.asset, fuzzVaultConfig.streamIdString
        );

        address newMarketMakingEngine = address(123);
        address newAsset = address(1234);
        string memory newStreamId = "0x123";

        changePrank({ msgSender: users.owner.account });
        UsdTokenSwapKeeper(usdTokenSwapKeeper).updateConfig(newMarketMakingEngine, newAsset, newStreamId);

        (, address currMarketMakingEngine, string memory streamId, address asset) =
            UsdTokenSwapKeeper(usdTokenSwapKeeper).getConfig();

        // it should update the config
        assertEq(currMarketMakingEngine, newMarketMakingEngine);
        assertEq(streamId, newStreamId);
        assertEq(asset, newAsset);
    }
}
