// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { IAutomationCompatible } from "@zaros/external/chainlink/interfaces/IAutomationCompatible.sol";
import { BaseKeeper } from "../BaseKeeper.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

contract FeeConversionKeeper is IAutomationCompatible, BaseKeeper {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_CONVERSION_KEEPER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.keepers.FeeConversionKeeper")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.FeeConversionKeeper
    /// @param marketMakingEngine The address of the MarketMakingEngine contract.
    struct FeeConversionKeeperStorage {
        IMarketMakingEngine marketMakingEngine;
        uint128 dexSwapStrategyId;
        uint128 minFeeDistributionValueUsd;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {LiquidationKeeper} UUPS initializer.
    function initialize(
        address owner,
        IMarketMakingEngine marketMakingEngine,
        uint128 dexSwapStrategyId,
        uint128 minFeeDistributionValueUsd
    )
        external
        initializer
    {
        __BaseKeeper_init(owner);

        if (address(marketMakingEngine) == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        DexSwapStrategy.Data memory dexSwapStrategy =
            IMarketMakingEngine(marketMakingEngine).getDexSwapStrategy(dexSwapStrategyId);

        // reverts if the dex swap strategy has an invalid dex adapter
        if (dexSwapStrategy.dexAdapter == address(0)) {
            revert Errors.DexSwapStrategyHasAnInvalidDexAdapter(dexSwapStrategyId);
        }

        if (minFeeDistributionValueUsd == 0) {
            revert Errors.ZeroInput("minFeeDistributionValueUsd");
        }

        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        self.marketMakingEngine = marketMakingEngine;
        self.dexSwapStrategyId = dexSwapStrategyId;
        self.minFeeDistributionValueUsd = minFeeDistributionValueUsd;
    }

    function checkUpkeep(bytes calldata /**/ ) external view returns (bool upkeepNeeded, bytes memory performData) {
        FeeConversionKeeperStorage memory self = _getFeeConversionKeeperStorage();

        uint128[] memory liveMarketIds = self.marketMakingEngine.getLiveMarketIds();

        bool distributionNeeded;
        uint128[] memory marketIds = new uint128[](liveMarketIds.length * 10);
        address[] memory assets = new address[](liveMarketIds.length * 10);
        uint256 index = 0;
        uint128 marketId;

        // Iterate over markets by id
        for (uint128 i; i < liveMarketIds.length; i++) {
            marketId = liveMarketIds[i];

            (address[] memory marketAssets, uint256[] memory feesCollected) =
                self.marketMakingEngine.getReceivedMarketFees(marketId);

            // Iterate over receivedMarketFees
            for (uint128 j; j < marketAssets.length; j++) {
                distributionNeeded = checkFeeDistributionNeeded(marketAssets[j], feesCollected[j]);

                if (distributionNeeded) {
                    // set upkeepNeeded = true
                    upkeepNeeded = true;

                    // set marketId, asset
                    marketIds[index] = marketId;
                    assets[index] = marketAssets[j];

                    index++;
                }
            }
        }

        if (upkeepNeeded) {
            performData = abi.encode(marketIds, assets);
        }
    }

    // call FeeDistributionBranch::convertAccumulatedFeesToWeth
    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        FeeConversionKeeperStorage memory self = _getFeeConversionKeeperStorage();

        IMarketMakingEngine marketMakingEngine = self.marketMakingEngine;

        // decode performData
        (uint128[] memory marketIds, address[] memory assets) = abi.decode(performData, (uint128[], address[]));

        // convert accumulated fees to weth for decoded markets and assets
        for (uint256 i; i < marketIds.length; i++) {
            marketMakingEngine.convertAccumulatedFeesToWeth(marketIds[i], assets[i], self.dexSwapStrategyId, "");
        }
    }

    /// @notice Retrieves the current configuration of the fee conversion keeper.
    /// @return keeperOwner The address of the owner of the fee conversion keeper.
    /// @return marketMakingEngine The address of the market-making engine.
    /// @param minFeeDistributionValueUsd The minimum fee distribution value in USD.
    function getConfig()
        external
        view
        returns (address keeperOwner, address marketMakingEngine, uint128 minFeeDistributionValueUsd)
    {
        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        keeperOwner = owner();
        marketMakingEngine = address(self.marketMakingEngine);
        minFeeDistributionValueUsd = self.minFeeDistributionValueUsd;
    }

    /// @notice Sets the configuration for the fee conversion keeper.
    /// @param marketMakingEngine The address of the market-making engine.
    /// @param minFeeDistributionValueUsd The minimum fee distribution value in USD.
    function updateConfig(address marketMakingEngine, uint128 minFeeDistributionValueUsd) external onlyOwner {
        if (marketMakingEngine == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        if (minFeeDistributionValueUsd == 0) {
            revert Errors.ZeroInput("minFeeDistributionValueUsd");
        }

        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        self.marketMakingEngine = IMarketMakingEngine(marketMakingEngine);
        self.minFeeDistributionValueUsd = minFeeDistributionValueUsd;
    }

    /// @notice Loads the fee conversion keeper storage.
    /// @return self The loaded FeeConversionKeeperStorage pointer.
    function _getFeeConversionKeeperStorage() internal pure returns (FeeConversionKeeperStorage storage self) {
        bytes32 slot = FEE_CONVERSION_KEEPER_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @notice Checks if fee distribution is needed based on the asset and the collected fee amount.
    /// @param asset The address of the asset being evaluated.
    /// @param collectedFee The amount of fee collected for the asset.
    /// @return distributionNeeded A boolean indicating whether fee distribution is required.
    function checkFeeDistributionNeeded(
        address asset,
        uint256 collectedFee
    )
        public
        view
        returns (bool distributionNeeded)
    {
        // load keeper data from storage
        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        /// get asset value in USD
        uint256 assetValue = self.marketMakingEngine.getAssetValue(asset, collectedFee);

        // if asset value GT min distribution value return true
        distributionNeeded = assetValue > self.minFeeDistributionValueUsd;
    }
}
