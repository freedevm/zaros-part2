// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { FeeConversionKeeper } from "@zaros/external/chainlink/keepers/fee-conversion-keeper/FeeConversionKeeper.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

contract FeeConversionKeeper_PerformUpkeep_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_GivenCallPerformUpkeepFunction(
        uint256 marketId,
        uint256 amount,
        uint256 minFeeDistributionValueUsd
    )
        external
        givenInitializeContract
    {
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        minFeeDistributionValueUsd = bound({
            x: minFeeDistributionValueUsd,
            min: 1,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        amount = bound({
            x: amount,
            min: minFeeDistributionValueUsd,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amount });

        changePrank({ msgSender: users.owner.account });

        configureFeeConversionKeeper(1, uint128(minFeeDistributionValueUsd));

        FeeConversionKeeper(feeConversionKeeper).setForwarder(users.keepersForwarder.account);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        changePrank({ msgSender: users.keepersForwarder.account });

        uint128[] memory marketIds = new uint128[](1);
        address[] memory assets = new address[](1);

        marketIds[0] = fuzzPerpMarketCreditConfig.marketId;
        assets[0] = address(usdc);

        bytes memory performData = abi.encode(marketIds, assets);

        uint256 expectedTokenAmount = uniswapV3Adapter.getExpectedOutput(address(usdc), address(wEth), amount);
        uint256 expectedAmount = uniswapV3Adapter.calculateAmountOutMin(expectedTokenAmount);

        // it should emit {LogConvertAccumulatedFeesToWeth} event
        vm.expectEmit();
        emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(expectedAmount);

        FeeConversionKeeper(feeConversionKeeper).performUpkeep(performData);
    }
}
