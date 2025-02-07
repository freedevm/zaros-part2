// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";
import { UsdToken } from "@zaros/usd/UsdToken.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract CreditDelegationBranch_WithdrawUsdTokenFromMarket_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheRegisteredEngine(uint256 marketId, uint256 amount) external {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });

        marketMakingEngine.withdrawUsdTokenFromMarket(fuzzMarketConfig.marketId, amount);
    }

    modifier givenTheSenderIsTheRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketIsNotLive(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsTheRegisteredEngine
    {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: users.owner.account });

        marketMakingEngine.pauseMarket(fuzzMarketConfig.marketId);

        changePrank({ msgSender: address(fuzzMarketConfig.engine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketIsDisabled.selector, fuzzMarketConfig.marketId));

        marketMakingEngine.withdrawUsdTokenFromMarket(fuzzMarketConfig.marketId, amount);
    }

    modifier whenTheMarketIsLive() {
        _;
    }

    function testFuzz_RevertWhen_TheCreditCapacityUsdIsLessThanZero(
        uint256 marketId,
        uint128 amount
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheMarketIsLive
    {
        vm.assume(amount > 0);
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: users.owner.account });

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 0);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InsufficientCreditCapacity.selector, fuzzMarketConfig.marketId, 0)
        );

        changePrank({ msgSender: address(fuzzMarketConfig.engine) });
        marketMakingEngine.withdrawUsdTokenFromMarket(fuzzMarketConfig.marketId, amount);
    }

    function testFuzz_WhenTheCreditCapacityUsdIsEqualOrGreaterThanZero(
        uint256 marketId,
        uint128 amount
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheMarketIsLive
    {
        amount = uint128(bound({ x: amount, min: 1, max: type(uint96).max }));
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureEngine(
            perpMarketsCreditConfig[fuzzMarketConfig.marketId].engine, address(usdToken), true
        );

        // it should emit {LogWithdrawUsdTokenFromMarket} event
        vm.expectEmit();
        emit CreditDelegationBranch.LogWithdrawUsdTokenFromMarket(
            address(fuzzMarketConfig.engine), fuzzMarketConfig.marketId, amount, amount
        );

        changePrank({ msgSender: address(fuzzMarketConfig.engine) });
        marketMakingEngine.withdrawUsdTokenFromMarket(fuzzMarketConfig.marketId, amount);

        uint256 engineUsdTOkenBalance = IERC20(usdToken).balanceOf(address(fuzzMarketConfig.engine));

        // it should mint the usd token
        assertEq(amount, engineUsdTOkenBalance);
    }
}
