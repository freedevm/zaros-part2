// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract DistributionHarness {
    function exposed_setActorShares(uint128 vaultId, bytes32 actorId, UD60x18 newActorShares) external {
        Distribution.Data storage self = _load_distributionData(vaultId);
        Distribution.setActorShares(self, actorId, newActorShares);
    }

    function exposed_distributeValue(uint128 vaultId, SD59x18 value) external {
        Distribution.Data storage self = _load_distributionData(vaultId);
        Distribution.distributeValue(self, value);
    }

    function exposed_accumulateActor(uint128 vaultId, bytes32 actorId) external {
        Distribution.Data storage self = _load_distributionData(vaultId);
        Distribution.accumulateActor(self, actorId);
    }

    function exposed_getActorValueChange(
        uint128 vaultId,
        bytes32 actorId
    )
        external
        view
        returns (SD59x18 valueChange)
    {
        Distribution.Data storage self = _load_distributionData(vaultId);
        valueChange = Distribution.getActorValueChange(self, actorId);
    }

    function _load_distributionData(uint128 vaultId) internal view returns (Distribution.Data storage) {
        Vault.Data storage vault = Vault.load(vaultId);
        Distribution.Data storage self = vault.wethRewardDistribution;
        return self;
    }
}
