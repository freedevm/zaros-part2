// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IUniswapV2Router02 } from "@zaros/utils/interfaces/IUniswapV2Router02.sol";
import { Path } from "@zaros/utils/libraries/Path.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @title mock Uniswap V3 Swap Strategy Router
/// @notice Router for stateless execution of swaps against Uniswap V3
contract MockUniswapV2SwapStrategyRouter is IUniswapV2Router02 {
    function factory() external pure override returns (address) { }

    function WETH() external pure override returns (address) { }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        override
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    { }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        override
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    { }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        override
        returns (uint256 amountA, uint256 amountB)
    { }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        override
        returns (uint256 amountToken, uint256 amountETH)
    { }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        override
        returns (uint256 amountA, uint256 amountB)
    { }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        override
        returns (uint256 amountToken, uint256 amountETH)
    { }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /**/
    )
        external
        override
        returns (uint256[] memory amounts)
    {
        uint256 pathLength = path.length;

        require(pathLength >= 2, "Invalid path length");

        amounts = new uint256[](pathLength);

        amounts[pathLength - 1] = amountOutMin;

        address tokenIn = path[0];
        address tokenOut = path[pathLength - 1];

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(to, amountOutMin);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        override
        returns (uint256[] memory amounts)
    { }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        override
        returns (uint256[] memory amounts)
    { }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        override
        returns (uint256[] memory amounts)
    { }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        override
        returns (uint256[] memory amounts)
    { }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        override
        returns (uint256[] memory amounts)
    { }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    )
        external
        pure
        override
        returns (uint256 amountB)
    { }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        override
        returns (uint256 amountOut)
    { }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        override
        returns (uint256 amountIn)
    { }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    )
        external
        view
        override
        returns (uint256[] memory amounts)
    { }

    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    )
        external
        view
        override
        returns (uint256[] memory amounts)
    { }

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        override
        returns (uint256 amountETH)
    { }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        override
        returns (uint256 amountETH)
    { }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        override
    { }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        override
    { }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        override
    { }
}
