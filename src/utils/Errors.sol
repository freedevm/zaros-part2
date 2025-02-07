// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

library Errors {
    /// @notice Generic protocol errors.

    /// @notice Thrown when the given input of a function is its zero value.
    error ZeroInput(string parameter);
    /// @notice Thrown when the sender is not authorized to perform a given action.
    error Unauthorized(address sender);
    /// @notice Thrown when two or more array parameters are expected to have the same length, but they don't.
    error ArrayLengthMismatch(uint256 expected, uint256 actual);
    /// @notice Thrown when the whitelist mode is enabled and user is not allowed
    error UserIsNotAllowed(address user);

    /// @notice AssetToAmountMap utility errors.

    /// @notice Thrown when trying to decrement an asset that is not in the map.
    error InvalidAssetToAmountMapUpdate();

    /// @notice RootProxy errors.
    error UnsupportedFunction(bytes4 functionSignature);

    /// @notice RootUpgrade errors.
    error IncorrectBranchUpgradeAction();
    error BranchIsZeroAddress();
    error BranchIsNotContract(address branch);
    error SelectorArrayEmpty(address branch);
    error SelectorIsZero();
    error FunctionAlreadyExists(bytes4 functionSelector);
    error ImmutableBranch();
    error FunctionFromSameBranch(bytes4 functionSelector);
    error NonExistingFunction(bytes4 functionSelector);
    error CannotRemoveFromOtherBranch(address branch, bytes4 functionSelector);
    error InitializableIsNotContract(address initializable);

    /// @notice Chainlink Keepers errors.

    /// @notice Thrown when an oracle aggregator returns an answer out of range of min and max.
    error OraclePriceFeedOutOfRange(address priceFeed);
    /// @notice Thrown when an oracle sequencer uptime feed returns an unexpected, invalid value.
    error InvalidSequencerUptimeFeedReturn(address sequencerUptimeFeedAddress);
    /// @notice Thrown when an oracle sequencer uptime feed returns an unexpected, invalid value.
    error OracleSequencerUptimeFeedIsDown(address sequencerUptimeFeed);
    /// @notice Thrown when an oracle grace period is not over.
    error GracePeriodNotOver(address sequencerUptimeFeedAddress);
    /// @notice Thrown when an oracle returns an unexpected, invalid value.
    error InvalidOracleReturn();
    /// @notice Thrown when an oracle price feed is outdated.
    error OraclePriceFeedHeartbeat(address priceFeed);
    /// @notice Thrown when the keeper provided checkData bounds are invalid.
    error InvalidBounds();
    /// @notice Thrown when an oracle sequencer is not started.
    error OracleSequencerUptimeFeedNotStarted(address sequencerUptimeFeedAddress);

    /// @notice PerpsEngine.OrderBranch errors

    /// @notice Thrown when trying to cancel an active market order and there's none.
    error NoActiveMarketOrder(uint128 tradingAccountId);
    /// @notice Thrown when trying to trade and the account is eligible for liquidation.
    error AccountIsLiquidatable(uint128 tradingAccountId);
    error NewPositionSizeTooSmall();

    /// @notice PerpsEngine.TradingAccountBranch

    /// @notice Thrown When the provided amount in 18 decimals of collateral exceeds the deposit cap.
    error DepositCap(address collateralType, uint256 amountX18, uint256 depositCapX18);
    /// @notice Thrown when there's not enough margin collateral to be withdrawn.
    error InsufficientCollateralBalance(uint256 amount, uint256 balance);
    /// @notice Thrown When the caller is not the account token contract.
    error OnlyTradingAccountToken(address sender);
    /// @notice Thrown when the caller is not authorized by the owner of the TradingAccount.
    error AccountPermissionDenied(uint128 tradingAccountId, address sender);
    /// @notice Thrown when the given `tradingAccountId` doesn't exist.
    error AccountNotFound(uint128 tradingAccountId, address sender);
    /// @notice Thrown when the given `tradingAccountId` tries to open a new position but it has already reached the
    /// limit.
    error MaxPositionsPerAccountReached(
        uint128 tradingAccountId, uint256 activePositionsLength, uint256 maxPositionsPerAccount
    );
    /// @notice Thrown when trying to settle an order and the account has insufficient margin for the new position.
    error InsufficientMargin(
        uint128 tradingAccountId, int256 marginBalanceUsdX18, uint256 requiredMarginUsdX18, uint256 totalFeesUsdX18
    );
    /// @notice Thrown when trying to deposit a collteral type that isn't in the liquidation priority configuration.
    error CollateralLiquidationPriorityNotDefined(address collateralType);
    /// @notice Thrown when the provided referral code is invalid.
    error InvalidReferralCode();
    /// @notice Thrown when trying to withdraw margin while having active order.
    error ActiveMarketOrder(uint128 tradingAccountId, uint128 marketId, int128 sizeDelta, uint256 timestamp);
    /// @notice Thrown when the user tries to withdraw more margin than is allowed while having open position
    error NotEnoughCollateralForLiquidationFee(uint256 liquidationFeeUsdX18);

    /// @notice PerpsEngine.PerpsEngineConfigurationBranch

    /// @notice Thrown when the provided `sequencerUptimeFeed` is the zero address.
    error SequencerUptimeFeedNotDefined();
    /// @notice Thrown when the provided `accountToken` is the zero address.
    error TradingAccountTokenNotDefined();
    /// @notice Thrown when `collateralType` decimals are greater than the system's decimals.
    error InvalidMarginCollateralConfiguration(address collateralType, uint8 decimals, address priceFeed);
    /// @notice Thrown when trying to update a market status but it hasn't been initialized yet.
    error PerpMarketNotInitialized(uint128 marketId);
    /// @notice Thrown when the provided `collateralType` is not in the collateral priority list when trying to remove
    /// it.
    error MarginCollateralTypeNotInPriority(address collateralType);
    /// @notice Thrown when the provided `collateralType` is already in the collateral priority list when trying to
    /// add
    error MarginCollateralAlreadyInPriority(address collateralType);
    /// @notice Thrown when a given trade is below the protocol configured min trade size in usd.
    error TradeSizeTooSmall();
    /// @notice Thrown when the provided `initialMarginRate` is less or equal than the `maintenanceMarginRate`.
    error InitialMarginRateLessOrEqualThanMaintenanceMarginRate();

    /// @notice PerpsEngine.SettlementBranch errors.

    /// @notice Thrown when the selected market id mismatch with the order's market id.
    error OrderMarketIdMismatch(uint128 marketId, uint128 orderMarketId);

    /// @notice Thrown when the caller is not the registered Keeper contract.
    error OnlyKeeper(address sender, address keeper);
    /// @notice Thrown when the signed `nonce` of a given order is not equal to the trading account's current nonce.
    error InvalidSignedNonce(uint128 tradingAccountNonce, uint120 orderNonce);
    /// @notice Thrown when an order signed by the `tradingAccountId` owner using the given `salt` has already been
    /// filled.
    error OrderAlreadyFilled(uint128 tradingAccountId, bytes32 salt);
    /// @notice Thrown when the recovered ECDSA signer of an offchain order is not the trading account owner.
    error InvalidOrderSigner(address signer, address expectedSigner);

    /// @notice PerpsEngine.PerpMarketBranch errors.

    /// @notice PerpsEngine.PerpsEngineConfiguration errors.

    /// @notice Thrown when the provided `marketId` doesn't exist or is currently disabled.
    error PerpMarketDisabled(uint128 marketId);
    /// @notice Thrown when the provided `marketId` is already enabled when trying to enable a market.
    error PerpMarketAlreadyEnabled(uint128 marketId);
    /// @notice Thrown when the provided `marketId` is already disabled when trying to disable a market.
    error PerpMarketAlreadyDisabled(uint128 marketId);

    /// @notice PerpsEngine.LiquidationBranch errors.

    error LiquidatorNotRegistered(address sender);

    /// @notice PerpsEngine.PerpMarket errors.

    /// @notice Thrown when there's no price adapter configured for a given perp market.
    error PriceAdapterNotDefined(uint128 marketId);
    /// @notice Thrown when an order tries to exceed the market's open interest cap.
    error ExceedsOpenInterestLimit(uint128 marketId, uint256 maxOpenInterest, uint256 newOpenInterest);
    /// @notice Thrown when an order tries to exceed the market's skew limit.
    error ExceedsSkewLimit(uint128 marketId, uint256 maxSkew, int256 newSkew);
    /// @notice Thrown when a perps market id has already been used.
    error MarketAlreadyExists(uint128 marketId);

    /// @notice PerpsEngine.MarginCollateralConfiguration errors.

    /// @notice Thrown when the {MarginCollateralConfiguration} doesn't have a price feed defined to return its price.
    error CollateralPriceFeedNotDefined();

    /// @notice PerpsEngine.MarketOrder errors.

    /// @notice Thrown when an account tries to create a new market order, and there's already an
    /// existing order with pending settlement.
    error MarketOrderStillPending(uint256 timestamp);

    /// @notice PerpsEngine.SettlementConfiguration errors.

    /// @notice Thrown when a configured settlement configuration is disabled.
    error SettlementDisabled();
    /// @notice Thrown when the provided settlement strategy for a perp market is invalid (e.g market order strategy
    /// for custom configuration).
    error InvalidSettlementStrategy();
    /// @notice Thrown when the provided settlement configuration id does not exist.
    error InvalidSettlementConfigurationId();
    /// @notice Thrown when the provided report's `reportStreamId` doesn't match the settlement configuration's
    /// one.
    error InvalidDataStreamReport(bytes32 streamId, bytes32 reportStreamId);

    /// @notice MarketMakingEngine.MarketMakingEngineBranch errors.

    /// @notice Thrown when the total of protocol fee recipient share exceeds 1e18
    error FeeRecipientShareExceedsLimit();

    /// @notice MarketMakingEngine.CreditDelegationBranch errors.

    /// @notice Thrown when the given `marketId` has no vaults delegating credit to it. This error must be unreachable
    /// and treated as a panic state.
    error NoConnectedVaults(uint128 marketId);
    /// @notice Thrown when trying to realize debt but the market has a credit capacity <= 0. The ADL
    /// system and LP's collateral risk parameters are built to prevent this error from being thrown.
    error InsufficientCreditCapacity(uint128 marketId, int256 creditCapacityUsd);
    /// @notice Thrown when trying to distribute value to an empty vaults debt distribution.
    /// NOTE: This error must be unreachable as the system enforces market to have a minimum delegated credit through
    /// Vault.Data.lockedCreditRatio.
    error NoDelegatedCredit(uint128 marketId);
    /// @notice Thrown when there aren't enough assets to cover the settlement base fee.
    error FailedToPaySettlementBaseFee();
    /// @notice Thrown when trying to rebalance vaults connected to different engines.
    error VaultsConnectedToDifferentEngines();
    /// @notice Thrown when trying to settle vaults debt using a usd token but one of the vaults involved are in an
    /// unexpected credit / debt state.
    error InvalidVaultDebtSettlementRequest();

    /// @notice MarketMakingEngine.Collateral errors.
    error CollateralDisabled(address collateralType);

    /// @notice MarketMakingEngine.Distribution errors.

    /// @notice Thrown when trying to distribute value to an empty distribution.
    error EmptyDistribution();

    /// @notice MarketMakingEngine.Market errors.

    /// @notice Thrown when the given `marketId` does not exist.
    error MarketDoesNotExist(uint128 marketId);

    /// @notice Thrown when the given `marketId` is disabled.
    error MarketIsDisabled(uint128 marketId);

    /// @notice MarketMakingEngine.WithdrawalRequest errors.

    /// @notice Thrown when a withdrawal request does not exist.
    /// @param vaultId The vault to withdraw assets from identifier.
    /// @param account The address of the user account requesting the withdrawal.
    /// @param withdrawalRequestId The withdrawal request identifier.
    error WithdrawalRequestDoesNotExist(uint128 vaultId, address account, uint128 withdrawalRequestId);

    /// @notice MarketMakingEngine.VaultRouterBranch errors

    /// @notice Thrown when `expectedAssetsOut` equals zero during a swap.
    error ZeroOutputTokens();

    /// @notice Thrown when a slippage check fails.
    /// @param minAmountOut The min amnount of assets to receive back
    /// @param amountOut The result of the swap execution
    error SlippageCheckFailed(uint256 minAmountOut, uint256 amountOut);

    /// @notice Thrown when a vault has insufficient balance to fulfill a swap request.
    /// @param vaultId The ID of the vault to swap assets from.
    /// @param vaultAssetBalance The current balance of the vault's asset.
    /// @param expectedAmountOut The amount of assets expected to receive after the swap.
    error InsufficientVaultBalance(uint256 vaultId, uint256 vaultAssetBalance, uint256 expectedAmountOut);

    /// @notice Thrown when a user does not have enough shares.
    error NotEnoughShares();

    /// @notice Thrown when a withdrawal is attempted before the required delay has passed.
    error WithdrawDelayNotPassed();

    /// @notice Thrown when a withdraw request is fulfilled.
    error WithdrawalRequestAlreadyFulfilled();

    /// @notice Thrown when vault with the given id already exists.
    /// @param vaultId The ID of the vault to create.
    error VaultAlreadyExists(uint256 vaultId);

    /// @notice Thrown when vault does NOT exist
    /// @param vaultId The ID of the vault that does NOT exist.
    error VaultDoesNotExist(uint128 vaultId);

    /// @notice Thrown when vault is NOT live.
    /// @dev A vault could be paused by setting its `isLive` flag to false.
    /// @param vaultId The ID of the vault that is NOT live.
    error VaultIsDisabled(uint128 vaultId);

    /// @notice Thrown when the quantity of shares is less than the minimum allowed.
    error QuantityOfSharesLessThanTheMinimumAllowed(uint256 minimumAllowed, uint256 quantity);

    /// @notice Thrown when trying to redeem shares for vault assets but it has insufficient available credit capacity
    /// to fulfill the request.
    error NotEnoughUnlockedCreditCapacity();

    /// @notice Throws when user tries to unstake, but has pending rewards
    /// @param actorId The id of the user unstaking
    /// @param pendingReward The pending reward of the user
    error UserHasPendingRewards(bytes32 actorId, uint256 pendingReward);

    /// @notice MarketMakingEngine.Vault errors.

    /// @notice Thrown when the vault is not connected to any market.
    error NoMarketsConnectedToVault(uint128 vaultId);

    /// @notice Dex Swap Strategy errors.

    /// @notice Thrown when dex swap strategy pool fee set to zero
    error InvalidPoolFee();

    /// @notice MarketMakingEngine.FeeDistributionBranch errors

    /// @notice Thrown when there are no available wEth fees to be collected
    error NoWethFeesCollected();

    /// @notice Thrown when user does not have fees to claim
    error NoFeesToClaim();

    /// @notice Thrown when fees should be > 0
    error ZeroFeeNotAllowed();

    /// @notice Thrown when user does not have shares to claim fees
    error NoSharesAvailable();

    /// @notice Thrown when the Dex Swap Strategy has an invalid dex adapter
    error DexSwapStrategyHasAnInvalidDexAdapter(uint128 dexSwapStrategyId);

    /// @notice Thrown when the asset is not in the market
    /// @param asset The asset that is not in the market
    error MarketDoesNotContainTheAsset(address asset);

    /// @notice Thrown when the asset amount is zero
    /// @param asset The asset that has zero amount
    error AssetAmountIsZero(address asset);

    /// @notice MarketMakingEngine.StabilityBranch errors.

    /// @notice Thrown when swap request is not yet expired
    /// @param user the user that initiated the request
    /// @param requestId The id of the request
    error RequestNotExpired(address user, uint128 requestId);

    /// @notice Thrown when request was already processed
    /// @param user the user that initiated the request
    /// @param requestId The id of the request
    error RequestAlreadyProcessed(address user, uint128 requestId);

    /// @notice Thrown when trying to swap usd tokens for different assets in a single `StabilityBranch::initiateSwap`
    /// call.
    error VaultsCollateralAssetsMismatch();

    /// @notice Thrown when the data stream report has expired
    error DataStreamReportExpired();

    /// Thrown when the request has expired
    /// @param user the user that initiated the request
    /// @param requestId The id of the request
    /// @param expiration The request expiration time
    error SwapRequestExpired(address user, uint128 requestId, uint256 expiration);

    /// @notice Thrown when swap path is invalid - assets and swap strategy ids mismatch
    error InvalidSwapPathParamsLength();

    /// @notice Thrown when a swap's expected output calculates to zero
    error ZeroExpectedSwapOutput();

    /// @notice Thrown when a swap's deadline is in the past
    error SwapDeadlineInThePast();

    /// @notice Thrown when a deposit would be eaten up by fees
    error DepositTooSmall();

    /// @notice Thrown when a deposit receives zero shares
    error DepositMustReceiveShares();

    /// @notice Thrown when a redeem receives zero assets
    error RedeemMustReceiveAssets();

    /// @notice Thrown when slippage tolerance is too low
    /// @param newSlippageTolerance proposed new slippage tolerance
    /// @param minSlippageBps minimum allowed value
    error MinSlippageTolerance(uint256 newSlippageTolerance, uint256 minSlippageBps);

    /// @notice Thrown when slippage tolerance is too high
    /// @param newSlippageTolerance proposed new slippage tolerance
    /// @param maxSlippageBps minimum allowed value
    error MaxSlippageTolerance(uint256 newSlippageTolerance, uint256 maxSlippageBps);
}
