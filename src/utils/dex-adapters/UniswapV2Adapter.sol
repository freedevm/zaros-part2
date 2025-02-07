// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { IUniswapV2Router02 } from "@zaros/utils/interfaces/IUniswapV2Router02.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { BaseAdapter } from "@zaros/utils/dex-adapters/BaseAdapter.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Path } from "@zaros/utils/libraries/Path.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

/// @notice Uniswap V2 adapter contract
contract UniswapV2Adapter is BaseAdapter {
    using Path for bytes;

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when the pool fee is set
    /// @param newFee The new pool fee
    event LogSetPoolFee(uint24 newFee);

    /// @notice Event emitted when the Uniswap V2 Swap Strategy Router is set
    /// @param uniswapV2SwapStrategyRouter The Uniswap V2 Swap Strategy Router address
    event LogSetUniswapV2SwapStrategyRouter(address indexed uniswapV2SwapStrategyRouter);

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V2 Swap Strategy Router address
    address public uniswapV2SwapStrategyRouter;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V2 Swap Strategy ID
    uint128 public constant STRATEGY_ID = 2;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        address _uniswapV2SwapStrategyRouter,
        uint256 _slippageToleranceBps
    )
        external
        initializer
    {
        // initialize the owner
        __BaseAdapter_init(owner, _slippageToleranceBps);

        // set the Uniswap V2 Swap Strategy Router
        setUniswapV2SwapStrategyRouter(_uniswapV2SwapStrategyRouter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IDexAdapter
    function executeSwapExactInputSingle(SwapExactInputSinglePayload calldata swapPayload)
        external
        returns (uint256 amountOut)
    {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // aprove the tokenIn to the swap router
        address uniswapV2SwapStrategyRouterCache = uniswapV2SwapStrategyRouter;
        IERC20(swapPayload.tokenIn).approve(uniswapV2SwapStrategyRouterCache, swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = getExpectedOutput(swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn);

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum = calculateAmountOutMin(expectedAmountOut);

        address[] memory path = new address[](2);
        path[0] = swapPayload.tokenIn;
        path[1] = swapPayload.tokenOut;

        uint256[] memory amountsOut = IUniswapV2Router02(uniswapV2SwapStrategyRouterCache).swapExactTokensForTokens({
            amountIn: swapPayload.amountIn,
            amountOutMin: amountOutMinimum,
            path: path,
            to: swapPayload.recipient,
            deadline: deadline
        });

        return amountsOut[1];
    }

    /// @inheritdoc IDexAdapter
    function executeSwapExactInput(SwapExactInputPayload calldata swapPayload) external returns (uint256 amountOut) {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // aprove the tokenIn to the swap router
        address uniswapV2SwapStrategyRouterCache = uniswapV2SwapStrategyRouter;
        IERC20(swapPayload.tokenIn).approve(uniswapV2SwapStrategyRouterCache, swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = getExpectedOutput(swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn);

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum = calculateAmountOutMin(expectedAmountOut);

        // decode path as it is Uniswap V3 specific
        (address[] memory tokens,) = swapPayload.path.decodePath();

        // execute trade
        uint256[] memory amountsOut = IUniswapV2Router02(uniswapV2SwapStrategyRouterCache).swapExactTokensForTokens({
            amountIn: swapPayload.amountIn,
            amountOutMin: amountOutMinimum,
            path: tokens,
            to: swapPayload.recipient,
            deadline: deadline
        });

        // return the amount out of the last trade
        return amountsOut[tokens.length - 1];
    }

    /// @notice Sets the Uniswap V2 Swap Strategy Router
    /// @dev Only the owner can set the Uniswap V2 Swap Strategy Router
    /// @param _uniswapV2SwapStrategyRouter The Uniswap V2 Swap Strategy Router address
    function setUniswapV2SwapStrategyRouter(address _uniswapV2SwapStrategyRouter) public onlyOwner {
        if (_uniswapV2SwapStrategyRouter == address(0)) revert Errors.ZeroInput("_uniswapV2SwapStrategyRouter");

        // set the uniswap v2 swap strategy router
        uniswapV2SwapStrategyRouter = _uniswapV2SwapStrategyRouter;

        // emit the event
        emit LogSetUniswapV2SwapStrategyRouter(_uniswapV2SwapStrategyRouter);
    }
}
