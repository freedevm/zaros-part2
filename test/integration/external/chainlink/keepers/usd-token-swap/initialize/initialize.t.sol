// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract UsdTokenSwapKeeper_Initialize_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_AddressOfMarketMakingEngineIsZero(uint256 vaultId) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeperImplementation = address(new UsdTokenSwapKeeper());
        string memory streamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketMakingEngine") });

        new ERC1967Proxy(
            usdTokenSwapKeeperImplementation,
            abi.encodeWithSelector(
                UsdTokenSwapKeeper.initialize.selector,
                users.owner.account,
                address(0),
                fuzzVaultConfig.asset,
                streamId
            )
        );
    }

    modifier whenAddressOfEngineIsNotZero() {
        _;
    }

    function test_RevertWhen_AddressOfAssetIsZero() external whenAddressOfEngineIsNotZero {
        address usdTokenSwapKeeperImplementation = address(new UsdTokenSwapKeeper());
        string memory streamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "asset") });

        new ERC1967Proxy(
            usdTokenSwapKeeperImplementation,
            abi.encodeWithSelector(
                UsdTokenSwapKeeper.initialize.selector, users.owner.account, marketMakingEngine, address(0), streamId
            )
        );
    }

    modifier whenAddressOfAssetIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_StreamIdIsZero(uint256 vaultId)
        external
        whenAddressOfEngineIsNotZero
        whenAddressOfAssetIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeperImplementation = address(new UsdTokenSwapKeeper());
        string memory invalidStreamId = "";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "streamId") });

        new ERC1967Proxy(
            usdTokenSwapKeeperImplementation,
            abi.encodeWithSelector(
                UsdTokenSwapKeeper.initialize.selector,
                users.owner.account,
                marketMakingEngine,
                fuzzVaultConfig.asset,
                invalidStreamId
            )
        );
    }

    function testFuzz_WhenStreamIdIsNotZero(uint256 vaultId)
        external
        whenAddressOfEngineIsNotZero
        whenAddressOfAssetIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeperImplementation = address(new UsdTokenSwapKeeper());
        string memory streamId = "1";

        // it should initialize
        new ERC1967Proxy(
            usdTokenSwapKeeperImplementation,
            abi.encodeWithSelector(
                UsdTokenSwapKeeper.initialize.selector,
                users.owner.account,
                marketMakingEngine,
                fuzzVaultConfig.asset,
                streamId
            )
        );
    }
}
