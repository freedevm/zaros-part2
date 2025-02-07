// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

contract MarketMakingEngineConfigurationBranch_GetReceivedMarketFees_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    function test_WhenGetReceivedMarketFeesIsCalled(uint256 marketId, uint256 amount) external {
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(fuzzPerpMarketCreditConfig.engine), give: amount });

        changePrank({ msgSender: address(fuzzPerpMarketCreditConfig.engine) });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        (address[] memory assets, uint256[] memory feesCollected) =
            marketMakingEngine.getReceivedMarketFees(fuzzPerpMarketCreditConfig.marketId);

        // it should return the received fees
        assertEq(assets[0], address(usdc));
        assertEq(feesCollected[0], convertTokenAmountToUd60x18(address(usdc), amount).intoUint256());
    }
}
