// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

/// @title Zaros Liquidity Provisioning (ZLP) Vault contract
/// @notice The ZlpVault contract is a UUPS upgradeable contract that extends the ERC4626 standard.
/// @dev It is deployed as a standalone proxy, separately from the `MarketMakingEngine`, and its core responsibility
/// is to store and manage the assets and shares of a single ZLP Vault.
/// @author 0xpedro.eth
/// @author 0xjoaovpsantos
/// @author yotov721
contract ZlpVault is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC4626Upgradeable {
    using Math for uint256;

    /// @custom:storage-location erc7201:openzeppelin.storage.ZlpVault
    struct ZlpVaultStorage {
        address marketMakingEngine;
        uint8 decimalsOffset;
        uint128 vaultId;
    }

    /// @notice ERC-7201 namespace storage location.
    bytes32 private constant ZLP_VAULT_STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ZlpVault")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Modifier to restrict access to the MarketMakingEngine root proxy contract.
    modifier onlyMarketMakingEngine() {
        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();

        if (msg.sender != zlpVaultStorage.marketMakingEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @dev Disables initialize functions at the implementation.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the ZlpVault UUPS contract.
    /// @dev See {UUPSUpgradeable}.
    function initialize(
        address marketMakingEngine,
        uint8 decimalsOffset,
        address owner,
        IERC20 asset_,
        uint128 vaultId
    )
        external
        initializer
    {
        __Ownable_init(owner);
        __ERC4626_init(asset_);

        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();
        zlpVaultStorage.marketMakingEngine = marketMakingEngine;
        zlpVaultStorage.decimalsOffset = decimalsOffset;
        zlpVaultStorage.vaultId = vaultId;

        IERC20(asset_).approve(marketMakingEngine, type(uint256).max);
    }

    /// @notice ERC7201 storage access function.
    function _getZlpVaultStorage() private pure returns (ZlpVaultStorage storage zlpVaultStorage) {
        bytes32 slot = ZLP_VAULT_STORAGE_LOCATION;
        assembly {
            zlpVaultStorage.slot := slot
        }
    }

    /// @notice Returns the maximum amount of assets that can be deposited into the ZLP Vault, taking into account the
    /// configured deposit cap.
    /// @dev Overridden and used in ERC4626.
    /// @return maxAssets The maximum amount of depositable assets.
    function maxDeposit(address) public view override returns (uint256 maxAssets) {
        // load the zlp vault storage pointer
        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();
        // cache the market making engine contract
        IMarketMakingEngine marketMakingEngine = IMarketMakingEngine(zlpVaultStorage.marketMakingEngine);

        // get the vault's deposit cap
        uint128 depositCap = marketMakingEngine.getDepositCap(zlpVaultStorage.vaultId);

        // cache the vault's total assets
        uint256 totalAssetsCached = totalAssets();

        // underflow check here would be redundant
        unchecked {
            // we need to ensure that depositCap > totalAssets, otherwise, a malicious actor could grief deposits by
            // sending assets directly to the vault contract and bypassing the deposit cap
            maxAssets = depositCap > totalAssetsCached ? depositCap - totalAssetsCached : 0;
        }
    }

    /// @dev The Market Making Engine does not call `ERC4626::mint`, thus, the max mint is always 0.
    function maxMint(address) public pure override returns (uint256) {
        return 0;
    }

    /// @dev The Market Making Engine does not call `ERC4626::withdraw`, thus, the max mint is always 0.
    function maxWithdraw(address) public pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc ERC4626Upgradeable
    function deposit(uint256 assets, address receiver) public override onlyMarketMakingEngine returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @inheritdoc ERC4626Upgradeable
    function mint(uint256 shares, address receiver) public override onlyMarketMakingEngine returns (uint256) {
        return super.mint(shares, receiver);
    }

    /// @inheritdoc ERC4626Upgradeable
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override
        onlyMarketMakingEngine
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @inheritdoc ERC4626Upgradeable
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override
        onlyMarketMakingEngine
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    /// @notice Returns the decimals offset between the ZLP Vault's underlying asset and its shares (index tokens).
    /// @dev Overridden and used in ERC4626.
    function _decimalsOffset() internal view override returns (uint8 offset) {
        offset = _getZlpVaultStorage().decimalsOffset;
    }

    /// @notice Converts the provided amount of ZLP Vault shares to the equivalent amount of underlying assets.
    /// @dev Overridden and used in ERC4626.
    /// @dev This function takes into account the ZLP Vault's unsettled debt in usd to return the correct expected
    /// amount of assets out for the given amount of shares in.
    /// @param shares The amount of ZLP Vault shares to convert.
    /// @return The equivalent amount of underlying assets for the given shares in parameter.
    function _convertToAssets(uint256 shares, Math.Rounding /**/ ) internal view override returns (uint256) {
        // load erc-7201 storage pointer
        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();

        // fetch the amount of assets out for the shares input value calling the `MarketMakingEngine`
        UD60x18 assetsOut = IMarketMakingEngine(zlpVaultStorage.marketMakingEngine).getIndexTokenSwapRate(
            zlpVaultStorage.vaultId, shares, false
        );

        return assetsOut.intoUint256();
    }

    /// @notice Converts the provided amount of the ZLP Vault's assets to the equivalent amount of shares.
    /// @dev Overridden and used in ERC4626.
    /// @dev This function takes into account the ZLP Vault's unsettled debt in usd to return the correct expected
    /// amount of shares out for the given amount of assets in.
    /// @param assets The amount of ZLP Vault assets to convert.
    /// @return The equivalent amount of ERC4626 shares for the given assets in parameter.
    function _convertToShares(
        uint256 assets,
        Math.Rounding
    )
        /*
        */
        internal
        view
        override
        returns (uint256)
    {
        // load erc-7201 storage pointer
        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();

        // fetch the amount of shares out for the assets input value calling the `MarketMakingEngine`
        UD60x18 sharesOut = IMarketMakingEngine(zlpVaultStorage.marketMakingEngine).getVaultAssetSwapRate(
            zlpVaultStorage.vaultId, assets, false
        );

        return sharesOut.intoUint256();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }

    function updateAssetAllowance(uint256 amount) external onlyMarketMakingEngine {
        // modifier `onlyMarketMakingEngine` ensures caller is market making engine
        // so pass `msg.sender` directly to `approve` saving 1 storage read
        IERC20(asset()).approve(msg.sender, amount);
    }
}
