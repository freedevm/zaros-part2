// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";
import { MockPriceFeedWithInvalidReturn } from "test/mocks/MockPriceFeedWithInvalidReturn.sol";
import { MockPriceFeedOldUpdatedAt } from "test/mocks/MockPriceFeedOldUpdatedAt.sol";
import { MockSequencerUptimeFeedWithInvalidReturn } from "test/mocks/MockSequencerUptimeFeedWithInvalidReturn.sol";
import { MockSequencerUptimeFeedDown } from "test/mocks/MockSequencerUptimeFeedDown.sol";
import { MockSequencerUptimeFeedGracePeriodNotOver } from "test/mocks/MockSequencerUptimeFeedGracePeriodNotOver.sol";
import { IPriceAdapter, PriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { MockSequencerUptimeFeed } from "test/mocks/MockSequencerUptimeFeed.sol";
import { PriceAdapterUtils } from "script/utils/PriceAdapterUtils.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract MarginCollateralConfiguration_GetPrice_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_PriceFeedIsZero(
        uint128 newDepositCap,
        uint120 newLoanToValue,
        uint8 newDecimals
    )
        external
    {
        address newPriceAdapter = address(0);

        perpsEngine.exposed_configure(address(usdc), newDepositCap, newLoanToValue, newDecimals, newPriceAdapter);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralPriceFeedNotDefined.selector) });

        perpsEngine.exposed_getPrice(address(usdc));
    }

    modifier whenPriceFeedIsNotZero() {
        _;
    }

    function test_RevertWhen_PriceFeedDecimalsIsGreaterThanTheSystemDecimals() external whenPriceFeedIsNotZero {
        address collateral = address(wstEth);

        MockPriceFeed mockPriceFeed = new MockPriceFeed(Constants.SYSTEM_DECIMALS + 1, int256(MOCK_USDC_USD_PRICE));

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP_X18.intoUint128(),
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WSTETH_PRICE_ADAPTER_NAME,
                        symbol: WSTETH_PRICE_ADAPTER_SYMBOL,
                        owner: users.owner.account,
                        priceFeed: address(mockPriceFeed),
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: address(new MockSequencerUptimeFeed(0)),
                        priceFeedHeartbeatSeconds: MOCK_PRICE_FEED_HEARTBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            )
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidOracleReturn.selector) });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals() {
        _;
    }

    modifier whenSequencerUptimeFeedIsNotZero() {
        _;
    }

    function test_RevertWhen_SequencerUptimeFeedReturnsAInvalidValue()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenSequencerUptimeFeedIsNotZero
    {
        address collateral = address(wstEth);

        changePrank({ msgSender: users.owner.account });
        MockSequencerUptimeFeedWithInvalidReturn mockSequencerUptimeFeedWithInvalidReturn =
            new MockSequencerUptimeFeedWithInvalidReturn();

        MockPriceFeed mockPriceFeed = new MockPriceFeed(Constants.SYSTEM_DECIMALS, int256(MOCK_WEETH_USD_PRICE));

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP_X18.intoUint128(),
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WSTETH_PRICE_ADAPTER_NAME,
                        symbol: WSTETH_PRICE_ADAPTER_SYMBOL,
                        owner: users.owner.account,
                        priceFeed: address(mockPriceFeed),
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: address(mockSequencerUptimeFeedWithInvalidReturn),
                        priceFeedHeartbeatSeconds: MOCK_PRICE_FEED_HEARTBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            )
        );

        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidSequencerUptimeFeedReturn.selector, address(mockSequencerUptimeFeedWithInvalidReturn)
            )
        });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenSequencerUptimeFeedReturnsAValidValue() {
        _;
    }

    function test_RevertWhen_SequencerUptimeFeedIsDown()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenSequencerUptimeFeedIsNotZero
        whenSequencerUptimeFeedReturnsAValidValue
    {
        address collateral = address(wstEth);

        changePrank({ msgSender: users.owner.account });
        MockSequencerUptimeFeedDown mockSequencerUptimeFeedDown = new MockSequencerUptimeFeedDown();

        MockPriceFeed mockPriceFeed = new MockPriceFeed(Constants.SYSTEM_DECIMALS, int256(MOCK_WEETH_USD_PRICE));

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP_X18.intoUint128(),
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WSTETH_PRICE_ADAPTER_NAME,
                        symbol: WSTETH_PRICE_ADAPTER_SYMBOL,
                        owner: users.owner.account,
                        priceFeed: address(mockPriceFeed),
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: address(mockSequencerUptimeFeedDown),
                        priceFeedHeartbeatSeconds: MOCK_PRICE_FEED_HEARTBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            )
        );

        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OracleSequencerUptimeFeedIsDown.selector, address(mockSequencerUptimeFeedDown)
            )
        });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenSequencerUptimeFeedIsOnline() {
        _;
    }

    function test_RevertWhen_GracePeriodNotOver()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenSequencerUptimeFeedIsNotZero
        whenSequencerUptimeFeedReturnsAValidValue
        whenSequencerUptimeFeedIsOnline
    {
        address collateral = address(wstEth);

        changePrank({ msgSender: users.owner.account });
        MockSequencerUptimeFeedGracePeriodNotOver mockSequencerUptimeFeedGracePeriodNotOver =
            new MockSequencerUptimeFeedGracePeriodNotOver();

        MockPriceFeed mockPriceFeed = new MockPriceFeed(Constants.SYSTEM_DECIMALS, int256(MOCK_WEETH_USD_PRICE));

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP_X18.intoUint128(),
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WSTETH_PRICE_ADAPTER_NAME,
                        symbol: WSTETH_PRICE_ADAPTER_SYMBOL,
                        owner: users.owner.account,
                        priceFeed: address(mockPriceFeed),
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: address(mockSequencerUptimeFeedGracePeriodNotOver),
                        priceFeedHeartbeatSeconds: MOCK_PRICE_FEED_HEARTBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            )
        );

        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.GracePeriodNotOver.selector, address(mockSequencerUptimeFeedGracePeriodNotOver)
            )
        });

        perpsEngine.exposed_getPrice(collateral);
    }

    function test_RevertWhen_PriceFeedReturnsAInvalidValueFromLatestRoundData()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
    {
        address collateral = address(wstEth);

        MockPriceFeedWithInvalidReturn mockPriceFeedWithInvalidReturn = new MockPriceFeedWithInvalidReturn();

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP_X18.intoUint128(),
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WSTETH_PRICE_ADAPTER_NAME,
                        symbol: WSTETH_PRICE_ADAPTER_SYMBOL,
                        owner: users.owner.account,
                        priceFeed: address(mockPriceFeedWithInvalidReturn),
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: address(new MockSequencerUptimeFeed(0)),
                        priceFeedHeartbeatSeconds: MOCK_PRICE_FEED_HEARTBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            )
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidOracleReturn.selector) });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenPriceFeedReturnsAValidValueFromLatestRoundData() {
        _;
    }

    function test_RevertWhen_TheDifferenceOfBlockTimestampMinusUpdateAtIsGreaterThanThePriceFeedHeartbetSeconds()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenPriceFeedReturnsAValidValueFromLatestRoundData
    {
        address collateral = address(wstEth);

        MockPriceFeedOldUpdatedAt mockPriceFeedOldUpdatedAt = new MockPriceFeedOldUpdatedAt();

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP_X18.intoUint128(),
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(
                PriceAdapterUtils.deployPriceAdapter(
                    PriceAdapter.InitializeParams({
                        name: WSTETH_PRICE_ADAPTER_NAME,
                        symbol: WSTETH_PRICE_ADAPTER_SYMBOL,
                        owner: users.owner.account,
                        priceFeed: address(mockPriceFeedOldUpdatedAt),
                        ethUsdPriceFeed: address(0),
                        sequencerUptimeFeed: address(new MockSequencerUptimeFeed(0)),
                        priceFeedHeartbeatSeconds: MOCK_PRICE_FEED_HEARTBEAT_SECONDS,
                        ethUsdPriceFeedHeartbeatSeconds: 0,
                        useEthPriceFeed: false
                    })
                )
            )
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OraclePriceFeedHeartbeat.selector, address(mockPriceFeedOldUpdatedAt)
            )
        });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenTheDifferenceOfBlockTimestampMinusUpdateAtIsLessThanOrEqualThanThePriceFeedHeartbetSeconds() {
        _;
    }

    function test_RevertWhen_TheAnswerIsEqualOrLessThanTheMinAnswer()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenPriceFeedReturnsAValidValueFromLatestRoundData
        whenTheDifferenceOfBlockTimestampMinusUpdateAtIsLessThanOrEqualThanThePriceFeedHeartbetSeconds
    {
        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            perpsEngine.exposed_MarginCollateral_load(address(usdc));

        int256 price = int256(IPriceAdapter(marginCollateralConfiguration.priceAdapter).getPrice().intoUint256());

        // when the price is equal to the minAnswer
        int256 minAnswer = price;
        int256 maxAnswer = price + 2;
        MockPriceFeed(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed()).updateMockAggregator(
            minAnswer, maxAnswer
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OraclePriceFeedOutOfRange.selector,
                address(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed())
            )
        });

        perpsEngine.exposed_getPrice(address(usdc));

        // when the price is less than the minAnswer
        minAnswer = price + 1;

        MockPriceFeed(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed()).updateMockAggregator(
            minAnswer, maxAnswer
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OraclePriceFeedOutOfRange.selector,
                address(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed())
            )
        });

        perpsEngine.exposed_getPrice(address(usdc));
    }

    function test_RevertWhen_TheAnswerIsEqualOrGreaterThanTheMaxAnswer()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenPriceFeedReturnsAValidValueFromLatestRoundData
        whenTheDifferenceOfBlockTimestampMinusUpdateAtIsLessThanOrEqualThanThePriceFeedHeartbetSeconds
    {
        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            perpsEngine.exposed_MarginCollateral_load(address(usdc));

        int256 price = int256(IPriceAdapter(marginCollateralConfiguration.priceAdapter).getPrice().intoUint256());

        // when the price is equal to the maxAnswer
        int256 minAnswer = price - 2;
        int256 maxAnswer = price;
        MockPriceFeed(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed()).updateMockAggregator(
            minAnswer, maxAnswer
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OraclePriceFeedOutOfRange.selector,
                address(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed())
            )
        });

        perpsEngine.exposed_getPrice(address(usdc));

        // when the price is greater than the maxAnswer
        maxAnswer = price - 1;

        MockPriceFeed(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed()).updateMockAggregator(
            minAnswer, maxAnswer
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OraclePriceFeedOutOfRange.selector,
                address(PriceAdapter(marginCollateralConfiguration.priceAdapter).priceFeed())
            )
        });

        perpsEngine.exposed_getPrice(address(usdc));
    }

    function test_WhenTheAnswerIsGreaterThanThanTheMinAnswerAndLessThanTheMaxAnswer()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenPriceFeedReturnsAValidValueFromLatestRoundData
        whenTheDifferenceOfBlockTimestampMinusUpdateAtIsLessThanOrEqualThanThePriceFeedHeartbetSeconds
    {
        UD60x18 price = perpsEngine.exposed_getPrice(address(wstEth));

        MockPriceFeed priceFeed = MockPriceFeed(
            address(PriceAdapter(marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceAdapter).priceFeed())
        );

        uint8 priceFeedDecimals = priceFeed.decimals();

        UD60x18 expectedPrice = ud60x18(
            marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].mockUsdPrice
                * 10 ** (Constants.SYSTEM_DECIMALS - priceFeedDecimals)
        );

        // it should return the price
        assertEq(expectedPrice.intoUint256(), price.intoUint256(), "price is not correct");
    }
}
