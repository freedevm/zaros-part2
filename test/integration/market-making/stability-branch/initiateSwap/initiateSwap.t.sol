// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

// PRB Math dependencies
import { ud60x18, UD60x18 } from "@prb-math/UD60x18.sol";

contract InitiateSwap_Integration_Test is Base_Test {
    using Collateral for Collateral.Data;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultIdsAndAmountsInArraysLengthMissmatch() external {
        uint128[] memory vaultIds = new uint128[](1);
        uint128[] memory amountsIn = new uint128[](2);
        uint128[] memory minAmountsOut = new uint128[](3);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ArrayLengthMismatch.selector, vaultIds.length, amountsIn.length)
        );

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    modifier whenVaultIdsAndAmountsInArraysLengthMatch() {
        _;
    }

    function test_RevertWhen_AmountsInAndMinAmountsOutArraysLengthMissmatch()
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
    {
        uint128[] memory vaultIds = new uint128[](2);
        uint128[] memory amountsIn = new uint128[](2);
        uint128[] memory minAmountsOut = new uint128[](3);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ArrayLengthMismatch.selector, amountsIn.length, minAmountsOut.length)
        );

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    modifier whenAmountsInAndMinAmountsOutArraysLengthMatch() {
        _;
    }

    function testFuzz_RevertWhen_CollateralIsDisabled(uint256 vaultId)
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
        whenAmountsInAndMinAmountsOutArraysLengthMatch
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        bool isEnabled = false;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureCollateral(fuzzVaultConfig.asset, address(8), 1e8, isEnabled, 8);
        changePrank({ msgSender: users.naruto.account });

        uint128[] memory vaultIds = new uint128[](2);
        uint128[] memory amountsIn = new uint128[](2);
        uint128[] memory minAmountsOut = new uint128[](2);

        vaultIds[0] = fuzzVaultConfig.vaultId;
        vaultIds[1] = fuzzVaultConfig.vaultId;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CollateralDisabled.selector, fuzzVaultConfig.asset));

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    modifier whenCollateralIsEnabled() {
        _;
    }

    function testFuzz_WhenCollateralAssetsOfVaultsMatch(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
        whenAmountsInAndMinAmountsOutArraysLengthMatch
        whenCollateralIsEnabled
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: users.owner.account });

        changePrank({ msgSender: users.naruto.account });

        deal({
            token: address(fuzzVaultConfig.asset),
            to: fuzzVaultConfig.indexToken,
            give: fuzzVaultConfig.depositCap
        });

        UD60x18 assetPriceX18 = IPriceAdapter(fuzzVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(fuzzVaultConfig.indexToken).totalAssets());
        uint256 maxSwapAmount = assetAmountX18.mul(assetPriceX18).intoUint256();

        swapAmount = bound({ x: swapAmount, min: 1e18, max: maxSwapAmount });

        uint128[] memory vaultIds = new uint128[](1);
        vaultIds[0] = fuzzVaultConfig.vaultId;

        uint128[] memory amountsIn = new uint128[](1);
        amountsIn[0] = uint128(swapAmount);

        uint128[] memory minAmountsOut = new uint128[](1);

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 swapRequestId = 1;

        address vaultAsset = marketMakingEngine.workaround_Vault_getVaultAsset(fuzzVaultConfig.vaultId);

        // it should emit {LogInitiateSwap} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit StabilityBranch.LogInitiateSwap(
            users.naruto.account,
            swapRequestId,
            fuzzVaultConfig.vaultId,
            amountsIn[0],
            0,
            vaultAsset,
            uint120(block.timestamp)
        );

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);

        // it should create new usd token swap request
        UsdTokenSwapConfig.SwapRequest memory request =
            marketMakingEngine.getSwapRequest(users.naruto.account, swapRequestId);

        assertGt(request.vaultId, 0);
        assertGt(request.deadline, 0);
        assertFalse(request.processed);
    }

    function testFuzz_RevertWhen_SecondVaultHasNoCollateral(
        uint128 firstVaultId,
        uint128 secondVaultId
    )
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
        whenAmountsInAndMinAmountsOutArraysLengthMatch
        whenCollateralIsEnabled
    {
        // ensure valid different vaults
        firstVaultId = uint128(bound(firstVaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        secondVaultId = uint128(bound(secondVaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        vm.assume(firstVaultId != secondVaultId);

        changePrank({ msgSender: users.naruto.account });

        // ensure same collateral token
        VaultConfig memory firstVaultConfig = getFuzzVaultConfig(firstVaultId);
        VaultConfig memory secondVaultConfig = getFuzzVaultConfig(secondVaultId);
        vm.assume(firstVaultConfig.asset == secondVaultConfig.asset);

        // fund only the first vault
        deal({
            token: address(firstVaultConfig.asset),
            to: firstVaultConfig.indexToken,
            give: firstVaultConfig.depositCap
        });

        // calculate max swap amount
        UD60x18 assetPriceX18 = IPriceAdapter(firstVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(firstVaultConfig.indexToken).totalAssets());
        uint256 maxSwapAmount = assetAmountX18.mul(assetPriceX18).intoUint256();

        // initiate swap for 2 vaults where second vault has no tokens
        uint128[] memory vaultIds = new uint128[](2);
        vaultIds[0] = firstVaultId;
        vaultIds[1] = secondVaultId;

        uint128[] memory amountsIn = new uint128[](2);
        amountsIn[0] = uint128(maxSwapAmount / 2);
        amountsIn[1] = uint128(maxSwapAmount / 2);

        uint128[] memory minAmountsOut = new uint128[](2);

        deal({ token: address(usdToken), to: users.naruto.account, give: maxSwapAmount });

        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientVaultBalance.selector, secondVaultId, 0, 0));
        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    function testFuzz_RevertWhen_SecondVaultHasInsufficientCollateral(
        uint128 firstVaultId,
        uint128 secondVaultId
    )
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
        whenAmountsInAndMinAmountsOutArraysLengthMatch
        whenCollateralIsEnabled
    {
        // ensure valid different vaults
        firstVaultId = uint128(bound(firstVaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        secondVaultId = uint128(bound(secondVaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        vm.assume(firstVaultId != secondVaultId);

        // ensure same collateral token
        VaultConfig memory firstVaultConfig = getFuzzVaultConfig(firstVaultId);
        VaultConfig memory secondVaultConfig = getFuzzVaultConfig(secondVaultId);
        vm.assume(firstVaultConfig.asset == secondVaultConfig.asset);

        // fully fund the first vault
        deal({
            token: address(firstVaultConfig.asset),
            to: firstVaultConfig.indexToken,
            give: firstVaultConfig.depositCap
        });
        // fund the second vault with a very small amount
        deal({ token: address(firstVaultConfig.asset), to: secondVaultConfig.indexToken, give: 1_000_000 });

        // calculate max swap amount
        UD60x18 assetPriceX18 = IPriceAdapter(firstVaultConfig.priceAdapter).getPrice();
        UD60x18 assetAmountX18 = ud60x18(IERC4626(firstVaultConfig.indexToken).totalAssets());
        uint256 maxSwapAmount = assetAmountX18.mul(assetPriceX18).intoUint256();

        // initiate swap for 2 vaults where second vault has no tokens
        uint128[] memory vaultIds = new uint128[](2);
        vaultIds[0] = firstVaultId;
        vaultIds[1] = secondVaultId;

        uint128[] memory amountsIn = new uint128[](2);
        amountsIn[0] = uint128(maxSwapAmount / 2);
        amountsIn[1] = uint128(maxSwapAmount / 2);

        uint128[] memory minAmountsOut = new uint128[](2);

        deal({ token: address(usdToken), to: users.naruto.account, give: maxSwapAmount });

        vm.expectRevert();
        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }
}
