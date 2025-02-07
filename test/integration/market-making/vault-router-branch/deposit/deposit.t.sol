// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { ERC4626Upgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC4626 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// PRB Math
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract Deposit_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_DepositedAssetsAreZero(uint256 vaultId) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "assets"));

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, 0, 0, "", false);
    }

    modifier whenDepositedAssetsAreNotZero() {
        _;
    }

    modifier whenWhitelistIsEnabled() {
        _;
    }

    function test_RevertWhen_UserIsNotAllowed(
        uint256 vaultId,
        uint128 assetsToDeposit
    )
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsEnabled
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = uint128(
            bound(assetsToDeposit, calculateMinOfSharesToStake(fuzzVaultConfig.vaultId), fuzzVaultConfig.depositCap)
        );

        address mockUser = address(123);
        deal(fuzzVaultConfig.asset, mockUser, assetsToDeposit);

        changePrank(users.owner.account);
        marketMakingEngine.configureWhitelist(address(whitelist), true);

        changePrank(mockUser);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.UserIsNotAllowed.selector, mockUser));

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, assetsToDeposit, 0, "", false);
    }

    modifier whenWhitelistIsDisabledOrUserIsAllowed() {
        _;
    }

    function test_RevertWhen_VaultDoesNotExist(uint128 assetsToDeposit)
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsDisabledOrUserIsAllowed
    {
        assetsToDeposit = uint128(bound(assetsToDeposit, 1, type(uint128).max));

        uint128 minSharesOut = 0;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector, INVALID_VAULT_ID));
        marketMakingEngine.deposit(INVALID_VAULT_ID, assetsToDeposit, minSharesOut, "", false);
    }

    modifier whenVaultDoesExist() {
        _;
    }

    modifier whenTheDepositFeeIsNotZero() {
        _;
    }

    function test_RevertWhen_AssetFeeIsZero(
        uint128 vaultId,
        uint128 assetsToDeposit
    )
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsDisabledOrUserIsAllowed
        whenVaultDoesExist
        whenTheDepositFeeIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), 1e18));
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        uint128 minSharesOut = 0;

        uint128[] memory vaultsIds = new uint128[](1);
        uint128[] memory depositFees = new uint128[](1);
        uint128[] memory redeemFees = new uint128[](1);

        vaultsIds[0] = fuzzVaultConfig.vaultId;
        depositFees[0] = 1;

        changePrank(users.owner.account);
        marketMakingEngine.configureDepositAndRedeemFees(vaultsIds, depositFees, redeemFees);

        changePrank(users.naruto.account);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroFeeNotAllowed.selector));
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, assetsToDeposit, minSharesOut, "", false);
    }

    modifier whenAssetFeeIsNotZero() {
        _;
    }

    function test_RevertWhen_AssetMinusFeeIsZero(
        uint128 vaultId,
        uint128 assetsToDeposit
    )
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsDisabledOrUserIsAllowed
        whenVaultDoesExist
        whenTheDepositFeeIsNotZero
        whenAssetFeeIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap));
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        UD60x18 assetsToDepositX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);

        UD60x18 assetFeesX18 = assetsToDepositX18.mul(ud60x18(fuzzVaultConfig.depositFee));

        uint128 minSharesOut = 0;

        uint128[] memory vaultsIds = new uint128[](1);
        uint128[] memory depositFees = new uint128[](1);
        uint128[] memory redeemFees = new uint128[](1);

        vaultsIds[0] = fuzzVaultConfig.vaultId;
        depositFees[0] = 1e18;

        changePrank(users.owner.account);
        marketMakingEngine.configureDepositAndRedeemFees(vaultsIds, depositFees, redeemFees);

        changePrank(users.naruto.account);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DepositTooSmall.selector));
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, assetsToDeposit, minSharesOut, "", false);
    }

    modifier whenTheDepositFeeIsZeroOrNot() {
        _;
    }

    function testFuzz_RevertWhen_TheDepositCapIsReached(
        uint128 vaultId,
        uint128 assetsToDeposit,
        bool depositFeeZero
    )
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsDisabledOrUserIsAllowed
        whenVaultDoesExist
        whenTheDepositFeeIsZeroOrNot
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        marketMakingEngine.workaround_Collateral_setParams(
            fuzzVaultConfig.asset,
            fuzzVaultConfig.creditRatio,
            fuzzVaultConfig.isEnabled,
            fuzzVaultConfig.decimals,
            fuzzVaultConfig.priceAdapter
        );

        uint128 depositFee = depositFeeZero ? uint128(0) : uint128(vaultsConfig[fuzzVaultConfig.vaultId].depositFee);

        _setDepositFee(depositFee, fuzzVaultConfig.vaultId);

        uint256 minDeposit = ud60x18(fuzzVaultConfig.depositCap).add(
            ud60x18(fuzzVaultConfig.depositCap).mul(ud60x18(depositFee))
        ).add(ud60x18(fuzzVaultConfig.depositCap)).intoUint256();

        assetsToDeposit = uint128(bound({ x: assetsToDeposit, min: minDeposit, max: type(uint128).max }));

        address collateral = fuzzVaultConfig.asset;

        deal(collateral, users.naruto.account, assetsToDeposit);

        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(depositFee));
        uint256 assetsFee = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);
        uint256 assetsMinusFees = assetsToDeposit - assetsFee;

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC4626Upgradeable.ERC4626ExceededMaxDeposit.selector,
                address(users.naruto.account),
                assetsMinusFees,
                fuzzVaultConfig.depositCap
            )
        );
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0, "", false);
    }

    modifier whenTheDepositCapIsNotReached() {
        _;
    }

    function testFuzz_RevertWhen_SharesMintedAreLessThanMinAmount(
        uint128 vaultId,
        uint128 assetsToDeposit,
        bool depositFeeZero
    )
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsDisabledOrUserIsAllowed
        whenVaultDoesExist
        whenTheDepositFeeIsZeroOrNot
        whenTheDepositCapIsNotReached
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        uint128 depositFee = depositFeeZero ? uint128(0) : uint128(vaultsConfig[fuzzVaultConfig.vaultId].depositFee);

        _setDepositFee(depositFee, fuzzVaultConfig.vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap));
        deal(fuzzVaultConfig.asset, user, assetsToDeposit);

        // calculate expected fees
        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(depositFee));

        // calculate assets minus fees
        uint256 assetsFee = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);
        uint256 assetsMinusFees = assetsToDeposit - assetsFee;

        uint128 minShares = type(uint128).max;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minShares, assetsMinusFees));
        marketMakingEngine.deposit(vaultId, assetsToDeposit, minShares, "", false);
    }

    modifier whenSharesMintedAreMoreThanMinAmount() {
        _;
    }

    function test_RevertWhen_SharesMintedAreZero(
        uint128 vaultId,
        uint128 assetsToDeposit,
        bool depositFeeZero
    )
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsDisabledOrUserIsAllowed
        whenVaultDoesExist
        whenTheDepositFeeIsZeroOrNot
        whenTheDepositCapIsNotReached
        whenSharesMintedAreMoreThanMinAmount
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        uint128 depositFee = depositFeeZero ? uint128(0) : uint128(vaultsConfig[fuzzVaultConfig.vaultId].depositFee);

        _setDepositFee(depositFee, fuzzVaultConfig.vaultId);

        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap));
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        uint128 minSharesOut = 0;

        vm.mockCall(
            address(fuzzVaultConfig.indexToken), abi.encodeWithSelector(IERC4626.deposit.selector), abi.encode(0)
        );

        changePrank(users.naruto.account);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DepositMustReceiveShares.selector));
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, assetsToDeposit, minSharesOut, "", false);
    }

    struct DepositState {
        // asset balances
        uint256 depositorAssetBal;
        uint256 feeReceiverAssetBal;
        uint256 vaultAssetBal;
        uint256 marketEngineAssetBal;
        // vault balances
        uint256 depositorVaultBal;
        uint256 marketEngineVaultBal;
    }

    function _getDepositState(
        address depositor,
        address feeReceiver,
        IERC20 assetToken,
        IERC20 vault
    )
        internal
        view
        returns (DepositState memory state)
    {
        state.depositorAssetBal = assetToken.balanceOf(depositor);
        state.feeReceiverAssetBal = assetToken.balanceOf(feeReceiver);
        state.vaultAssetBal = assetToken.balanceOf(address(vault));
        state.marketEngineAssetBal = assetToken.balanceOf(address(marketMakingEngine));
        state.depositorVaultBal = vault.balanceOf(depositor);
        state.marketEngineVaultBal = vault.balanceOf(address(marketMakingEngine));
    }

    function test_WhenSharesMintedAreNotZero(
        uint128 vaultId,
        uint128 assetsToDeposit,
        bool depositFeeZero
    )
        external
        whenDepositedAssetsAreNotZero
        whenWhitelistIsDisabledOrUserIsAllowed
        whenVaultDoesExist
        whenTheDepositFeeIsZeroOrNot
        whenTheDepositCapIsNotReached
        whenSharesMintedAreMoreThanMinAmount
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        uint128 depositFee = depositFeeZero ? uint128(0) : uint128(vaultsConfig[fuzzVaultConfig.vaultId].depositFee);

        _setDepositFee(depositFee, fuzzVaultConfig.vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap));
        deal(fuzzVaultConfig.asset, user, assetsToDeposit);

        // calculate expected fees
        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(depositFee));
        uint256 expectedAssetFees = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);
        uint256 assetsMinusFees = assetsToDeposit - expectedAssetFees;

        // save and verify pre state
        DepositState memory pre = _getDepositState(
            user, users.vaultFeeRecipient.account, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken)
        );

        assertEq(pre.depositorAssetBal, assetsToDeposit, "Depositor has assets to deposit");
        assertEq(pre.feeReceiverAssetBal, 0, "FeeReceiver has no assets");
        assertEq(pre.vaultAssetBal, 0, "Vault has no assets");
        assertEq(pre.marketEngineAssetBal, 0, "MarketEngine has no assets");
        assertEq(pre.depositorVaultBal, 0, "Depositor has no vault shares");
        assertEq(pre.marketEngineVaultBal, 0, "MarketEngine has no vault shares");

        marketMakingEngine.workaround_Vault_setTotalCreditDelegationWeight(vaultId, 1e10);

        // perform the deposit
        vm.startPrank(user);
        vm.expectEmit();
        emit VaultRouterBranch.LogDeposit(vaultId, user, assetsMinusFees);
        marketMakingEngine.deposit(vaultId, assetsToDeposit, 0, "", false);

        // save and verify post state
        DepositState memory post = _getDepositState(
            user, users.vaultFeeRecipient.account, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken)
        );

        assertEq(post.depositorAssetBal, 0, "Depositor lost assets after deposit");
        assertEq(post.feeReceiverAssetBal, expectedAssetFees, "FeeReceiver got asset fees");
        assertEq(post.vaultAssetBal, assetsMinusFees, "Vault got assets minus fees");
        assertEq(post.marketEngineAssetBal, 0, "No assets stuck in MarketEngine");

        assertGt(post.depositorVaultBal, 0, "Depositor got vault shares");
        assertEq(post.marketEngineVaultBal, 0, "MarketEngine got no vault shares");
    }

    function _setDepositFee(uint128 depositFee, uint128 vaultId) internal {
        uint128[] memory vaultsIds = new uint128[](1);
        uint128[] memory depositFees = new uint128[](1);
        uint128[] memory redeemFees = new uint128[](1);

        vaultsIds[0] = vaultId;
        depositFees[0] = depositFee;

        changePrank(users.owner.account);
        marketMakingEngine.configureDepositAndRedeemFees(vaultsIds, depositFees, redeemFees);

        changePrank(users.naruto.account);
    }
}
