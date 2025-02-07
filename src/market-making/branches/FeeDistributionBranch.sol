// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { AssetSwapPath } from "@zaros/market-making/leaves/AssetSwapPath.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Market } from "src/market-making/leaves/Market.sol";
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch is EngineAccessControl {
    using Collateral for Collateral.Data;
    using DexSwapStrategy for DexSwapStrategy.Data;
    using Distribution for Distribution.Data;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using Market for Market.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeERC20 for IERC20;
    using Vault for Vault.Data;

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the market making engine receives collateral type for fee distribution
    /// @param marketId The market receiving the fees
    /// @param asset The collateral type address.
    /// @param amount The token amount of collateral type received.
    event LogReceiveMarketFee(address indexed asset, uint128 marketId, uint256 amount);

    /// @notice Emitted when received collateral type has been converted to weth.
    /// @param totalWethX18 The total amounf of weth received once converted.
    event LogConvertAccumulatedFeesToWeth(uint256 totalWethX18);

    /// @notice Emitted when weth rewards are sent to fee recipients.
    /// @param marketId The market that distributed weth to the protocol fee recipients.
    /// @param totalWethReward The total weth reward amount sent to fee recipients, using weth's decimals.
    event LogSendWethToFeeRecipients(uint128 indexed marketId, uint256 totalWethReward);

    /// @notice Emitted when a user claims their accumulated fees.
    /// @param claimer Address of the user who claimed the fees.
    /// @param vaultId Identifier of the vault from which fees were claimed.
    /// @param amount Amount of WETH claimed as fees.
    event LogClaimFees(address indexed claimer, uint128 indexed vaultId, uint256 amount);

    /// @notice Returns the claimable amount of weth fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return earnedFees The amount of weth fees claimable.
    function getEarnedFees(uint128 vaultId, address staker) external view returns (uint256 earnedFees) {
        Vault.Data storage vault = Vault.load(vaultId);

        bytes32 actorId = bytes32(uint256(uint160(staker)));

        earnedFees = vault.wethRewardDistribution.getActorValueChange(actorId).intoUint256();
    }

    /// @notice Receives collateral as a fee for processing,
    /// this fee later will be converted to WETH and sent to beneficiaries.
    /// @dev onlyRegisteredEngine address can call this function.
    /// @param marketId The market receiving the fees.
    /// @param asset The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.
    function receiveMarketFee(
        uint128 marketId,
        address asset,
        uint256 amount
    )
        external
        onlyRegisteredEngine(marketId)
    {
        // verify input amount
        if (amount == 0) revert Errors.ZeroInput("amount");

        // loads the market data storage pointer
        Market.Data storage market = Market.loadExisting(marketId);

        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(asset);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // convert uint256 -> UD60x18; scales input amount to 18 decimals
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // transfer fee amount
        // note: we're calling `ERC20::transferFrom` before state transitions as `_handleWethRewardDistribution`
        // requires assets to be in the contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        if (asset == MarketMakingEngineConfiguration.load().weth) {
            // if asset is weth, we can skip straight to handling the weth reward distribution
            _handleWethRewardDistribution(market, address(0), amountX18);
        } else {
            // update [asset => received fees] mapping
            market.depositFee(asset, amountX18);
        }

        // emit event to log the received fee
        emit LogReceiveMarketFee(asset, marketId, amount);
    }

    struct ConvertAccumulatedFeesToWethContext {
        UD60x18 assetAmountX18;
        uint256 assetAmount;
        UD60x18 receivedWethX18;
        address weth;
        uint256 tokensSwapped;
        UD60x18 feeRecipientsSharesX18;
        UD60x18 receivedProtocolWethRewardX18;
        UD60x18 receivedVaultsWethRewardX18;
    }

    /// @notice Converts collected collateral amount to WETH
    /// @dev Only registered system keepers can call this function.
    /// @dev Net WETH rewards are split among fee recipients and vaults delegating credit to the market, according to
    /// the configured share values.
    /// @param marketId The id of the market to have its fees converted to WETH.
    /// @param asset The asset to be swapped for WETH.
    /// @param dexSwapStrategyId The dex swap strategy id to be used for swapping.
    /// @param path The path is a sequence of (tokenAddress - fee - tokenAddress),
    /// which are the variables needed to compute each pool contract address in our sequence of swaps.
    /// The multihop swap router code will automatically find the correct pool with these variables,
    /// and execute the swap needed within each pool in our sequence.
    /// The path param could be empty if the swap is single input.
    function convertAccumulatedFeesToWeth(
        uint128 marketId,
        address asset,
        uint128 dexSwapStrategyId,
        bytes calldata path
    )
        external
        onlyRegisteredSystemKeepers
    {
        // loads the collateral data storage pointer, collateral must be enabled
        Collateral.Data storage collateral = Collateral.load(asset);
        collateral.verifyIsEnabled();

        // loads the market data storage pointer
        Market.Data storage market = Market.loadExisting(marketId);

        // reverts if the market hasn't received any fees for the given asset
        (bool exists, uint256 receivedFees) = market.receivedFees.tryGet(asset);
        if (!exists) revert Errors.MarketDoesNotContainTheAsset(asset);
        if (receivedFees == 0) revert Errors.AssetAmountIsZero(asset);

        // working data, converted receivedFees uint256 -> UD60x18
        ConvertAccumulatedFeesToWethContext memory ctx;
        ctx.assetAmountX18 = ud60x18(receivedFees);

        // convert the asset amount to token amount
        ctx.assetAmount = collateral.convertUd60x18ToTokenAmount(ctx.assetAmountX18);

        // load weth address
        ctx.weth = MarketMakingEngineConfiguration.load().weth;

        // if asset is weth directly add to accumulated weth, else swap token for weth
        if (asset == ctx.weth) {
            // store the amount of weth
            ctx.receivedWethX18 = ctx.assetAmountX18;
        } else {
            // load the weth collateral data storage pointer
            Collateral.Data storage wethCollateral = Collateral.load(ctx.weth);

            // load custom swap path for asset if enabled
            AssetSwapPath.Data storage swapPath = AssetSwapPath.load(asset);

            // verify if the swap should be input multi-dex/custom swap path, single or multihop
            if (swapPath.enabled) {
                ctx.tokensSwapped = _performMultiDexSwap(swapPath, ctx.assetAmount);
            } else if (path.length == 0) {
                // loads the dex swap strategy data storage pointer
                DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.loadExisting(dexSwapStrategyId);

                // approve the collateral token to the dex adapter
                IERC20(asset).approve(dexSwapStrategy.dexAdapter, ctx.assetAmount);

                // prepare the data for executing the swap
                SwapExactInputSinglePayload memory swapCallData = SwapExactInputSinglePayload({
                    tokenIn: asset,
                    tokenOut: ctx.weth,
                    amountIn: ctx.assetAmount,
                    recipient: address(this)
                });
                // Swap collected collateral fee amount for WETH and store the obtained amount
                ctx.tokensSwapped = dexSwapStrategy.executeSwapExactInputSingle(swapCallData);
            } else {
                // loads the dex swap strategy data storage pointer
                DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.loadExisting(dexSwapStrategyId);

                // approve the collateral token to the dex adapter
                IERC20(asset).approve(dexSwapStrategy.dexAdapter, ctx.assetAmount);

                // prepare the data for executing the swap
                SwapExactInputPayload memory swapCallData = SwapExactInputPayload({
                    path: path,
                    tokenIn: asset,
                    tokenOut: ctx.weth,
                    amountIn: ctx.assetAmount,
                    recipient: address(this)
                });

                // Swap collected collateral fee amount for WETH and store the obtained amount
                ctx.tokensSwapped = dexSwapStrategy.executeSwapExactInput(swapCallData);
            }

            // uint256 -> ud60x18
            ctx.receivedWethX18 = wethCollateral.convertTokenAmountToUd60x18(ctx.tokensSwapped);
        }
        // handles distribution of the weth reward between the protocol and market
        _handleWethRewardDistribution(market, asset, ctx.receivedWethX18);

        // emit event to log the conversion of fees to weth
        emit LogConvertAccumulatedFeesToWeth(ctx.receivedWethX18.intoUint256());
    }

    /// @notice Sends allocated weth amount to fee recipients.
    /// @dev onlyRegisteredEngine address can call this function.
    /// @param marketId The market to which fee recipients contribute.
    function sendWethToFeeRecipients(uint128 marketId) external onlyRegisteredEngine(marketId) {
        // loads the fee data storage pointer
        Market.Data storage market = Market.loadExisting(marketId);

        // reverts if no protocol weth rewards have been collected
        if (market.availableProtocolWethReward == 0) revert Errors.NoWethFeesCollected();

        // loads the market making engine configuration data storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // cache the weth address
        address weth = marketMakingEngineConfiguration.weth;

        // load weth collateral configuration
        Collateral.Data storage wethCollateralData = Collateral.load(weth);

        // convert collected fees to UD60x18 and convert decimals if needed, to ensure it's using the network's weth
        // decimals value
        uint256 availableProtocolWethReward =
            wethCollateralData.convertUd60x18ToTokenAmount(ud60x18(market.availableProtocolWethReward));

        // get total shares
        UD60x18 totalShares = ud60x18(marketMakingEngineConfiguration.totalFeeRecipientsShares);

        // this condition can never be hit since if shares is zero, availableProtocolWethReward
        // will also be zero, since in convertAccumulatedFeesToWeth at the end if there are no
        // fee recipient shares all weth rewards would go to the vaults
        if (totalShares.isZero()) {
            // if total shares is zero, revert
            revert Errors.NoSharesAvailable();
        }

        // set to zero the amount of pending weth to be distributed
        market.availableProtocolWethReward = 0;

        // sends the accumulated protocol weth reward to the configured fee recipients
        marketMakingEngineConfiguration.distributeProtocolAssetReward(weth, availableProtocolWethReward);

        // emit event to log the weth sent to fee recipients
        emit LogSendWethToFeeRecipients(marketId, availableProtocolWethReward);
    }

    /// @notice allows user to claim their share of fees
    /// @param vaultId the vault fees are claimed from
    function claimFees(uint128 vaultId) external {
        // load the vault data storage pointer
        Vault.Data storage vault = Vault.load(vaultId);

        // get the actor id
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        // reverts if the actor has no shares
        if (vault.wethRewardDistribution.actor[actorId].shares == 0) revert Errors.NoSharesAvailable();

        // get the claimable amount of fees
        UD60x18 amountToClaimX18 = vault.wethRewardDistribution.getActorValueChange(actorId).intoUD60x18();

        // reverts if the claimable amount is 0
        if (amountToClaimX18.isZero()) revert Errors.NoFeesToClaim();

        vault.wethRewardDistribution.accumulateActor(actorId);

        // weth address
        address weth = MarketMakingEngineConfiguration.load().weth;

        // load the weth collateral data storage pointer
        Collateral.Data storage wethCollateral = Collateral.load(weth);

        // convert the amount to claim to weth amount
        uint256 amountToClaim = wethCollateral.convertUd60x18ToTokenAmount(amountToClaimX18);

        // transfer the amount to the claimer
        IERC20(weth).safeTransfer(msg.sender, amountToClaim);

        // emit event to log the amount claimed
        emit LogClaimFees(msg.sender, vaultId, amountToClaim);
    }

    /// @notice Calculates the value of a specified asset in terms of its collateral.
    /// @dev Uses the asset's price and amount to compute its value.
    /// @param asset The address of the asset.
    /// @param amount The amount of the asset to calculate the value for.
    /// @return value The calculated value of the asset in its native units.
    function getAssetValue(address asset, uint256 amount) public view returns (uint256 value) {
        // load collateral
        Collateral.Data storage collateral = Collateral.load(asset);

        // get asset price in 18 dec
        UD60x18 priceX18 = collateral.getPrice();

        // convert token amount to 18 dec
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // calculate token value based on price
        UD60x18 valueX18 = priceX18.mul(amountX18);

        // ud60x18 -> uint256
        value = collateral.convertUd60x18ToTokenAmount(valueX18);
    }

    /// @notice Retrieves the assets and corresponding fees collected for a specific market.
    /// @param marketId The ID of the market whose received fees are being queried.
    /// @return assets An array of asset addresses for which fees were collected.
    /// @return feesCollected An array of fee amounts corresponding to the assets.
    function getReceivedMarketFees(uint128 marketId)
        external
        view
        returns (address[] memory assets, uint256[] memory feesCollected)
    {
        Market.Data storage market = Market.loadExisting(marketId);

        EnumerableMap.AddressToUintMap storage receivedMarketFees = market.receivedFees;
        uint256 length = receivedMarketFees.length();

        assets = new address[](length);
        feesCollected = new uint256[](length);

        for (uint256 i; i < length; i++) {
            (assets[i], feesCollected[i]) = receivedMarketFees.at(i);
        }
    }

    /// @notice Retrieves the details of a specific DEX swap strategy.
    /// @param dexSwapStrategyId The unique identifier of the DEX swap strategy.
    /// @return The data of the specified DEX swap strategy.
    function getDexSwapStrategy(uint128 dexSwapStrategyId) external pure returns (DexSwapStrategy.Data memory) {
        return DexSwapStrategy.load(dexSwapStrategyId);
    }

    function _handleWethRewardDistribution(
        Market.Data storage market,
        address assetOut,
        UD60x18 receivedWethX18
    )
        internal
    {
        // cache the total fee recipients shares as UD60x18
        UD60x18 feeRecipientsSharesX18 = ud60x18(MarketMakingEngineConfiguration.load().totalFeeRecipientsShares);

        // calculate the weth rewards for protocol and vaults
        UD60x18 receivedProtocolWethRewardX18 = receivedWethX18.mul(feeRecipientsSharesX18);
        UD60x18 receivedVaultsWethRewardX18 =
            receivedWethX18.mul(ud60x18(Constants.MAX_SHARES).sub(feeRecipientsSharesX18));

        // calculate leftover reward
        UD60x18 leftover = receivedWethX18.sub(receivedProtocolWethRewardX18).sub(receivedVaultsWethRewardX18);

        // add leftover reward to vault reward
        receivedVaultsWethRewardX18 = receivedVaultsWethRewardX18.add(leftover);

        // adds the weth received for protocol and vaults rewards using the assets previously paid by the engine
        // as fees, and remove its balance from the market's `receivedMarketFees` map
        market.receiveWethReward(assetOut, receivedProtocolWethRewardX18, receivedVaultsWethRewardX18);

        // recalculate markes' vaults credit delegations after receiving fees to push reward distribution
        Vault.recalculateVaultsCreditCapacity(market.getConnectedVaultsIds());
    }

    /// @notice Performs a custom swap path across multiple assets using specified DEX swap strategies.
    /// @param swapPath The structured data defining the assets and DEX swap strategies to use for the swap.
    /// @param assetAmount The initial amount of the input asset to swap.
    /// @return The amount of the final output asset obtained after completing the swap path.
    function _performMultiDexSwap(
        AssetSwapPath.Data memory swapPath,
        uint256 assetAmount
    )
        internal
        returns (uint256)
    {
        // load assets array
        address[] memory assets = swapPath.assets;

        // load dex swap strategy ids array
        uint128[] memory dexSwapStrategyIds = swapPath.dexSwapStrategyIds;

        // declare amountIn as initial token amountIn
        uint256 amountIn = assetAmount;

        for (uint256 i; i < assets.length - 1; i++) {
            // loads the dex swap strategy data storage pointer
            DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.loadExisting(dexSwapStrategyIds[i]);

            // approve the collateral token to the dex adapter
            IERC20(assets[i]).approve(dexSwapStrategy.dexAdapter, amountIn);

            // prepare the data for executing the swap
            SwapExactInputSinglePayload memory swapCallData = SwapExactInputSinglePayload({
                tokenIn: assets[i],
                tokenOut: assets[i + 1],
                amountIn: amountIn,
                recipient: address(this)
            });

            // Swap collected collateral fee amount for the next asset and store the obtained amount
            amountIn = dexSwapStrategy.executeSwapExactInputSingle(swapCallData);
        }

        // return the last swap amount out
        return amountIn;
    }

    /// @notice Returns the raw available weth rewards for a given market id
    /// @param marketId The live market id
    /// @return availableProtocolWethReward market available protocol rewards
    /// @return wethRewardPerVaultShare market avaiable staking rewards
    function getWethRewardDataRaw(uint128 marketId)
        external
        view
        returns (uint128 availableProtocolWethReward, uint128 wethRewardPerVaultShare)
    {
        Market.Data storage market = Market.loadExisting(marketId);

        (availableProtocolWethReward, wethRewardPerVaultShare) =
            (market.availableProtocolWethReward, market.wethRewardPerVaultShare);
    }
}
