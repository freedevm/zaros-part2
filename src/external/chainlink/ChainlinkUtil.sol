// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IOffchainAggregator } from "@zaros/external/chainlink/interfaces/IOffchainAggregator.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library ChainlinkUtil {
    using SafeCast for int256;

    /// @param priceFeed The Chainlink Price Feed address.
    /// @param priceFeedHeartbeatSeconds The number of seconds between price feed updates.
    /// @param sequencerUptimeFeed The Chainlink Price Feed address.
    struct GetPriceParams {
        IAggregatorV3 priceFeed;
        uint32 priceFeedHeartbeatSeconds;
        IAggregatorV3 sequencerUptimeFeed;
    }

    /// @notice Queries the provided Chainlink Price Feed for the margin collateral oracle price.
    /// @param params The GetPriceParams struct.
    /// @return price in zaros internal precision
    function getPrice(GetPriceParams memory params) internal view returns (UD60x18 price) {
        uint8 priceDecimals = params.priceFeed.decimals();

        // should revert if priceDecimals > 18
        if (priceDecimals > Constants.SYSTEM_DECIMALS) {
            revert Errors.InvalidOracleReturn();
        }

        if (address(params.sequencerUptimeFeed) != address(0)) {
            try params.sequencerUptimeFeed.latestRoundData() returns (
                uint80, int256 answer, uint256 startedAt, uint256, uint80
            ) {
                bool isSequencerUp = answer == 0;
                if (!isSequencerUp) {
                    revert Errors.OracleSequencerUptimeFeedIsDown(address(params.sequencerUptimeFeed));
                }

                if (startedAt == 0) {
                    revert Errors.OracleSequencerUptimeFeedNotStarted(address(params.sequencerUptimeFeed));
                }

                uint256 timeSinceUp = block.timestamp - startedAt;
                if (timeSinceUp <= Constants.SEQUENCER_GRACE_PERIOD_TIME) {
                    revert Errors.GracePeriodNotOver(address(params.sequencerUptimeFeed));
                }
            } catch {
                revert Errors.InvalidSequencerUptimeFeedReturn(address(params.sequencerUptimeFeed));
            }
        }

        try params.priceFeed.latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
            if (block.timestamp - updatedAt > params.priceFeedHeartbeatSeconds) {
                revert Errors.OraclePriceFeedHeartbeat(address(params.priceFeed));
            }

            IOffchainAggregator aggregator = IOffchainAggregator(params.priceFeed.aggregator());
            int192 minAnswer = aggregator.minAnswer();
            int192 maxAnswer = aggregator.maxAnswer();

            if (answer <= minAnswer || answer >= maxAnswer) {
                revert Errors.OraclePriceFeedOutOfRange(address(params.priceFeed));
            }

            price = ud60x18(answer.toUint256() * 10 ** (Constants.SYSTEM_DECIMALS - priceDecimals));
        } catch {
            revert Errors.InvalidOracleReturn();
        }
    }

    /// @notice Decodes the signedReport object and returns the report data only.
    function getReportData(bytes memory signedReport) internal pure returns (bytes memory reportData) {
        (, reportData) = abi.decode(signedReport, (bytes32[3], bytes));
    }

    function getEthVericationFee(
        IVerifierProxy chainlinkVerifier,
        bytes memory reportData
    )
        internal
        returns (FeeAsset memory fee)
    {
        IFeeManager chainlinkFeeManager = chainlinkVerifier.s_feeManager();
        address feeTokenAddress = chainlinkFeeManager.i_nativeAddress();
        (fee,,) = chainlinkFeeManager.getFeeAndReward(address(this), reportData, feeTokenAddress);
    }

    function verifyReport(
        IVerifierProxy chainlinkVerifier,
        FeeAsset memory fee,
        bytes memory signedReport
    )
        internal
        returns (bytes memory verifiedReportData)
    {
        verifiedReportData = chainlinkVerifier.verify{ value: fee.amount }(signedReport, abi.encode(fee.assetAddress));
    }
}
