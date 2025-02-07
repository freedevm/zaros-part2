// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureUsdTokenSwapConfig_Integration_Test is Base_Test {
    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(
        uint128 baseFeeUsd,
        uint128 swapSettlementFeeBps,
        uint128 maxExecutionTime
    )
        external
    {
        vm.assume(maxExecutionTime > 0);
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureUsdTokenSwapConfig(baseFeeUsd, swapSettlementFeeBps, maxExecutionTime);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_TheMaxExecutionTimeIsZero(
        uint128 baseFeeUsd,
        uint128 swapSettlementFeeBps
    )
        external
        givenTheSenderIsTheOwner
    {
        changePrank({ msgSender: users.owner.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maxExecutionTime") });

        marketMakingEngine.configureUsdTokenSwapConfig(baseFeeUsd, swapSettlementFeeBps, 0);
    }

    function test_WhenTheMaxExecutionTimeIsNotZero(
        uint128 baseFeeUsd,
        uint128 swapSettlementFeeBps,
        uint128 maxExecutionTime
    )
        external
        givenTheSenderIsTheOwner
    {
        vm.assume(maxExecutionTime > 0);

        changePrank({ msgSender: users.owner.account });

        vm.expectEmit();
        emit UsdTokenSwapConfig.LogUpdateUsdTokenSwapConfig(baseFeeUsd, swapSettlementFeeBps, maxExecutionTime);

        marketMakingEngine.configureUsdTokenSwapConfig(baseFeeUsd, swapSettlementFeeBps, maxExecutionTime);

        // it should update the usd token swap fees
        (uint128 actualSwapSettlementFeeBps, uint128 actualBaseFeeUsd) = marketMakingEngine.getUsdTokenSwapFees();

        assertEq(actualSwapSettlementFeeBps, swapSettlementFeeBps);
        assertEq(actualBaseFeeUsd, baseFeeUsd);
    }
}
