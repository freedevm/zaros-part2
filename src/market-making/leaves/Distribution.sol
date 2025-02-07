//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

library Distribution {
    using SafeCast for int256;

    struct Actor {
        uint128 shares;
        int256 lastValuePerShare;
    }

    struct Data {
        uint128 totalShares;
        int256 valuePerShare;
        mapping(bytes32 actorId => Actor) actor;
    }

    function distributeValue(Data storage self, SD59x18 value) internal {
        if (value.eq(SD59x18_ZERO)) {
            return;
        }

        UD60x18 totalShares = ud60x18(self.totalShares);

        if (totalShares.eq(UD60x18_ZERO)) {
            revert Errors.EmptyDistribution();
        }

        SD59x18 deltaValuePerShare = value.div(totalShares.intoSD59x18());

        self.valuePerShare = sd59x18(self.valuePerShare).add(deltaValuePerShare).intoInt256();
    }

    function setActorShares(
        Data storage self,
        bytes32 actorId,
        UD60x18 newActorShares
    )
        internal
        returns (SD59x18 valueChange)
    {
        valueChange = getActorValueChange(self, actorId);
        Actor storage actor = self.actor[actorId];

        self.totalShares = ud60x18(self.totalShares).add(newActorShares).sub(ud60x18(actor.shares)).intoUint128();
        actor.shares = newActorShares.intoUint128();

        _updateLastValuePerShare(self, actor, newActorShares);
    }

    function accumulateActor(Data storage self, bytes32 actorId) internal returns (SD59x18 valueChange) {
        Actor storage actor = self.actor[actorId];
        return _updateLastValuePerShare(self, actor, ud60x18(actor.shares));
    }

    function getActorValueChange(Data storage self, bytes32 actorId) internal view returns (SD59x18 valueChange) {
        return _getActorValueChange(self, self.actor[actorId]);
    }

    function getActorShares(Data storage self, bytes32 actorId) internal view returns (UD60x18 shares) {
        return ud60x18(self.actor[actorId].shares);
    }

    function getTotalAndActorRawData(
        Data storage self,
        bytes32 actorId
    )
        internal
        view
        returns (uint128 totalShares, int256 valuePerShare, uint128 accountShares, int256 accountLastValuePerShare)
    {
        // global values
        (totalShares, valuePerShare) = (self.totalShares, self.valuePerShare);
        // account values
        (accountShares, accountLastValuePerShare) =
            (self.actor[actorId].shares, self.actor[actorId].lastValuePerShare);
    }

    function getValuePerShare(Data storage self) internal view returns (SD59x18) {
        return sd59x18(self.valuePerShare);
    }

    function _updateLastValuePerShare(
        Data storage self,
        Actor storage actor,
        UD60x18 newActorShares
    )
        private
        returns (SD59x18 valueChange)
    {
        valueChange = _getActorValueChange(self, actor);

        actor.lastValuePerShare = newActorShares.eq(UD60x18_ZERO) ? int256(0) : self.valuePerShare;
    }

    function _getActorValueChange(
        Data storage self,
        Actor storage actor
    )
        private
        view
        returns (SD59x18 valueChange)
    {
        SD59x18 deltaValuePerShare = sd59x18(self.valuePerShare).sub(sd59x18(actor.lastValuePerShare));
        valueChange = deltaValuePerShare.mul(ud60x18(actor.shares).intoSD59x18());
    }
}
