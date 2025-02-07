// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { BaseKeeper } from "../BaseKeeper.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";

contract UsdTokenSwapKeeper is ILogAutomation, IStreamsLookupCompatible, BaseKeeper {
    /// @notice ERC7201 storage location.
    bytes32 internal constant USDZ_SWAP_KEEPER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.keepers.UsdTokenSwapKeeper")) - 1)
    ) & ~bytes32(uint256(0xff));

    string public constant DATA_STREAMS_FEED_LABEL = "feedIDs";
    string public constant DATA_STREAMS_QUERY_LABEL = "timestamp";

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.UsdTokenSwapKeeper
    /// @param marketMakingEngine The address of the MarketMakingEngine contract.
    /// @param streamId The Chainlink Data Streams stream id.
    struct UsdTokenSwapKeeperStorage {
        IMarketMakingEngine marketMakingEngine;
        address asset;
        string streamId;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {UsdTokenSwapKeeper} UUPS initializer.
    function initialize(
        address owner,
        address marketMakingEngine,
        address asset,
        string calldata streamId
    )
        external
        initializer
    {
        __BaseKeeper_init(owner);

        if (address(marketMakingEngine) == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        if (asset == address(0)) {
            revert Errors.ZeroInput("asset");
        }

        if (bytes(streamId).length == 0) {
            revert Errors.ZeroInput("streamId");
        }

        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();

        self.marketMakingEngine = IMarketMakingEngine(marketMakingEngine);
        self.streamId = streamId;
        self.asset = asset;
    }

    function getConfig()
        external
        view
        returns (address keeperOwner, address marketMakingEngine, string memory streamId, address asset)
    {
        UsdTokenSwapKeeperStorage memory self = _getUsdTokenSwapKeeperStorage();

        keeperOwner = owner();
        marketMakingEngine = address(self.marketMakingEngine);
        streamId = self.streamId;
        asset = self.asset;
    }

    /// @inheritdoc ILogAutomation
    function checkLog(
        AutomationLog calldata log,
        bytes memory
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // https://docs.chain.link/chainlink-automation/guides/log-trigger
        // 0th index is the event signature hash
        address caller = bytes32ToAddress(log.topics[1]);
        uint128 requestId = uint128(uint256(log.topics[2]));

        // load usd token swap storage
        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();

        // load requiest for user by id
        UsdTokenSwapConfig.SwapRequest memory request =
            IMarketMakingEngine(self.marketMakingEngine).getSwapRequest(caller, requestId);

        // if request dealine expired revert
        if (request.deadline < block.timestamp) {
            return (false, new bytes(0));
        }

        // if keeper asset stream != vault asset revert
        // Since the event emitted would be catched by multiple keepers, each with a stream for different asset, only
        // the one with the matching asset needs to be able to execute the swap
        if (request.assetOut != self.asset) {
            return (false, new bytes(0));
        }

        string[] memory streams = new string[](1);
        streams[0] = self.streamId;

        // encode perform data
        bytes memory extraData = abi.encode(caller, requestId);

        revert StreamsLookup(DATA_STREAMS_FEED_LABEL, streams, DATA_STREAMS_QUERY_LABEL, block.timestamp, extraData);
    }

    /// @inheritdoc ILogAutomation
    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        (bytes memory signedReport, bytes memory extraData) = abi.decode(performData, (bytes, bytes));
        (address user, uint128 requestId) = abi.decode(extraData, (address, uint128));

        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();

        self.marketMakingEngine.fulfillSwap(user, requestId, signedReport, address(self.marketMakingEngine));
    }

    /// @inheritdoc IStreamsLookupCompatible
    function checkCallback(
        bytes[] calldata values,
        bytes calldata extraData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bytes memory signedReport = values[0];

        upkeepNeeded = true;
        performData = abi.encode(signedReport, extraData);
    }

    function updateConfig(address marketMakingEngine, address asset, string calldata streamId) external onlyOwner {
        if (marketMakingEngine == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        if (asset == address(0)) {
            revert Errors.ZeroInput("asset");
        }

        if (bytes(streamId).length == 0) {
            revert Errors.ZeroInput("streamId");
        }

        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();

        self.marketMakingEngine = IMarketMakingEngine(marketMakingEngine);
        self.streamId = streamId;
        self.asset = asset;
    }

    function _getUsdTokenSwapKeeperStorage() internal pure returns (UsdTokenSwapKeeperStorage storage self) {
        bytes32 slot = USDZ_SWAP_KEEPER_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function bytes32ToAddress(bytes32 _address) public pure returns (address) {
        return address(uint160(uint256(_address)));
    }
}
