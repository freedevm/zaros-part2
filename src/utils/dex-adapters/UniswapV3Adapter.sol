// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { IUniswapV3RouterInterface } from "@zaros/utils/interfaces/IUniswapV3RouterInterface.sol";
import { BaseAdapter } from "@zaros/utils/dex-adapters/BaseAdapter.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @notice Uniswap V3 adapter contract
contract UniswapV3Adapter is BaseAdapter {
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when the pool fee is set
    /// @param newFee The new pool fee
    event LogSetPoolFee(uint24 newFee);

    /// @notice Event emitted when the Uniswap V3 Swap Strategy Router is set
    /// @param uniswapV3SwapStrategyRouter The Uniswap V3 Swap Strategy Router address
    event LogSetUniswapV3SwapStrategyRouter(address indexed uniswapV3SwapStrategyRouter);

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy Router address
    address public uniswapV3SwapStrategyRouter;

    /// @notice The pool fee
    /// @dev 500 bps (0.05%) for stable pairs with low volatility.
    /// @dev 3000 bps (0.30%) for most pairs with moderate volatility.
    /// @dev 10000 bps (1.00%) for highly volatile pairs.
    uint24 public feeBps;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy ID
    uint128 public constant STRATEGY_ID = 1;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        address _uniswapV3SwapStrategyRouter,
        uint256 _slippageToleranceBps,
        uint24 _fee
    )
        external
        initializer
    {
        // initialize the owner
        __BaseAdapter_init(owner, _slippageToleranceBps);

        // set the Uniswap V3 Swap Strategy Router
        setUniswapV3SwapStrategyRouter(_uniswapV3SwapStrategyRouter);

        // set the pool fee
        setPoolFee(_fee);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// inheritdoc IDexAdapter
    function executeSwapExactInputSingle(SwapExactInputSinglePayload calldata swapPayload)
        external
        returns (uint256 amountOut)
    {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // cache uniswap v3 swap strategy router
        IUniswapV3RouterInterface swapRouter = IUniswapV3RouterInterface(uniswapV3SwapStrategyRouter);

        // approve the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(address(swapRouter), swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = getExpectedOutput(swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn);

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMin = calculateAmountOutMin(expectedAmountOut);

        return swapRouter.exactInputSingle(
            IUniswapV3RouterInterface.ExactInputSingleParams({
                tokenIn: swapPayload.tokenIn,
                tokenOut: swapPayload.tokenOut,
                fee: feeBps,
                recipient: swapPayload.recipient,
                deadline: deadline,
                amountIn: swapPayload.amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /// inheritdoc IDexAdapter
    function executeSwapExactInput(SwapExactInputPayload calldata swapPayload) external returns (uint256 amountOut) {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // cache uniswap v3 swap strategy router
        IUniswapV3RouterInterface swapRouter = IUniswapV3RouterInterface(uniswapV3SwapStrategyRouter);

        // approve the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(address(swapRouter), swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = getExpectedOutput(swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn);

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum =
            (expectedAmountOut * (Constants.BPS_DENOMINATOR - slippageToleranceBps)) / Constants.BPS_DENOMINATOR;

        return swapRouter.exactInput(
            IUniswapV3RouterInterface.ExactInputParams({
                path: swapPayload.path,
                recipient: swapPayload.recipient,
                deadline: deadline,
                amountIn: swapPayload.amountIn,
                amountOutMinimum: amountOutMinimum
            })
        );
    }

    /// @notice Sets pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(uint24 newFee) public onlyOwner {
        // revert if the new fee is not 500, 3000 or 10_000
        if (newFee != 500 && newFee != 3000 && newFee != 10_000) revert Errors.InvalidPoolFee();

        // set the new fee
        feeBps = newFee;

        // emit the event
        emit LogSetPoolFee(newFee);
    }

    /// @notice Sets the Uniswap V3 Swap Strategy Router
    /// @dev Only the owner can set the Uniswap V3 Swap Strategy Router
    /// @param _uniswapV3SwapStrategyRouter The Uniswap V3 Swap Strategy Router address
    function setUniswapV3SwapStrategyRouter(address _uniswapV3SwapStrategyRouter) public onlyOwner {
        if (_uniswapV3SwapStrategyRouter == address(0)) revert Errors.ZeroInput("_uniswapV3SwapStrategyRouter");

        // set the uniswap v3 swap strategy router
        uniswapV3SwapStrategyRouter = _uniswapV3SwapStrategyRouter;

        // emit the event
        emit LogSetUniswapV3SwapStrategyRouter(_uniswapV3SwapStrategyRouter);
    }
}
