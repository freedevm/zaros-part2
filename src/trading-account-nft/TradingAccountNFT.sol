// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

// Open Zeppelin dependencies
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title TradingAccountNFT
/// @notice ERC721 token representing a trading account.
contract TradingAccountNFT is ERC721EnumerableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeCast for uint256;

    /// @dev Disables initialize functions at the implementation.
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract.
    /// @param _owner The owner of the contract.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    function initialize(address _owner, string memory _name, string memory _symbol) external initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_owner);
    }

    /// @notice Mints a new token.
    /// @param to The address to mint the token to.
    /// @param tokenId The token ID to mint.
    function mint(address to, uint256 tokenId) external onlyOwner {
        // intentionally not using _safeMint
        _mint(to, tokenId);
    }

    /// @notice Change owner of the TradingAccountNFT.
    /// @param to The address to transfer the token to.
    /// @param tokenId The token ID to transfer.
    /// @param auth The address that is allowed to transfer the token.
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);
        IPerpsEngine(owner()).notifyAccountTransfer(to, tokenId.toUint128());

        return previousOwner;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }
}
