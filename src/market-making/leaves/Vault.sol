// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Collateral } from "./Collateral.sol";
import { CreditDelegation } from "./CreditDelegation.sol";
import { Distribution } from "./Distribution.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Market } from "./Market.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO, unary } from "@prb-math/SD59x18.sol";

/// @dev NOTE: each market's realized debt must always be distributed as unsettledRealizedDebt to vaults following the
/// Debt Distribution System.
/// @dev Vault's debt for asset settlement purposes = marketsRealizedDebtUsd
/// @dev Vault's debt for credit delegation and ADL purposes = marketsUnrealizedDebtUsd + marketsRealizedDebtUsd
library Vault {
    using Collateral for Collateral.Data;
    using CreditDelegation for CreditDelegation.Data;
    using Distribution for Distribution.Data;
    using EnumerableSet for EnumerableSet.UintSet;
    using Market for Market.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    /// @notice Emitted when a vault's credit capacity is updated at the `Vault::recalculateVaultsCreditCapacity`
    /// loop.
    /// @param vaultId The vault identifier.
    /// @param vaultUnrealizedDebtChangeUsd The vault's unrealized debt update during the recalculation.
    /// @param vaultRealizedDebtChangeUsd The vault's realized debt update during the recalculation.
    /// @param vaultNewCreditCapacityUsd The vault's new credit capacity after the recalculation of total debt and the
    /// USD adjusted value of its underlying assets.
    /// @dev The parameter above is adjusted by the configured collateral's credit ratio.
    event LogUpdateVaultCreditCapacity(
        uint128 indexed vaultId,
        int256 vaultRealizedDebtChangeUsd,
        int256 vaultUnrealizedDebtChangeUsd,
        uint256 vaultUsdcCreditChange,
        uint256 vaultWethRewardChange,
        int256 vaultNewCreditCapacityUsd
    );

    /// @notice Represents a swap strategy for exchanging assets.
    /// @param usdcDexSwapStrategyId The ID of the Dex swap strategy used for swapping to USDC.
    /// @param usdcDexSwapPath The encoded swap path for exchanging assets to USDC.
    /// @param assetDexSwapStrategyId The ID of the Dex swap strategy used for swapping to the target asset.
    /// @param assetDexSwapPath The encoded swap path for exchanging USDC to the target asset.
    struct SwapStrategy {
        uint128 usdcDexSwapStrategyId;
        bytes usdcDexSwapPath;
        uint128 assetDexSwapStrategyId;
        bytes assetDexSwapPath;
    }

    /// @param depositFee The despoit fee in the Vault, example 1e18 (100%), 0.1e18 (10%), 0.01e16 (1%), 0.001e18
    /// (0,1%).
    /// @param redeemFee The redeem fee in the Vault, example 1e18 (100%), 0.1e18 (10%), 0.01e16 (1%), 0.001e18
    /// (0,1%).
    /// @param id The vault identifier.
    /// @param totalCreditDelegationWeight The total amount of credit delegation weight in the vault.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param lockedCreditRatio The configured ratio that determines how much of the vault's total assets can't be
    /// withdrawn according to the Vault's total debt, in order to secure the credit delegation system.
    /// @param marketsUnrealizedDebtUsd The total amount of unrealized debt coming from markets in USD.
    /// @param marketsRealizedDebtUsd The total amount of realized debt coming from markets in USD. This value
    /// represents the net delta of a market's credit deposits and its net usd token issuance.
    /// @param depositedUsdc The total amount of USDC deposits coming from markets or other vaults to this vault,
    /// takes part of the unsettled realized debt value.
    /// @param indexToken The index token address.
    /// @param engine The engine implementation that this vault delegates credit to. Used to validate markets that can
    /// be connected to this vault.
    /// @param SwapStrategy Hold data about the vault asset/usdc swap paths
    /// @param collateral The collateral asset data.
    /// @param stakingFeeDistribution `actor`: Stakers, `shares`: Staked index tokens, `valuePerShare`: WETH fee
    /// earned per share.
    /// @param connectedMarkets The list of connected market ids. Whenever there's an update, a new
    /// `EnumerableSet.UintSet` is created.
    /// @param withdrawalRequestIdCounter Counter for user withdraw request ids
    struct Data {
        uint256 depositFee;
        uint256 redeemFee;
        uint128 id;
        uint128 totalCreditDelegationWeight;
        uint128 depositCap;
        uint128 withdrawalDelay;
        uint128 lockedCreditRatio;
        int128 marketsUnrealizedDebtUsd;
        int128 marketsRealizedDebtUsd;
        uint128 depositedUsdc;
        address indexToken;
        address engine;
        bool isLive;
        SwapStrategy swapStrategy;
        Collateral.Data collateral;
        Distribution.Data wethRewardDistribution;
        EnumerableSet.UintSet[] connectedMarkets;
        mapping(address => uint128) withdrawalRequestIdCounter;
    }

    /// @notice Parameters required to create a new vault.
    /// @param depositFee The deposit fee for the vault.
    /// @param redeemFee The redeem fee for the vault.
    /// @param vaultId The unique identifier for the vault to be created.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param indexToken The address of the index token used in the vault.
    /// @param engine The address of the engine
    /// @param collateral The collateral asset data associated with the vault.
    struct CreateParams {
        uint256 depositFee;
        uint256 redeemFee;
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        address indexToken;
        address engine;
        Collateral.Data collateral;
    }

    /// @notice Parameters required to update an existing vault.
    /// @param vaultId The unique identifier for the vault to be updated.
    /// @param depositCap The new maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The new delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param isLive The new status of the vault.
    /// @param lockedCreditRatio The ratio that determines how much of the vault's total assets can't be
    /// withdrawn according to the Vault's total debt, in order to secure the credit delegation system.
    struct UpdateParams {
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        bool isLive;
        uint128 lockedCreditRatio;
    }

    /// @notice Loads a {Vault} namespace.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function load(uint128 vaultId) internal pure returns (Data storage vault) {
        bytes32 slot = keccak256(abi.encode(VAULT_LOCATION, vaultId));
        assembly {
            vault.slot := slot
        }
    }

    /// @notice Loads a {Vault} namespace.
    /// @dev Invariants:
    /// The Vault MUST exist.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function loadExisting(uint128 vaultId) internal view returns (Data storage vault) {
        vault = load(vaultId);
        if (vault.id == 0) {
            revert Errors.VaultDoesNotExist(vaultId);
        }
        return vault;
    }

    /// @notice Loads a {Vault} namespace.
    /// @dev Invariants:
    /// The Vault MUST exist.
    /// The Vault MUST be live.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function loadLive(uint128 vaultId) internal view returns (Data storage vault) {
        vault = loadExisting(vaultId);

        if (!vault.isLive) {
            revert Errors.VaultIsDisabled(vaultId);
        }
    }

    /// @notice Returns the vault's minimum credit capacity allocated to the connected markets.
    /// @dev Prevents the vault's LPs from withdrawing more collateral than allowed, leading to potential liquidity
    /// issues to connected markets.
    /// @dev If the credit capacity goes to zero or below, meaning the vault is insolvent, the locked capacity will be
    /// zero, so functions using this method must ensure funds can't be withdrawn in that state.
    /// @param self The vault storage pointer.
    /// @return lockedCreditCapacityUsdX18 The vault's minimum credit capacity in USD.
    function getLockedCreditCapacityUsd(Data storage self)
        internal
        view
        returns (UD60x18 lockedCreditCapacityUsdX18)
    {
        SD59x18 creditCapacityUsdX18 = getTotalCreditCapacityUsd(self);
        lockedCreditCapacityUsdX18 = creditCapacityUsdX18.lte(SD59x18_ZERO)
            ? UD60x18_ZERO
            : creditCapacityUsdX18.intoUD60x18().mul(ud60x18(self.lockedCreditRatio));
    }

    /// @notice Returns the vault's total credit capacity allocated to the connected markets.
    /// @dev The vault's total credit capacity is adjusted by its the credit ratio of its underlying collateral asset.
    /// @param self The vault storage pointer.
    /// @return creditCapacityUsdX18 The vault's total credit capacity in USD.
    function getTotalCreditCapacityUsd(Data storage self) internal view returns (SD59x18 creditCapacityUsdX18) {
        // load the collateral configuration storage pointer
        Collateral.Data storage collateral = self.collateral;

        // fetch the zlp vault's total assets amount
        UD60x18 totalAssetsX18 = ud60x18(IERC4626(self.indexToken).totalAssets());

        // calculate the total assets value in usd terms
        UD60x18 totalAssetsUsdX18 = collateral.getAdjustedPrice().mul(totalAssetsX18);

        // calculate the vault's credit capacity in usd terms
        creditCapacityUsdX18 = totalAssetsUsdX18.intoSD59x18().sub(getTotalDebt(self));
    }

    /// @notice Returns the vault's total debt distributed from connected markets.
    /// @dev Takes into account the unrealized debt, the unsettled (yet to be settled) realized debt and the usdc
    /// credit deposited by markets.
    /// @param self The vault storage pointer.
    function getTotalDebt(Data storage self) internal view returns (SD59x18 totalDebtUsdX18) {
        totalDebtUsdX18 = getUnsettledRealizedDebt(self).add(sd59x18(self.marketsUnrealizedDebtUsd));
    }

    /// @notice Returns the vault's total unsettled debt in USD, taking into account both the markets' unrealized
    /// debt, but yet to be settled, and the usdc deposits allocated to the vault.
    /// @dev Note that only the vault's share of the markets' realized debt is taken into consideration for debt /
    /// credit settlements. Unrealized debt isn't taken into account for this purpose until realized by the markets,
    /// but it affects the vault's credit capacity and the conversion rate between index and underlying tokens.
    /// @dev USDC deposits are considered a net credit taking part of the unsettled realized debt, as they're used to
    /// back usd tokens and deducted during debt settlements. This is why we unary minus the deposited USDC value to
    /// calculate the vault's total unsettled debt.
    /// @param self The vault storage pointer.
    /// @return unsettledRealizedDebtUsdX18 The vault's total unsettled debt in USD.
    function getUnsettledRealizedDebt(Data storage self)
        internal
        view
        returns (SD59x18 unsettledRealizedDebtUsdX18)
    {
        unsettledRealizedDebtUsdX18 =
            sd59x18(self.marketsRealizedDebtUsd).add(unary(ud60x18(self.depositedUsdc).intoSD59x18()));
    }

    struct RecalculateConnectedMarketsState_Context {
        uint128 vaultId;
        SD59x18 marketUnrealizedDebtUsdX18;
        SD59x18 marketRealizedDebtUsdX18;
        SD59x18 realizedDebtChangeUsdX18;
        SD59x18 unrealizedDebtChangeUsdX18;
        UD60x18 usdcCreditChangeX18;
        UD60x18 wethRewardChangeX18;
    }

    /// @notice Recalculates the latest debt of each market connected to a vault, distributing its total debt to it.
    /// @dev We assume this function's caller checks that connectedMarketsIdsCache > 0.
    /// @param self The vault storage pointer.
    /// @param connectedMarketsIdsCache The cached connected markets ids.
    /// @param shouldRehydrateCache Whether the connected markets ids cache should be rehydrated or not.
    /// @return rehydratedConnectedMarketsIdsCache The potentially rehydrated connected markets ids cache.
    /// @return vaultTotalRealizedDebtChangeUsdX18 The vault's total realized debt change in USD.
    /// @return vaultTotalUnrealizedDebtChangeUsdX18 The vault's total unrealized debt change in USD.
    /// @return vaultTotalUsdcCreditChangeX18 The vault's total USDC credit change.
    /// @return vaultTotalWethRewardChangeX18 The vault's total WETH reward change.
    function _recalculateConnectedMarketsState(
        Data storage self,
        uint128[] memory connectedMarketsIdsCache,
        bool shouldRehydrateCache
    )
        private
        returns (
            uint128[] memory rehydratedConnectedMarketsIdsCache,
            SD59x18 vaultTotalRealizedDebtChangeUsdX18,
            SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
            UD60x18 vaultTotalUsdcCreditChangeX18,
            UD60x18 vaultTotalWethRewardChangeX18
        )
    {
        RecalculateConnectedMarketsState_Context memory ctx;
        rehydratedConnectedMarketsIdsCache = new uint128[](connectedMarketsIdsCache.length);

        // cache the vault id
        ctx.vaultId = self.id;

        // cache the connected markets length
        uint256 connectedMarketsConfigLength = self.connectedMarkets.length;

        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[connectedMarketsConfigLength - 1];

        for (uint256 i; i < connectedMarketsIdsCache.length; i++) {
            if (shouldRehydrateCache) {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarkets.at(i).toUint128();
            } else {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarketsIdsCache[i];
            }

            // loads the market storage pointer
            Market.Data storage market = Market.load(rehydratedConnectedMarketsIdsCache[i]);

            // first we cache the market's unrealized and realized debt
            ctx.marketUnrealizedDebtUsdX18 = market.getUnrealizedDebtUsd();
            ctx.marketRealizedDebtUsdX18 = market.getRealizedDebtUsd();

            // if market has debt distribute it
            if (!ctx.marketUnrealizedDebtUsdX18.isZero() || !ctx.marketRealizedDebtUsdX18.isZero()) {
                // distribute the market's debt to its connected vaults
                market.distributeDebtToVaults(ctx.marketUnrealizedDebtUsdX18, ctx.marketRealizedDebtUsdX18);
            }

            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation =
                CreditDelegation.load(ctx.vaultId, rehydratedConnectedMarketsIdsCache[i]);

            // prevent division by zero
            if (!market.getTotalDelegatedCreditUsd().isZero()) {
                // get the vault's accumulated debt, credit and reward changes from the market to update its stored
                // values
                (
                    ctx.realizedDebtChangeUsdX18,
                    ctx.unrealizedDebtChangeUsdX18,
                    ctx.usdcCreditChangeX18,
                    ctx.wethRewardChangeX18
                ) = market.getVaultAccumulatedValues(
                    ud60x18(creditDelegation.valueUsd),
                    sd59x18(creditDelegation.lastVaultDistributedRealizedDebtUsdPerShare),
                    sd59x18(creditDelegation.lastVaultDistributedUnrealizedDebtUsdPerShare),
                    ud60x18(creditDelegation.lastVaultDistributedUsdcCreditPerShare),
                    ud60x18(creditDelegation.lastVaultDistributedWethRewardPerShare)
                );
            }

            // if there's been no change in any of the returned values, we can iterate to the next
            // market id
            if (
                ctx.realizedDebtChangeUsdX18.isZero() && ctx.unrealizedDebtChangeUsdX18.isZero()
                    && ctx.usdcCreditChangeX18.isZero() && ctx.wethRewardChangeX18.isZero()
            ) {
                continue;
            }

            // update the vault's state by adding its share of the market's latest state variables
            vaultTotalRealizedDebtChangeUsdX18 = vaultTotalRealizedDebtChangeUsdX18.add(ctx.realizedDebtChangeUsdX18);
            vaultTotalUnrealizedDebtChangeUsdX18 =
                vaultTotalUnrealizedDebtChangeUsdX18.add(ctx.unrealizedDebtChangeUsdX18);
            vaultTotalUsdcCreditChangeX18 = vaultTotalUsdcCreditChangeX18.add(ctx.usdcCreditChangeX18);
            vaultTotalWethRewardChangeX18 = vaultTotalWethRewardChangeX18.add(ctx.wethRewardChangeX18);

            // update the last distributed debt, credit and reward values to the vault's credit delegation to the
            // given market id, in order to keep next calculations consistent
            creditDelegation.updateVaultLastDistributedValues(
                sd59x18(market.realizedDebtUsdPerVaultShare),
                sd59x18(market.unrealizedDebtUsdPerVaultShare),
                ud60x18(market.usdcCreditPerVaultShare),
                ud60x18(market.wethRewardPerVaultShare)
            );
        }
    }

    /// @notice Recalculates the latest credit capacity of the provided vaults ids taking into account their latest
    /// assets and debt usd denonimated values.
    /// @dev We use a `uint256` array because a market's connected vaults ids are stored at a `EnumerableSet.UintSet`.
    /// @dev We assume this function's caller checks that connectedMarketsIdsCache > 0.
    /// @param vaultsIds The array of vaults ids to recalculate the credit capacity.
    // todo: check where we're messing with the `continue` statement
    function recalculateVaultsCreditCapacity(uint256[] memory vaultsIds) internal {
        for (uint256 i; i < vaultsIds.length; i++) {
            // uint256 -> uint128
            uint128 vaultId = vaultsIds[i].toUint128();

            // load the vault storage pointer
            Data storage self = load(vaultId);

            // make sure there are markets connected to the vault
            uint256 connectedMarketsConfigLength = self.connectedMarkets.length;
            if (connectedMarketsConfigLength == 0) continue;

            // loads the connected markets storage pointer by taking the last configured market ids uint set
            EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[connectedMarketsConfigLength - 1];

            // cache the connected markets ids to avoid multiple storage reads, as we're going to loop over them twice
            // at `_recalculateConnectedMarketsState` and `_updateCreditDelegations`
            uint128[] memory connectedMarketsIdsCache = new uint128[](connectedMarkets.length());

            // update vault and credit delegation weight
            updateVaultAndCreditDelegationWeight(self, connectedMarketsIdsCache);

            // iterate over each connected market id and distribute its debt so we can have the latest credit
            // delegation of the vault id being iterated to the provided `marketId`
            (
                uint128[] memory updatedConnectedMarketsIdsCache,
                SD59x18 vaultTotalRealizedDebtChangeUsdX18,
                SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
                UD60x18 vaultTotalUsdcCreditChangeX18,
                UD60x18 vaultTotalWethRewardChangeX18
            ) = _recalculateConnectedMarketsState(self, connectedMarketsIdsCache, true);

            // gas optimization: only write to storage if values have changed
            //
            // updates the vault's stored unsettled realized debt distributed from markets
            if (!vaultTotalRealizedDebtChangeUsdX18.isZero()) {
                self.marketsRealizedDebtUsd = sd59x18(self.marketsRealizedDebtUsd).add(
                    vaultTotalRealizedDebtChangeUsdX18
                ).intoInt256().toInt128();
            }

            // updates the vault's stored unrealized debt distributed from markets
            if (!vaultTotalUnrealizedDebtChangeUsdX18.isZero()) {
                self.marketsUnrealizedDebtUsd = sd59x18(self.marketsUnrealizedDebtUsd).add(
                    vaultTotalUnrealizedDebtChangeUsdX18
                ).intoInt256().toInt128();
            }

            // adds the vault's total USDC credit change, earned from its connected markets, to the
            // `depositedUsdc` variable
            if (!vaultTotalUsdcCreditChangeX18.isZero()) {
                self.depositedUsdc = ud60x18(self.depositedUsdc).add(vaultTotalUsdcCreditChangeX18).intoUint128();
            }

            // distributes the vault's total WETH reward change, earned from its connected markets
            if (!vaultTotalWethRewardChangeX18.isZero() && self.wethRewardDistribution.totalShares != 0) {
                SD59x18 vaultTotalWethRewardChangeSD59X18 =
                    sd59x18(int256(vaultTotalWethRewardChangeX18.intoUint256()));
                self.wethRewardDistribution.distributeValue(vaultTotalWethRewardChangeSD59X18);
            }

            // update the vault's credit delegations
            (, SD59x18 vaultNewCreditCapacityUsdX18) =
                _updateCreditDelegations(self, updatedConnectedMarketsIdsCache, false);

            emit LogUpdateVaultCreditCapacity(
                vaultId,
                vaultTotalRealizedDebtChangeUsdX18.intoInt256(),
                vaultTotalUnrealizedDebtChangeUsdX18.intoInt256(),
                vaultTotalUsdcCreditChangeX18.intoUint256(),
                vaultTotalWethRewardChangeX18.intoUint256(),
                vaultNewCreditCapacityUsdX18.intoInt256()
            );
        }
    }

    /// @notice Updates an existing vault with the specified parameters.
    /// @dev Modifies the vault's settings. Reverts if the vault does not exist.
    /// @param params The struct containing the parameters required to update the vault.
    function update(UpdateParams memory params) internal {
        Data storage self = load(params.vaultId);

        if (self.id == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        self.depositCap = params.depositCap;
        self.withdrawalDelay = params.withdrawalDelay;
        self.isLive = params.isLive;
        self.lockedCreditRatio = params.lockedCreditRatio;
    }

    /// @notice Creates a new vault with the specified parameters.
    /// @dev Initializes the vault with the provided parameters. Reverts if the vault already exists.
    /// @param params The struct containing the parameters required to create the vault.
    function create(CreateParams memory params) internal {
        Data storage self = load(params.vaultId);

        if (self.id != 0) {
            revert Errors.VaultAlreadyExists(params.vaultId);
        }

        self.id = params.vaultId;
        self.depositCap = params.depositCap;
        self.withdrawalDelay = params.withdrawalDelay;
        self.indexToken = params.indexToken;
        self.collateral = params.collateral;
        self.depositFee = params.depositFee;
        self.redeemFee = params.redeemFee;
        self.engine = params.engine;
        self.isLive = true;
    }

    /// @notice Updates the swap strategy for a specific vault in storage.
    /// @param vaultId The unique identifier of the vault.
    /// @param assetDexSwapPath The encoded path for the asset swap on the DEX.
    /// @param usdcDexSwapPath The encoded path for the USDC swap on the DEX.
    /// @param assetDexSwapStrategyId The identifier for the asset DEX swap strategy.
    /// @param usdcDexSwapStrategyId The identifier for the USDC DEX swap strategy.
    function updateVaultSwapStrategy(
        uint128 vaultId,
        bytes memory assetDexSwapPath,
        bytes memory usdcDexSwapPath,
        uint128 assetDexSwapStrategyId,
        uint128 usdcDexSwapStrategyId
    )
        internal
    {
        Data storage self = load(vaultId);

        self.swapStrategy.assetDexSwapPath = assetDexSwapPath;
        self.swapStrategy.usdcDexSwapPath = usdcDexSwapPath;
        self.swapStrategy.assetDexSwapStrategyId = assetDexSwapStrategyId;
        self.swapStrategy.usdcDexSwapStrategyId = usdcDexSwapStrategyId;
    }

    /// @notice Update the vault and credit delegation weight
    /// @param self The vault storage pointer.
    /// @param connectedMarketsIdsCache The cached connected markets ids.
    function updateVaultAndCreditDelegationWeight(
        Data storage self,
        uint128[] memory connectedMarketsIdsCache
    )
        internal
    {
        // cache the connected markets length
        uint256 connectedMarketsConfigLength = self.connectedMarkets.length;

        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[connectedMarketsConfigLength - 1];

        // get the total of shares
        uint128 newWeight = uint128(IERC4626(self.indexToken).totalAssets());

        for (uint256 i; i < connectedMarketsIdsCache.length; i++) {
            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation =
                CreditDelegation.load(self.id, connectedMarkets.at(i).toUint128());

            // update the credit delegation weight
            creditDelegation.weight = newWeight;
        }

        // update the vault weight
        self.totalCreditDelegationWeight = newWeight;
    }

    /// @notice Updates the vault's credit delegations to its connected markets, using the provided cache of connected
    /// markets ids.
    /// @dev This function assumes that the connected markets ids cache is up to date with the stored markets ids. If
    /// this invariant resolves to false, the function will not work as expected.
    /// @dev We assume self.totalCreditDelegationWeight is always greater than zero, as it's verified during
    /// configuration.
    /// @param self The vault storage pointer.
    /// @param connectedMarketsIdsCache The cached connected markets ids.
    /// @param shouldRehydrateCache Whether the connected markets ids cache should be rehydrated or not.
    /// @return rehydratedConnectedMarketsIdsCache The potentially rehydrated connected markets ids cache.
    function _updateCreditDelegations(
        Data storage self,
        uint128[] memory connectedMarketsIdsCache,
        bool shouldRehydrateCache
    )
        private
        returns (uint128[] memory rehydratedConnectedMarketsIdsCache, SD59x18 vaultCreditCapacityUsdX18)
    {
        rehydratedConnectedMarketsIdsCache = new uint128[](connectedMarketsIdsCache.length);
        // cache the vault id
        uint128 vaultId = self.id;

        // cache the connected markets length
        uint256 connectedMarketsConfigLength = self.connectedMarkets.length;

        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[connectedMarketsConfigLength - 1];

        // loop over each connected market id that has been cached once again in order to update this vault's
        // credit delegations
        for (uint256 i; i < connectedMarketsIdsCache.length; i++) {
            // rehydrate the markets ids cache if needed
            if (shouldRehydrateCache) {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarkets.at(i).toUint128();
            } else {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarketsIdsCache[i];
            }

            // loads the memory cached market id
            uint128 connectedMarketId = rehydratedConnectedMarketsIdsCache[i];

            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation = CreditDelegation.load(vaultId, connectedMarketId);

            // cache the previous credit delegation value
            UD60x18 previousCreditDelegationUsdX18 = ud60x18(creditDelegation.valueUsd);

            // cache the latest credit delegation share of the vault's credit capacity
            uint128 totalCreditDelegationWeightCache = self.totalCreditDelegationWeight;

            if (totalCreditDelegationWeightCache != 0) {
                // get the latest credit delegation share of the vault's credit capacity
                UD60x18 creditDelegationShareX18 =
                    ud60x18(creditDelegation.weight).div(ud60x18(totalCreditDelegationWeightCache));

                // stores the vault's total credit capacity to be returned
                vaultCreditCapacityUsdX18 = getTotalCreditCapacityUsd(self);

                // if the vault's credit capacity went to zero or below, we set its credit delegation to that market
                // to zero
                UD60x18 newCreditDelegationUsdX18 = vaultCreditCapacityUsdX18.gt(SD59x18_ZERO)
                    ? vaultCreditCapacityUsdX18.intoUD60x18().mul(creditDelegationShareX18)
                    : UD60x18_ZERO;

                // calculate the delta applied to the market's total delegated credit
                UD60x18 creditDeltaUsdX18 = newCreditDelegationUsdX18.sub(previousCreditDelegationUsdX18);

                // loads the market's storage pointer and update total delegated credit
                Market.Data storage market = Market.load(connectedMarketId);
                market.updateTotalDelegatedCredit(creditDeltaUsdX18);

                // if new credit delegation is zero, we clear the credit delegation storage
                if (newCreditDelegationUsdX18.isZero()) {
                    creditDelegation.clear();
                } else {
                    // update the credit delegation stored usd value
                    creditDelegation.valueUsd = newCreditDelegationUsdX18.intoUint128();
                }
            }
        }
    }
}
