// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { UsdToken } from "@zaros/usd/UsdToken.sol";

contract MockUsdToken is UsdToken {
    constructor(
        address owner,
        uint256 deployerBalance,
        string memory _name,
        string memory _symbol
    )
        UsdToken(owner, _name, _symbol)
    {
        _mint(owner, deployerBalance);
    }

    function mockMint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
