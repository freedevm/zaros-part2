// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

/// @dev Zaros USD Tokens MUST always implement 18 decimals, in order to not break system-wide invariants.
contract UsdToken is ERC20Permit, Ownable {
    constructor(
        address owner,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(owner)
    { }

    function mint(address to, uint256 amount) external onlyOwner {
        _requireAmountNotZero(amount);
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _requireAmountNotZero(amount);
        _burn(msg.sender, amount);
    }

    function _requireAmountNotZero(uint256 amount) private pure {
        if (amount == 0) {
            revert Errors.ZeroInput("amount");
        }
    }
}
