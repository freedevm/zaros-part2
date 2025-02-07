// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";

contract UsdTokenSwapKeeper_GetConfig_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_WhenCallGetConfigFunction(uint256 vaultId) external givenInitializeContract {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        address usdTokenSwapKeeper = deployUsdTokenSwapKeeper(
            users.owner.account, address(marketMakingEngine), fuzzVaultConfig.asset, fuzzVaultConfig.streamIdString
        );

        (address keeperOwner, address keeperMarketMakingEngine, string memory streamId, address asset) =
            UsdTokenSwapKeeper(usdTokenSwapKeeper).getConfig();

        // it should return keeper owner
        assertEq(keeperOwner, users.owner.account, "keeper owner missmatch");

        // it should return address of the market making engine
        assertEq(address(marketMakingEngine), keeperMarketMakingEngine, "MM engine missmatch");

        // it should return streamId
        assertEq(fuzzVaultConfig.streamIdString, streamId, "streamid missmatch");

        // it should return address of the keeper asset
        assertEq(fuzzVaultConfig.asset, asset, "asset missmatch");
    }
}
