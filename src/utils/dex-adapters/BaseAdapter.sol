// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IPriceAdapter } from "@zaros/utils/interfaces/IPriceAdapter.sol";
import { ISwapAssetConfig } from "@zaros/utils/interfaces/ISwapAssetConfig.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Open zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Swap asset configuration
/// @param decimals The asset decimals
/// @param priceAdapter The asset price adapter
struct SwapAssetConfigData {
    uint8 decimals;
    address priceAdapter;
}

abstract contract BaseAdapter is UUPSUpgradeable, OwnableUpgradeable, ISwapAssetConfig, IDexAdapter {
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when the deadline is set
    /// @param deadline The new deadline
    event LogSetDeadline(uint256 deadline);

    /// @notice Event emitted when the new swap asset config data is set
    /// @param asset The asset address
    /// @param decimals The asset decimals
    /// @param priceAdapter The asset price adapter
    event LogSetSwapAssetConfig(address indexed asset, uint8 decimals, address priceAdapter);

    /// @notice Event emitted when the slippage tolerance is set
    /// @param newSlippageTolerance The new slippage tolerance
    event LogSetSlippageTolerance(uint256 newSlippageTolerance);

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The asset data
    mapping(address asset => SwapAssetConfigData data) public swapAssetConfigData;

    /// @notice the slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    uint256 public slippageToleranceBps;

    /// @notice The deadline
    uint256 deadline;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function __BaseAdapter_init(address owner, uint256 _slippageToleranceBps) public initializer {
        // initialize the owner
        __Ownable_init(owner);

        // set the slippage tolerance
        setSlippageTolerance(_slippageToleranceBps);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets the swap asset config data
    /// @dev The asset config data is used to calculate the expected output amount
    /// @dev Only the owner can set the asset config data
    /// @param asset The asset address
    /// @param decimals The asset decimals
    /// @param priceAdapter The asset price adapter
    function setSwapAssetConfig(address asset, uint8 decimals, address priceAdapter) public onlyOwner {
        // set the swap asset config data
        swapAssetConfigData[asset] = SwapAssetConfigData(decimals, priceAdapter);

        // emit the event
        emit LogSetSwapAssetConfig(asset, decimals, priceAdapter);
    }

    /// @notice Get the expected output amount
    /// @param tokenIn The token in address
    /// @param tokenOut The token out address
    /// @param amountIn The input amount in native precision of tokenIn
    /// @return expectedAmountOut The expected amount out in native precision of tokenOut
    function getExpectedOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        public
        view
        returns (uint256 expectedAmountOut)
    {
        // fail fast for zero input
        if (amountIn == 0) revert Errors.ZeroExpectedSwapOutput();

        // get token prices
        UD60x18 priceTokenInX18 = IPriceAdapter(swapAssetConfigData[tokenIn].priceAdapter).getPrice();
        UD60x18 priceTokenOutX18 = IPriceAdapter(swapAssetConfigData[tokenOut].priceAdapter).getPrice();

        // convert input amount from native to internal zaros precision
        UD60x18 amountInX18 = Math.convertTokenAmountToUd60x18(swapAssetConfigData[tokenIn].decimals, amountIn);

        // calculate the expected amount out in native precision of output token
        expectedAmountOut = Math.convertUd60x18ToTokenAmount(
            swapAssetConfigData[tokenOut].decimals, amountInX18.mul(priceTokenInX18).div(priceTokenOutX18)
        );

        // revert when calculated expected output is zero; must revert here
        // otherwise the subsequent slippage bps calculation will also
        // return a minimum swap output of zero giving away the input tokens
        if (expectedAmountOut == 0) revert Errors.ZeroExpectedSwapOutput();
    }

    /// @notice Calculate the amount out min
    /// @param amountOutMinExpected The amount out min expected
    /// @return amountOutMin The amount out min
    function calculateAmountOutMin(uint256 amountOutMinExpected) public view returns (uint256 amountOutMin) {
        // calculate the amount out min
        amountOutMin =
            (amountOutMinExpected * (Constants.BPS_DENOMINATOR - slippageToleranceBps)) / Constants.BPS_DENOMINATOR;
    }

    /// @notice Sets slippage tolerance
    function setSlippageTolerance(uint256 newSlippageTolerance) public onlyOwner {
        // enforce min/max slippage tolerance
        if (newSlippageTolerance < Constants.MIN_SLIPPAGE_BPS) {
            revert Errors.MinSlippageTolerance(newSlippageTolerance, Constants.MIN_SLIPPAGE_BPS);
        }
        if (newSlippageTolerance > Constants.MAX_SLIPPAGE_BPS) {
            revert Errors.MaxSlippageTolerance(newSlippageTolerance, Constants.MAX_SLIPPAGE_BPS);
        }

        // update storage
        slippageToleranceBps = newSlippageTolerance;

        // emit the event LogSetSlippageTolerance
        emit LogSetSlippageTolerance(newSlippageTolerance);
    }

    /// @notice Sets deadline
    /// @param _deadline The new deadline
    function setDeadline(uint256 _deadline) public onlyOwner {
        // revert if the deadline is in the past
        if (_deadline < block.timestamp) revert Errors.SwapDeadlineInThePast();

        // set the new deadline
        deadline = _deadline;

        // emit the event
        emit LogSetDeadline(_deadline);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    UPGRADEABLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Upgrades the contract
    /// @dev This function is called by the proxy when the contract is upgraded
    /// @dev Only the owner can upgrade the contract
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
