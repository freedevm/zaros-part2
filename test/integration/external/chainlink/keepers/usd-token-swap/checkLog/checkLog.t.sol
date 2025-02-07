// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";
import { Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

// PRB Math dependencies
import { ud60x18, UD60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract UsdTokenSwapKeeper_CheckLog_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenCheckLogIsCalled() {
        _;
    }

    function testFuzz_WhenDeadlineHasExpored(uint256 vaultId) external givenCheckLogIsCalled {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        deal({
            token: address(fuzzVaultConfig.asset),
            to: fuzzVaultConfig.indexToken,
            give: fuzzVaultConfig.depositCap
        });

        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        changePrank({ msgSender: users.owner.account });

        UsdTokenSwapKeeper(usdTokenSwapKeeper).setForwarder(users.keepersForwarder.account);

        marketMakingEngine.configureSystemKeeper(usdTokenSwapKeeper, true);

        changePrank({ msgSender: users.naruto.account });

        UD60x18 assetPriceX18 = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(fuzzVaultConfig.indexToken).totalAssets());
        uint256 amountInUsd = assetAmountX18.mul(assetPriceX18).intoUint256();

        deal({ token: address(usdToken), to: users.naruto.account, give: amountInUsd });

        IERC20(usdToken).approve(address(marketMakingEngine), amountInUsd);

        initiateUsdSwap(fuzzVaultConfig.vaultId, uint128(amountInUsd), 0);

        skip(MAX_VERIFICATION_DELAY + 1);

        bytes32[] memory topics = new bytes32[](4);
        topics[0] = keccak256(abi.encode("Log(address,uint128)"));
        topics[1] = bytes32(uint256(uint160(address(users.naruto.account)))); // caller
        topics[2] = bytes32(uint256(1)); // requestId

        AutomationLog memory mockedLog = AutomationLog({
            index: 0,
            timestamp: 0,
            txHash: 0,
            blockNumber: 0,
            blockHash: 0,
            source: address(0),
            topics: topics,
            data: abi.encode(1)
        });

        bytes memory extraData = abi.encode("extraData");

        (bool upkeepNeeded,) = UsdTokenSwapKeeper(usdTokenSwapKeeper).checkLog(mockedLog, extraData);

        // it should return false
        assertEq(upkeepNeeded, false);
    }

    modifier whenDeadlineHasNotExpired() {
        _;
    }

    function test_WhenAssetsMissmatch() external givenCheckLogIsCalled whenDeadlineHasNotExpired {
        VaultConfig memory initialVaultConfig = getFuzzVaultConfig(INITIAL_VAULT_ID);
        VaultConfig memory vaultConfig = getFuzzVaultConfig(FINAL_VAULT_ID);

        deal({
            token: address(initialVaultConfig.asset),
            to: initialVaultConfig.indexToken,
            give: initialVaultConfig.depositCap
        });

        // use keeper of other vault than the one used in the request
        address usdTokenSwapKeeper = usdTokenSwapKeepers[vaultConfig.asset];

        changePrank({ msgSender: users.owner.account });

        UsdTokenSwapKeeper(usdTokenSwapKeeper).setForwarder(users.keepersForwarder.account);

        marketMakingEngine.configureSystemKeeper(usdTokenSwapKeeper, true);

        changePrank({ msgSender: users.naruto.account });

        UD60x18 assetPriceX18 = IPriceAdapter(initialVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(initialVaultConfig.indexToken).totalAssets());
        uint256 amountInUsd = assetAmountX18.mul(assetPriceX18).intoUint256();

        deal({ token: address(usdToken), to: users.naruto.account, give: amountInUsd });

        IERC20(usdToken).approve(address(marketMakingEngine), amountInUsd);

        initiateUsdSwap(initialVaultConfig.vaultId, amountInUsd, 0);

        bytes32[] memory topics = new bytes32[](4);
        topics[0] = keccak256(abi.encode("Log(address,uint128)"));
        topics[1] = bytes32(uint256(uint160(address(users.naruto.account)))); // caller
        topics[2] = bytes32(uint256(1)); // requestId

        AutomationLog memory mockedLog = AutomationLog({
            index: 0,
            timestamp: 0,
            txHash: 0,
            blockNumber: 0,
            blockHash: 0,
            source: address(0),
            topics: topics,
            data: abi.encode(1)
        });

        bytes memory extraData = abi.encode("extraData");

        (bool upkeepNeeded,) = UsdTokenSwapKeeper(usdTokenSwapKeeper).checkLog(mockedLog, extraData);

        // it should return false
        assertEq(upkeepNeeded, false);
    }

    function testFuzz_RevertWhen_AssetsMatch(uint256 vaultId)
        external
        givenCheckLogIsCalled
        whenDeadlineHasNotExpired
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        deal({
            token: address(fuzzVaultConfig.asset),
            to: fuzzVaultConfig.indexToken,
            give: fuzzVaultConfig.depositCap
        });

        UD60x18 assetPriceX18 = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(fuzzVaultConfig.indexToken).totalAssets());
        uint256 amountInUsd = assetAmountX18.mul(assetPriceX18).intoUint256();

        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        changePrank({ msgSender: users.owner.account });

        UsdTokenSwapKeeper(usdTokenSwapKeeper).setForwarder(users.keepersForwarder.account);

        marketMakingEngine.configureSystemKeeper(usdTokenSwapKeeper, true);

        changePrank({ msgSender: users.naruto.account });

        deal({ token: address(usdToken), to: users.naruto.account, give: amountInUsd });

        IERC20(usdToken).approve(address(marketMakingEngine), amountInUsd);

        initiateUsdSwap(fuzzVaultConfig.vaultId, amountInUsd, 0);

        bytes32[] memory topics = new bytes32[](4);
        topics[0] = keccak256(abi.encode("Log(address,uint128)"));
        topics[1] = bytes32(uint256(uint160(address(users.naruto.account)))); // caller
        topics[2] = bytes32(uint256(1)); // requestId

        AutomationLog memory mockedLog = AutomationLog({
            index: 0,
            timestamp: 0,
            txHash: 0,
            blockNumber: 0,
            blockHash: 0,
            source: address(0),
            topics: topics,
            data: abi.encode(1)
        });

        bytes memory extraData = abi.encode("extraData");

        string[] memory streams = new string[](1);
        streams[0] = fuzzVaultConfig.streamIdString;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                IStreamsLookupCompatible.StreamsLookup.selector,
                "feedIDs",
                streams,
                "timestamp",
                block.timestamp,
                abi.encode(users.naruto.account, 1)
            )
        });

        UsdTokenSwapKeeper(usdTokenSwapKeeper).checkLog(mockedLog, extraData);
    }
}
