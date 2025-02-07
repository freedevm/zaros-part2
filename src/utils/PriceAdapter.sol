// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { IPriceAdapter } from "@zaros/utils/interfaces/IPriceAdapter.sol";

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PriceAdapter is IPriceAdapter, OwnableUpgradeable, UUPSUpgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The name of the Price Adapter.
    string public name;

    /// @notice The symbol of the Price Adapter.
    string public symbol;

    /// @notice The Chainlink Price Feed address.
    address public priceFeed;

    /// @notice The Chainlink ETH/USD Price Feed address.
    address public ethUsdPriceFeed;

    /// @notice The Sequencer Uptime Feed address.
    address public sequencerUptimeFeed;

    /// @notice The number of seconds between price feed updates.
    uint32 public priceFeedHeartbeatSeconds;

    /// @notice The number of seconds between ETH/USD price feed updates.
    uint32 public ethUsdPriceFeedHeartbeatSeconds;

    /// @notice A flag indicating if the price adapter is to use the custom version.
    bool public useEthPriceFeed;

    /*//////////////////////////////////////////////////////////////////////////
                                     STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The initialization parameters.
    /// @param name The name of the Price Adapter.
    /// @param symbol The symbol of the Price Adapter.
    /// @param owner The owner of the contract.
    /// @param priceFeed The Chainlink Price Feed address.
    /// @param ethUsdPriceFeed The Chainlink ETH/USD Price Feed address.
    /// @param sequencerUptimeFeed The Sequencer Uptime Feed address.
    /// @param priceFeedHeartbeatSeconds The number of seconds between price feed updates.
    /// @param ethUsdPriceFeedHeartbeatSeconds The number of seconds between ETH/USD price feed updates.
    /// @param useEthPriceFeed A flag indicating if the price adapter is to use the custom version.
    struct InitializeParams {
        string name;
        string symbol;
        address owner;
        address priceFeed;
        address ethUsdPriceFeed;
        address sequencerUptimeFeed;
        uint32 priceFeedHeartbeatSeconds;
        uint32 ethUsdPriceFeedHeartbeatSeconds;
        bool useEthPriceFeed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INITIALIZE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Disables initialize functions at the implementation.
    constructor() {
        _disableInitializers();
    }

    function initialize(InitializeParams calldata params) external initializer {
        __Ownable_init(params.owner);

        name = params.name;
        symbol = params.symbol;
        priceFeed = params.priceFeed;
        ethUsdPriceFeed = params.ethUsdPriceFeed;
        sequencerUptimeFeed = params.sequencerUptimeFeed;
        priceFeedHeartbeatSeconds = params.priceFeedHeartbeatSeconds;
        ethUsdPriceFeedHeartbeatSeconds = params.ethUsdPriceFeedHeartbeatSeconds;
        useEthPriceFeed = params.useEthPriceFeed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the USD price of the configured asset.
    /// @return priceUsdX18 The USD quote of the token in zaros internal precision
    function getPrice() external view returns (UD60x18 priceUsdX18) {
        if (useEthPriceFeed) {
            address sequencerUptimeFeedCache = sequencerUptimeFeed;

            UD60x18 quantityTokenInEth = ChainlinkUtil.getPrice(
                ChainlinkUtil.GetPriceParams({
                    priceFeed: IAggregatorV3(priceFeed),
                    priceFeedHeartbeatSeconds: priceFeedHeartbeatSeconds,
                    sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeedCache)
                })
            );

            UD60x18 ethUsdPrice = ChainlinkUtil.getPrice(
                ChainlinkUtil.GetPriceParams({
                    priceFeed: IAggregatorV3(ethUsdPriceFeed),
                    priceFeedHeartbeatSeconds: ethUsdPriceFeedHeartbeatSeconds,
                    sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeedCache)
                })
            );

            priceUsdX18 = quantityTokenInEth.mul(ethUsdPrice);
        } else {
            priceUsdX18 = ChainlinkUtil.getPrice(
                ChainlinkUtil.GetPriceParams({
                    priceFeed: IAggregatorV3(priceFeed),
                    priceFeedHeartbeatSeconds: priceFeedHeartbeatSeconds,
                    sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeed)
                })
            );
        }
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
