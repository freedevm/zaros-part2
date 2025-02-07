// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRBMath dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

contract VaultHarness {
    using EnumerableSet for EnumerableSet.UintSet;

    function workaround_Vault_getIndexToken(uint128 vaultId) external view returns (address) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.indexToken;
    }

    function workaround_Vault_getActorStakedShares(
        uint128 vaultId,
        bytes32 actorId
    )
        external
        view
        returns (uint128)
    {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.wethRewardDistribution;

        return stakingData.actor[actorId].shares;
    }

    function workaround_Vault_getValuePerShare(uint128 vaultId) external view returns (int256) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.wethRewardDistribution;

        return stakingData.valuePerShare;
    }

    function workaround_Vault_setTotalStakedShares(uint128 vaultId, uint128 newShares) external {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.wethRewardDistribution;

        stakingData.totalShares = newShares;
    }

    function workaround_Vault_getTotalStakedShares(uint128 vaultId) external view returns (uint128) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.wethRewardDistribution;

        return stakingData.totalShares;
    }

    function workaround_Vault_getWithdrawDelay(uint128 vaultId) external view returns (uint128) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.withdrawalDelay;
    }

    function workaround_Vault_getDepositCap(uint128 vaultId) external view returns (uint128) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.depositCap;
    }

    function workaround_Vault_getIsLive(uint128 vaultId) external view returns (bool) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.isLive;
    }

    function workaround_Vault_getVaultAsset(uint128 vaultId) external view returns (address) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.collateral.asset;
    }

    function exposed_Vault_create(Vault.CreateParams memory params) external {
        Vault.create(params);
    }

    function exposed_Vault_update(Vault.UpdateParams memory params) external {
        Vault.update(params);
    }

    function workaround_Vault_getConnectedMarkets(uint128 vaultId)
        external
        view
        returns (uint128[] memory connectedMarkets)
    {
        Vault.Data storage vaultData = Vault.load(vaultId);

        uint256 connectedMarketsCacheLength =
            vaultData.connectedMarkets[vaultData.connectedMarkets.length - 1].length();

        connectedMarkets = new uint128[](connectedMarketsCacheLength);

        for (uint256 i; i < connectedMarketsCacheLength; i++) {
            connectedMarkets[i] = uint128(vaultData.connectedMarkets[vaultData.connectedMarkets.length - 1].at(i));
        }
    }

    function workaround_Vault_setTotalCreditDelegationWeight(
        uint128 vaultId,
        uint128 totalCreditDelegationWeight
    )
        external
    {
        Vault.Data storage vaultData = Vault.load(vaultId);
        vaultData.totalCreditDelegationWeight = totalCreditDelegationWeight;
    }

    function workaround_setVaultDebt(uint128 vaultId, int128 amount) external {
        Vault.Data storage vaultData = Vault.load(vaultId);
        vaultData.marketsRealizedDebtUsd = amount;
    }

    function workaround_getVaultDebt(uint128 vaultId) external view returns (int128) {
        Vault.Data storage vaultData = Vault.load(vaultId);
        return vaultData.marketsRealizedDebtUsd;
    }

    function workaround_setVaultDepositedUsdc(uint128 vaultId, uint128 amount) external {
        Vault.Data storage vaultData = Vault.load(vaultId);
        vaultData.depositedUsdc = amount;
    }

    function workaround_getVaultDepositedUsdc(uint128 vaultId) external view returns (uint128) {
        Vault.Data storage vaultData = Vault.load(vaultId);
        return vaultData.depositedUsdc;
    }

    function workaround_getVaultTotalDebt(uint128 vaultId) external view returns (SD59x18) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return sd59x18(vaultData.marketsRealizedDebtUsd).add(unary(ud60x18(vaultData.depositedUsdc).intoSD59x18()))
            .add(sd59x18(vaultData.marketsUnrealizedDebtUsd));
    }
}
