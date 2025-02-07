// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Math } from "@zaros/utils/Math.sol";
import { Whitelist } from "@zaros/utils/Whitelist.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { Math as MathOpenZeppelin } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract VaultRouterBranch {
    using SafeERC20 for IERC20;
    using Collateral for Collateral.Data;
    using Distribution for Distribution.Data;
    using Vault for Vault.Data;
    using SafeCast for uint256;
    using MathOpenZeppelin for uint256;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    /// @notice Emitted when a user stakes shares.
    /// @param vaultId The ID of the vault which shares are staked.
    /// @param user The address of the user who staked the shares.
    /// @param shares The amount of shares staked by the user.
    event LogStake(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Emitted when a user initiates a withdrawal from a vault.
    /// @param vaultId The ID of the vault from which the shares are being withdrawn.
    /// @param user The address of the user who initiated the withdrawal.
    /// @param shares The amount of shares to be withdrawn by the user.
    event LogInitiateWithdrawal(uint256 indexed vaultId, address indexed user, uint128 shares);

    /// @notice Emitted when a user unstakes shares.
    /// @param vaultId The ID of the vault which shares are unstaked.
    /// @param user The address of the user who unstaked the shares.
    /// @param shares The amount of shares unstaked by the user.
    event LogUnstake(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Emitted when a user deposist assets.
    /// @param vaultId The ID of the vault which assets are deposited.
    /// @param user The user that deposits the assets.
    /// @param assets The assets amount.
    event LogDeposit(uint256 indexed vaultId, address indexed user, uint256 assets);

    /// @notice Emitted when a user deposist assets.
    /// @param vaultId The ID of the vault which assets are deposited.
    /// @param user The user that deposits the assets.
    /// @param shares The shares amount being redeemed.
    event LogRedeem(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Returns the net credit capacity of the given vault, taking into account its underlying assets and
    /// debt.
    /// @dev The net credit capacity is the total assets value minus the total debt value.
    /// @param vaultId The vault identifier.
    /// @return totalAssetsMinusVaultDebt The net credit capacity of the vault.
    function getVaultCreditCapacity(uint128 vaultId) public view returns (uint256) {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.loadExisting(vaultId);

        // fetch the vault's total assets in 18 dec
        SD59x18 totalAssetsX18 =
            vault.collateral.convertTokenAmountToSd59x18(IERC4626(vault.indexToken).totalAssets().toInt256());

        // we use the vault's net sum of all debt types coming from its connected markets to determine the swap rate
        SD59x18 vaultDebtUsdX18 = vault.getTotalDebt();

        // get collateral asset price
        UD60x18 assetPriceX18 = vault.collateral.getPrice();

        // convert the vault debt value in USD to the equivalent amount of assets to be credited or debited
        SD59x18 vaultDebtInAssetsX18 = vaultDebtUsdX18.div(assetPriceX18.intoSD59x18());

        // get decimal offset
        uint8 decimalOffset = Constants.SYSTEM_DECIMALS - vault.collateral.decimals;

        // subtract the vault's debt from the total assets
        // NOTE: we add 1 to the total assets to avoid division by zero.
        // Add 10 ** decimalsOffset since when converting back from x18 to uint256, it would equal 1
        // NOTE: credit is accounted as negative debt, so it would be added to the total assets
        SD59x18 totalAssetsMinusVaultDebtX18 =
            totalAssetsX18.add(sd59x18(int256(10 ** uint256(decimalOffset)))).sub(vaultDebtInAssetsX18);

        // sd59x18 -> uint256
        uint256 totalAssetsMinusVaultDebt = vault.collateral.convertSd59x18ToTokenAmount(totalAssetsMinusVaultDebtX18);

        return totalAssetsMinusVaultDebt;
    }

    /// @notice Returns the deposit cap to save 5 storage reads versus calling getVaultData
    /// @dev Invariants:
    /// - Vault MUST exist.
    /// @param vaultId The vault identifier.
    /// @return depositCap The maximum amount of collateral assets that can be deposited in the vault.
    function getDepositCap(uint128 vaultId) external view returns (uint128 depositCap) {
        depositCap = Vault.loadExisting(vaultId).depositCap;
    }

    /// @notice Returns the data and state of a given vault.
    /// @dev Invariants:
    /// - Vault MUST exist.
    /// @param vaultId The vault identifier.
    /// @return depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @return withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @return marketsRealizedDebtUsd The total amount of unsettled debt in USD.
    /// @return depositedUsdc The total amount of credit deposits from markets that have been converted and
    /// distributed as USDC to vaults.
    /// @return indexToken The index token address.
    /// @return collateral The collateral asset data.
    function getVaultData(uint128 vaultId)
        external
        view
        returns (
            uint128 depositCap,
            uint128 withdrawalDelay,
            int128 marketsRealizedDebtUsd,
            uint128 depositedUsdc,
            address indexToken,
            Collateral.Data memory collateral
        )
    {
        // load existing vault by id
        Vault.Data storage vault = Vault.loadExisting(vaultId);

        depositCap = vault.depositCap;
        withdrawalDelay = vault.withdrawalDelay;
        marketsRealizedDebtUsd = vault.marketsRealizedDebtUsd;
        depositedUsdc = vault.depositedUsdc;
        indexToken = vault.indexToken;
        collateral = vault.collateral;
    }

    /// @notice Returns the swap rate from index token to collateral asset for the provided vault.
    /// @dev Invariants:
    /// - Vault MUST exist.
    /// @dev This function does not perform state updates. Thus, in order to retrieve the atomic state in a non-view
    /// function like `deposit` `redeem`, the implementation must handle those updates beforehand, through the `Vault`
    /// leaf's methods.
    /// @param vaultId The vault identifier.
    /// @param sharesIn The amount of input shares for which to calculate the swap rate.
    /// @param shouldDiscountRedeemFee The flag that indicates if should discount the redeem fee.
    /// @return assetsOut The swap price from index token to collateral asset.
    function getIndexTokenSwapRate(
        uint128 vaultId,
        uint256 sharesIn,
        bool shouldDiscountRedeemFee
    )
        public
        view
        returns (UD60x18 assetsOut)
    {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.loadExisting(vaultId);

        // get the vault's net credit capacity, i.e its total assets usd value minus its total debt (or adding its
        // credit if debt is negative)
        uint256 totalAssetsMinusVaultDebt = getVaultCreditCapacity(vaultId);

        // get decimal offset
        uint8 decimalOffset = Constants.SYSTEM_DECIMALS - IERC20Metadata(vault.indexToken).decimals();

        // Get the asset amount out for the input amount of shares, taking into account the vault's debt
        // See {IERC4626-previewRedeem}
        // `IERC4626(vault.indexToken).totalSupply() + 10 ** decimalOffset` could lead to problems
        uint256 previewAssetsOut = sharesIn.mulDiv(
            totalAssetsMinusVaultDebt,
            IERC4626(vault.indexToken).totalSupply() + 10 ** decimalOffset,
            MathOpenZeppelin.Rounding.Floor
        );

        // verify if should discount redeem fee
        if (shouldDiscountRedeemFee) {
            // get the preview assets out discounting redeem fee
            previewAssetsOut =
                ud60x18(previewAssetsOut).sub(ud60x18(previewAssetsOut).mul(ud60x18(vault.redeemFee))).intoUint256();
        }

        // Return the final adjusted amountOut as UD60x18
        return ud60x18(previewAssetsOut);
    }

    /// @notice Returns the swap rate from collateral asset to index token for the provided vault.
    /// @dev Invariants:
    /// - Vault MUST exist.
    /// @param vaultId The vault identifier.
    /// @param assetsIn The amount of input assets for which to calculate the swap rate.
    /// @param shouldDiscountDepositFee The flag that indicates if should discount the deposit fee.
    /// @return sharesOut The swap price from underlying collateral asset to the vault shares.
    function getVaultAssetSwapRate(
        uint128 vaultId,
        uint256 assetsIn,
        bool shouldDiscountDepositFee
    )
        public
        view
        returns (UD60x18 sharesOut)
    {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.loadExisting(vaultId);

        // get the vault's net credit capacity, i.e its total assets usd value minus its total debt (or adding its
        // credit if debt is negative)
        uint256 totalAssetsMinusVaultDebt = getVaultCreditCapacity(vaultId);

        // get decimal offset
        uint8 decimalOffset = Constants.SYSTEM_DECIMALS - IERC20Metadata(vault.indexToken).decimals();

        // Get the shares amount out for the input amount of tokens, taking into account the unsettled debt
        // See {IERC4626-previewDeposit}.
        // `IERC4626(vault.indexToken).totalSupply() + 10 ** decimalOffset` could lead to problems
        uint256 previewSharesOut = assetsIn.mulDiv(
            IERC4626(vault.indexToken).totalSupply() + 10 ** decimalOffset,
            totalAssetsMinusVaultDebt,
            MathOpenZeppelin.Rounding.Floor
        );

        if (shouldDiscountDepositFee) {
            previewSharesOut =
                ud60x18(previewSharesOut).sub(ud60x18(previewSharesOut).mul(ud60x18(vault.depositFee))).intoUint256();
        }

        // Return the final adjusted amountOut as UD60x18
        return ud60x18(previewSharesOut);
    }

    struct DepositContext {
        address vaultAsset;
        IReferral referralModule;
        uint8 vaultAssetDecimals;
        UD60x18 vaultDepositFee;
        UD60x18 assetsX18;
        UD60x18 assetFeesX18;
        uint256 assetFees;
        uint256 assetsMinusFees;
        uint256 shares;
    }

    /// @notice Deposits a given amount of collateral assets into the provided vault in exchange for index tokens.
    /// @dev Invariants involved in the call:
    /// The total deposits MUST not exceed the vault after the deposit.
    /// The number of received shares MUST be greater than or equal to minShares.
    /// The number of received shares MUST be > 0 even when minShares = 0.
    /// The Vault MUST exist.
    /// The Vault MUST be live.
    /// If the vault enforces fees then calculated deposit fee must be non-zero.
    /// No tokens should remain stuck in this contract.
    /// @param vaultId The vault identifier.
    /// @param assets The amount of collateral to deposit, in the underlying ERC20 decimals.
    /// @param minShares The minimum amount of index tokens to receive in 18 decimals.
    /// @param referralCode The referral code to use.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    function deposit(
        uint128 vaultId,
        uint128 assets,
        uint128 minShares,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external
    {
        if (assets == 0) revert Errors.ZeroInput("assets");

        // load the mm engine configuration from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // enforce whitelist if enabled
        address whitelistCache = marketMakingEngineConfiguration.whitelist;
        if (whitelistCache != address(0)) {
            if (!Whitelist(whitelistCache).verifyIfUserIsAllowed(msg.sender)) {
                revert Errors.UserIsNotAllowed(msg.sender);
            }
        }

        // fetch storage slot for vault by id, vault must exist with valid collateral
        Vault.Data storage vault = Vault.loadLive(vaultId);
        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist(vaultId);

        // define context struct and get vault collateral asset
        DepositContext memory ctx;
        ctx.vaultAsset = vault.collateral.asset;

        // prepare the `Vault::recalculateVaultsCreditCapacity` call
        uint256[] memory vaultsIds = new uint256[](1);
        vaultsIds[0] = uint256(vaultId);

        // recalculates the vault's credit capacity
        // note: we need to update the vaults credit capacity before depositing new assets in order to calculate the
        // correct conversion rate between assets and shares, and to validate the involved invariants accurately
        Vault.recalculateVaultsCreditCapacity(vaultsIds);

        // load the referral module contract
        ctx.referralModule = IReferral(marketMakingEngineConfiguration.referralModule);

        // register the given referral code
        if (referralCode.length != 0) {
            ctx.referralModule.registerReferral(
                abi.encode(msg.sender), msg.sender, referralCode, isCustomReferralCode
            );
        }

        // cache the vault assets decimals value for gas savings
        ctx.vaultAssetDecimals = vault.collateral.decimals;

        // uint256 -> ud60x18 18 decimals
        ctx.assetsX18 = Math.convertTokenAmountToUd60x18(ctx.vaultAssetDecimals, assets);

        // cache the deposit fee
        ctx.vaultDepositFee = ud60x18(vault.depositFee);

        // if deposit fee is zero, skip needless processing
        if (ctx.vaultDepositFee.isZero()) {
            ctx.assetsMinusFees = assets;
        } else {
            // otherwise calculate the deposit fee
            ctx.assetFeesX18 = ctx.assetsX18.mul(ctx.vaultDepositFee);

            // ud60x18 -> uint256 asset decimals
            ctx.assetFees = Math.convertUd60x18ToTokenAmount(ctx.vaultAssetDecimals, ctx.assetFeesX18);

            // invariant: if vault enforces fees then calculated fee must be non-zero
            if (ctx.assetFees == 0) revert Errors.ZeroFeeNotAllowed();

            // enforce positive amount left over after deducting fees
            ctx.assetsMinusFees = assets - ctx.assetFees;
            if (ctx.assetsMinusFees == 0) revert Errors.DepositTooSmall();
        }

        // transfer tokens being deposited minus fees into this contract
        IERC20(ctx.vaultAsset).safeTransferFrom(msg.sender, address(this), ctx.assetsMinusFees);

        // transfer fees from depositor to fee recipient address
        if (ctx.assetFees > 0) {
            IERC20(ctx.vaultAsset).safeTransferFrom(
                msg.sender, marketMakingEngineConfiguration.vaultDepositAndRedeemFeeRecipient, ctx.assetFees
            );
        }

        // increase vault allowance to transfer tokens minus fees from this contract to vault
        address indexTokenCache = vault.indexToken;
        IERC20(ctx.vaultAsset).approve(indexTokenCache, ctx.assetsMinusFees);

        // then perform the actual deposit
        // NOTE: the following call will update the total assets deposited in the vault
        // NOTE: the following call will validate the vault's deposit cap
        // invariant: no tokens should remain stuck in this contract
        ctx.shares = IERC4626(indexTokenCache).deposit(ctx.assetsMinusFees, msg.sender);

        // assert min shares minted
        if (ctx.shares < minShares) revert Errors.SlippageCheckFailed(minShares, ctx.shares);

        // invariant: received shares must be > 0 even when minShares = 0; no donation allowed
        if (ctx.shares == 0) revert Errors.DepositMustReceiveShares();

        // emit an event
        emit LogDeposit(vaultId, msg.sender, ctx.assetsMinusFees);
    }

    /// @notice Stakes a given amount of index tokens in the contract.
    /// @dev Index token holders must stake in order to earn fees distributions from the market making engine.
    /// @dev Invariants involved in the call:
    /// The sum of all staked assets SHOULD always equal the total stake value
    /// The Vault MUST exist.
    /// The Vault MUST be live.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to stake, in 18 decimals.
    function stake(uint128 vaultId, uint128 shares) external {
        // to prevent safe cast overflow errors
        if (shares < Constants.MIN_OF_SHARES_TO_STAKE) {
            revert Errors.QuantityOfSharesLessThanTheMinimumAllowed(Constants.MIN_OF_SHARES_TO_STAKE, uint256(shares));
        }

        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.loadLive(vaultId);

        // prepare the `Vault::recalculateVaultsCreditCapacity` call
        uint256[] memory vaultsIds = new uint256[](1);
        vaultsIds[0] = uint256(vaultId);

        // updates the vault's credit capacity and perform all vault state
        // transitions before updating `msg.sender` staked shares
        Vault.recalculateVaultsCreditCapacity(vaultsIds);

        // load distribution data
        Distribution.Data storage wethRewardDistribution = vault.wethRewardDistribution;

        // cast actor address to bytes32
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        // accumulate the actor's pending reward before staking
        wethRewardDistribution.accumulateActor(actorId);

        // load actor distribution data
        Distribution.Actor storage actor = wethRewardDistribution.actor[actorId];

        // calculate actor updated shares amount
        UD60x18 updatedActorShares = ud60x18(actor.shares).add(ud60x18(shares));

        // update actor staked shares
        wethRewardDistribution.setActorShares(actorId, updatedActorShares);

        // transfer shares from actor
        IERC20(vault.indexToken).safeTransferFrom(msg.sender, address(this), shares);

        // emit an event
        emit LogStake(vaultId, msg.sender, shares);
    }

    ///.@notice Initiates a withdrawal request for a given amount of index tokens from the provided vault.
    /// @dev Even if the vault doesn't have enough unlocked credit capacity to fulfill the withdrawal request, the
    /// user can still initiate it, wait for the withdrawal delay period to elapse, and redeem the shares when
    /// liquidity is available.
    /// @dev Invariants involved in the call:
    /// The shares to withdraw MUST be greater than zero.
    /// The user MUST have enough shares in their balance to initiate the withdrawal.
    /// The Vault MUST exist.
    /// The Vault MUST be live.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to withdraw, in 18 decimals.
    function initiateWithdrawal(uint128 vaultId, uint128 shares) external {
        if (shares == 0) {
            revert Errors.ZeroInput("sharesAmount");
        }

        // fetch storage slot for vault by id, vault must exist with valid collateral
        Vault.Data storage vault = Vault.loadLive(vaultId);
        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist(vaultId);

        // increment vault/user withdrawal request counter and set withdrawal request id
        uint128 withdrawalRequestId = ++vault.withdrawalRequestIdCounter[msg.sender];

        // load storage slot for withdrawal request
        WithdrawalRequest.Data storage withdrawalRequest =
            WithdrawalRequest.load(vaultId, msg.sender, withdrawalRequestId);

        // update withdrawal request create time
        withdrawalRequest.timestamp = block.timestamp.toUint128();

        // update withdrawal request shares
        withdrawalRequest.shares = shares;

        // transfer shares to the contract to be later redeemed
        IERC20(vault.indexToken).safeTransferFrom(msg.sender, address(this), shares);

        // emit an event
        emit LogInitiateWithdrawal(vaultId, msg.sender, shares);
    }

    struct RedeemContext {
        uint128 shares;
        UD60x18 expectedAssetsX18;
        UD60x18 expectedAssetsMinusRedeemFeeX18;
        UD60x18 sharesMinusRedeemFeesX18;
        uint256 redeemFee;
        uint256 sharesFees;
        SD59x18 creditCapacityBeforeRedeemUsdX18;
        UD60x18 lockedCreditCapacityBeforeRedeemUsdX18;
    }

    /// @notice Redeems a given amount of index tokens in exchange for collateral assets from the provided vault,
    /// after the withdrawal delay period has elapsed.
    /// @dev Invariants involved in the call:
    /// The withdrawalRequest MUST NOT be already fulfilled.
    /// The withdrawal delay period MUST have elapsed.
    /// Redeemed assets MUST meet or exceed minAssets.
    /// Redeemed assets MUST be > 0 even when minAssets = 0.
    /// The Vault MUST exist.
    /// The Vault MUST be live.
    /// No shares should remain stuck in this contract.
    /// @param vaultId The vault identifier.
    /// @param withdrawalRequestId The previously initiated withdrawal request id.
    /// @param minAssets The minimum amount of collateral to receive, in the underlying ERC20 decimals.
    function redeem(uint128 vaultId, uint128 withdrawalRequestId, uint256 minAssets) external {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.loadLive(vaultId);

        // load storage slot for previously created withdrawal request
        WithdrawalRequest.Data storage withdrawalRequest =
            WithdrawalRequest.loadExisting(vaultId, msg.sender, withdrawalRequestId);

        // revert if withdrawal request already fulfilled
        if (withdrawalRequest.fulfilled) revert Errors.WithdrawalRequestAlreadyFulfilled();

        // revert if withdrawal request delay not yet passed
        if (withdrawalRequest.timestamp + vault.withdrawalDelay > block.timestamp) {
            revert Errors.WithdrawDelayNotPassed();
        }

        // prepare the `Vault::recalculateVaultsCreditCapacity` call
        uint256[] memory vaultsIds = new uint256[](1);
        vaultsIds[0] = uint256(vaultId);

        // updates the vault's credit capacity before redeeming
        Vault.recalculateVaultsCreditCapacity(vaultsIds);

        // define context struct, get withdraw shares and associated assets
        RedeemContext memory ctx;
        ctx.shares = withdrawalRequest.shares;
        ctx.expectedAssetsX18 = getIndexTokenSwapRate(vaultId, ctx.shares, false);

        // load the mm engine configuration from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // cache vault's redeem fee
        ctx.redeemFee = vault.redeemFee;

        // get assets minus redeem fee
        ctx.expectedAssetsMinusRedeemFeeX18 =
            ctx.expectedAssetsX18.sub(ctx.expectedAssetsX18.mul(ud60x18(ctx.redeemFee)));

        // calculate assets minus redeem fee as shares
        ctx.sharesMinusRedeemFeesX18 =
            getVaultAssetSwapRate(vaultId, ctx.expectedAssetsMinusRedeemFeeX18.intoUint256(), false);

        // get the shares to send to the vault deposit and redeem fee recipient
        ctx.sharesFees = ctx.shares - ctx.sharesMinusRedeemFeesX18.intoUint256();

        // cache the vault's credit capacity before redeeming
        ctx.creditCapacityBeforeRedeemUsdX18 = vault.getTotalCreditCapacityUsd();

        // cache the locked credit capacity before redeeming
        ctx.lockedCreditCapacityBeforeRedeemUsdX18 = vault.getLockedCreditCapacityUsd();

        // redeem shares previously transferred to the contract at `initiateWithdrawal` and store the returned assets
        address indexToken = vault.indexToken;
        uint256 assets =
            IERC4626(indexToken).redeem(ctx.sharesMinusRedeemFeesX18.intoUint256(), msg.sender, address(this));

        // get the redeem fee
        if (ctx.sharesFees > 0) {
            IERC4626(indexToken).redeem(
                ctx.sharesFees, marketMakingEngineConfiguration.vaultDepositAndRedeemFeeRecipient, address(this)
            );
        }

        // require at least min assets amount returned
        if (assets < minAssets) revert Errors.SlippageCheckFailed(minAssets, assets);

        // invariant: received assets must be > 0 even when minAssets = 0
        if (assets == 0) revert Errors.RedeemMustReceiveAssets();

        // if the credit capacity delta is greater than the locked credit capacity before the state transition, revert
        if (
            ctx.creditCapacityBeforeRedeemUsdX18.sub(vault.getTotalCreditCapacityUsd()).lte(
                ctx.lockedCreditCapacityBeforeRedeemUsdX18.intoSD59x18()
            )
        ) {
            revert Errors.NotEnoughUnlockedCreditCapacity();
        }

        // set withdrawal request to fulfilled
        withdrawalRequest.fulfilled = true;

        // emit an event
        emit LogRedeem(vaultId, msg.sender, ctx.sharesMinusRedeemFeesX18.intoUint256());
    }

    /// @notice Unstakes a given amount of index tokens from the contract.
    /// @dev Unstaked tokens don't participate in fees distributions.
    /// @dev Invariants involved in the call:
    /// The user MUST have enough shares staked to perform the unstake.
    /// The Vault MUST exist.
    /// The Vault MUST be live.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to unstake, in 18 decimals.
    function unstake(uint128 vaultId, uint256 shares) external {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.loadLive(vaultId);

        // prepare the `Vault::recalculateVaultsCreditCapacity` call
        uint256[] memory vaultsIds = new uint256[](1);
        vaultsIds[0] = uint256(vaultId);

        // updates the vault's credit capacity and perform all vault
        // state transitions before updating `msg.sender` staked shares
        Vault.recalculateVaultsCreditCapacity(vaultsIds);

        // get vault staking fee distribution data
        Distribution.Data storage wethRewardDistribution = vault.wethRewardDistribution;

        // cast actor address to bytes32
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        // get the claimable amount of fees
        UD60x18 amountToClaimX18 = vault.wethRewardDistribution.getActorValueChange(actorId).intoUD60x18();

        // reverts if the claimable amount is NOT 0
        if (!amountToClaimX18.isZero()) revert Errors.UserHasPendingRewards(actorId, amountToClaimX18.intoUint256());

        // accumulate the actor's pending reward before unstaking
        wethRewardDistribution.accumulateActor(actorId);

        // get actor staked shares
        UD60x18 actorShares = wethRewardDistribution.getActorShares(actorId);

        // verify actor has shares they are attempting to unstake
        if (actorShares.lt(ud60x18(shares))) revert Errors.NotEnoughShares();

        UD60x18 updatedActorShares = actorShares.sub(ud60x18(shares));

        // update actor shares
        wethRewardDistribution.setActorShares(actorId, updatedActorShares);

        // transfer shares to user
        IERC20(vault.indexToken).safeTransfer(msg.sender, shares);

        // emit an event
        emit LogUnstake(vaultId, msg.sender, shares);
    }

    /// @notice Returns the amount of shares staked by a given account in the provided vault.
    /// @param vaultId The vault identifier.
    /// @param account The address of the account to query.
    /// @return The amount of shares staked by the account.
    function getStakedSharesOfAccount(uint128 vaultId, address account) external view returns (uint256) {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.loadLive(vaultId);

        // get vault staking fee distribution data
        Distribution.Data storage distributionData = vault.wethRewardDistribution;

        // cast account address to bytes32
        bytes32 actorId = bytes32(uint256(uint160(account)));

        // get account staked shares
        UD60x18 actorShares = distributionData.getActorShares(actorId);

        return actorShares.intoUint256();
    }

    /// @notice Returns total and account-related staking share info.
    /// @param vaultId The vault identifier.
    /// @param account The address of the account to query.
    /// @return totalShares The shares of all stakers.
    /// @return valuePerShare The current global value per share.
    /// @return accountShares The shares of the input account.
    /// @return accountLastValuePerShare The last value per share of the input account.
    function getTotalAndAccountStakingData(
        uint128 vaultId,
        address account
    )
        external
        view
        returns (uint128 totalShares, int256 valuePerShare, uint128 accountShares, int256 accountLastValuePerShare)
    {
        // get vault staking fee distribution data
        Distribution.Data storage distributionData = Vault.loadLive(vaultId).wethRewardDistribution;

        // cast account address to bytes32
        bytes32 actorId = bytes32(uint256(uint160(account)));

        // output the raw data
        (totalShares, valuePerShare, accountShares, accountLastValuePerShare) =
            distributionData.getTotalAndActorRawData(actorId);
    }
}
