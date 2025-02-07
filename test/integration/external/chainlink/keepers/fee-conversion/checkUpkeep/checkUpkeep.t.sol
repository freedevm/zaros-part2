// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { FeeConversionKeeper } from "@zaros/external/chainlink/keepers/fee-conversion-keeper/FeeConversionKeeper.sol";

contract FeeConversionKeeper_CheckUpkeep_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        configureMarkets();
        changePrank({ msgSender: address(users.naruto.account) });
    }

    modifier givenCheckUpkeepIsCalled() {
        _;
    }

    function test_WhenMarketsHaveLessThanMinFeeForDistribution() external givenCheckUpkeepIsCalled {
        configureFeeConversionKeeper(1, 1);

        (bool upkeepNeeded,) = FeeConversionKeeper(feeConversionKeeper).checkUpkeep("");

        // it should return false
        assertFalse(upkeepNeeded);
    }

    function test_WhenMarketsHaveMoreThanMinFeeForDistribution(
        uint256 marketId,
        uint256 amount,
        uint256 minFeeDistributionValueUsd
    )
        external
        givenCheckUpkeepIsCalled
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

        configureFeeConversionKeeper(1, 1);

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        (bool upkeepNeeded, bytes memory performData) = FeeConversionKeeper(feeConversionKeeper).checkUpkeep("");

        (uint128[] memory marketIds, address[] memory assets) = abi.decode(performData, (uint128[], address[]));

        // it should return true
        assertTrue(upkeepNeeded);

        assertEq(assets[0], address(usdc));
        assertEq(marketIds[0], fuzzPerpMarketCreditConfig.marketId);
    }
}
