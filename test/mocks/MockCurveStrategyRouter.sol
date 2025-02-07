// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { ICurveSwapRouter } from "@zaros/utils/interfaces/ICurveSwapRouter.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @title mock Curve Strategy Router
/// @notice Router for stateless execution of swaps against Curve Finance
contract MockCurveStrategyRouter is ICurveSwapRouter {
    /// @inheritdoc ICurveSwapRouter
    function exchange_with_best_rate(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _expected,
        address _receiver
    )
        external
        payable
        returns (uint256 amountOut)
    {
        IERC20(_from).transferFrom(msg.sender, address(this), _amount);
        IERC20(_to).transfer(_receiver, _expected);

        amountOut = _expected;
    }
}
