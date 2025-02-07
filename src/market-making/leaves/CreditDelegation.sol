// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

library CreditDelegation {
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant CREDIT_DELEGATION_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.CreditDelegation")) - 1));

    /// @notice Credit delegation storage structure.
    /// @param vaultId The vault providing a share of its credit to the market.
    /// @param marketId The market receiving the delegated credit.
    /// @param weight Used to calculate the delegation's share of the vault's available credit capacity.
    /// @param valueUsd The latest value of the credit delegation in USD.
    /// @param lastVaultDistributedRealizedDebtUsdPerShare The last realized debt per share value distributed to the
    /// vault.
    /// @param lastVaultDistributedUnrealizedDebtUsdPerShare The last unrealized debt per share value distributed to
    /// the vault.
    /// @param lastVaultDistributedUsdcCreditPerShare The last usdc credit per share value distributed to the vault.
    /// @param lastVaultDistributedWethRewardPerShare The last weth reward per share value distributed to the vault.
    struct Data {
        uint128 vaultId;
        uint128 marketId;
        uint128 weight;
        uint128 valueUsd;
        int128 lastVaultDistributedRealizedDebtUsdPerShare;
        int128 lastVaultDistributedUnrealizedDebtUsdPerShare;
        uint128 lastVaultDistributedUsdcCreditPerShare;
        uint128 lastVaultDistributedWethRewardPerShare;
    }

    /// @notice Loads a {CreditDelegation}.
    /// @param vaultId the Vault providing a share of its credit to the market.
    /// @param marketId the perp market receiving the credit.
    /// @return creditDelegation The loaded credit delegation storage pointer.
    function load(uint128 vaultId, uint256 marketId) internal pure returns (Data storage creditDelegation) {
        bytes32 slot = keccak256(abi.encode(CREDIT_DELEGATION_LOCATION, vaultId, marketId));
        assembly {
            creditDelegation.slot := slot
        }
    }

    /// @notice Clears the credit delegation storage.
    /// @dev Called when a vault's credit share is fully undelegated from a market.
    /// @param self The credit delegation storage pointer.
    function clear(Data storage self) internal {
        delete self.vaultId;
        delete self.marketId;
        delete self.weight;
        delete self.valueUsd;
        delete self.lastVaultDistributedRealizedDebtUsdPerShare;
        delete self.lastVaultDistributedUnrealizedDebtUsdPerShare;
        delete self.lastVaultDistributedUsdcCreditPerShare;
        delete self.lastVaultDistributedWethRewardPerShare;
    }

    /// @notice Updates this vault's credit delegation last distributed debt and reward values.
    /// @dev This function must be called whenever a vault accumulates debt and reward distributed by a market, and
    /// this leaf is used to support accounting at the Vault and Market leaves.
    /// @param self The credit delegation storage pointer.
    /// @param vaultDistributedRealizedDebtUsdPerShareX18 The last realized debt per share value distributed to the
    /// vault credit delegation.
    /// @param vaultDistributedUnrealizedDebtUsdPerShareX18 The last unrealized debt per share value distributed to
    /// the vault credit delegation.
    /// @param vaultDistributedUsdcCreditPerShareX18 The last usdc credit per share value distributed to the vault
    /// credit delegation.
    /// @param vaultDistributedWethRewardPerShareX18 The last weth reward per share value distributed to the
    /// vault credit delegation.
    function updateVaultLastDistributedValues(
        Data storage self,
        SD59x18 vaultDistributedRealizedDebtUsdPerShareX18,
        SD59x18 vaultDistributedUnrealizedDebtUsdPerShareX18,
        UD60x18 vaultDistributedUsdcCreditPerShareX18,
        UD60x18 vaultDistributedWethRewardPerShareX18
    )
        internal
    {
        // updates the credit delegation state
        self.lastVaultDistributedRealizedDebtUsdPerShare =
            vaultDistributedRealizedDebtUsdPerShareX18.intoInt256().toInt128();
        self.lastVaultDistributedUnrealizedDebtUsdPerShare =
            vaultDistributedUnrealizedDebtUsdPerShareX18.intoInt256().toInt128();
        self.lastVaultDistributedUsdcCreditPerShare = vaultDistributedUsdcCreditPerShareX18.intoUint128();
        self.lastVaultDistributedWethRewardPerShare = vaultDistributedWethRewardPerShareX18.intoUint128();
    }
}
