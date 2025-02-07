// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";

contract UpdatePerpMarketConfiguration_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_MarketIsNotInitialized(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint128 marketIdNotInitialized = uint128(FINAL_MARKET_ID) + 1;

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            skewScale: fuzzMarketConfig.skewScale,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketNotInitialized.selector, marketIdNotInitialized)
        });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(marketIdNotInitialized, params);
    }

    modifier whenMarketIsInitialized() {
        _;
    }

    function testFuzz_RevertWhen_LengthOfNameIsZero(uint256 marketId) external whenMarketIsInitialized {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: "",
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "name") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenLengthOfNameIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_LengthOfSymbolIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: "",
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "symbol") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenLengthOfSymbolIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_PriceAdapterIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: address(0),
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "priceAdapter") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenPriceAdapterIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_MaintenanceMarginRateIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: 0,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maintenanceMarginRateX18") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenMaintenanceMarginRateIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_MaxOpenInterestIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: 0,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maxOpenInterest") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenMaxOpenInterestIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_MaxSkewIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
        whenMaxOpenInterestIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: 0,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maxSkew") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenMaxSkewIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_InitialMarginRateIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
        whenMaxOpenInterestIsNotZero
        whenMaxSkewIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: 0,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "initialMarginRateX18") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenInitialMarginRateIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_InitialMarginRateIsLessOrEqualToMaintenanceMargin(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
        whenMaxOpenInterestIsNotZero
        whenMaxSkewIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.InitialMarginRateLessOrEqualThanMaintenanceMarginRate.selector)
        });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenInitialMarginIsNotLessOrEqualToMaintenanceMargin() {
        _;
    }

    function testFuzz_RevertWhen_SkewScaleIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
        whenMaxOpenInterestIsNotZero
        whenMaxSkewIsNotZero
        whenInitialMarginIsNotLessOrEqualToMaintenanceMargin
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: 0,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "skewScale") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenSkewScaleIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_MinTradeSizeIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
        whenMaxOpenInterestIsNotZero
        whenMaxSkewIsNotZero
        whenInitialMarginIsNotLessOrEqualToMaintenanceMargin
        whenSkewScaleIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: 0,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "minTradeSizeX18") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    modifier whenMinTradeSizeIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_MaxFundingVelocityIsZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
        whenMaxOpenInterestIsNotZero
        whenMaxSkewIsNotZero
        whenInitialMarginIsNotLessOrEqualToMaintenanceMargin
        whenSkewScaleIsNotZero
        whenMinTradeSizeIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxSkew: fuzzMarketConfig.maxSkew,
            maxFundingVelocity: 0,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maxFundingVelocity") });

        changePrank({ msgSender: users.owner.account });
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, params);
    }

    function testFuzz_WhenMaxFundingVelocityIsNotZero(uint256 marketId)
        external
        whenMarketIsInitialized
        whenLengthOfNameIsNotZero
        whenLengthOfSymbolIsNotZero
        whenPriceAdapterIsNotZero
        whenMaintenanceMarginRateIsNotZero
        whenMaxOpenInterestIsNotZero
        whenMaxSkewIsNotZero
        whenInitialMarginIsNotLessOrEqualToMaintenanceMargin
        whenSkewScaleIsNotZero
        whenMinTradeSizeIsNotZero
    {
        changePrank({ msgSender: users.owner.account });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory newParams =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: "New market name",
            symbol: "New symbol",
            priceAdapter: address(123),
            initialMarginRateX18: 2,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 3,
            maxSkew: 4,
            maxFundingVelocity: 5,
            skewScale: 6,
            minTradeSizeX18: 8,
            orderFees: OrderFees.Data({ makerFee: 0.0009e18, takerFee: 0.0001e18 })
        });

        // it should emit {LogUpdatePerpMarketConfiguration} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit PerpsEngineConfigurationBranch.LogUpdatePerpMarketConfiguration(
            users.owner.account, fuzzMarketConfig.marketId
        );

        // it should update perp market
        perpsEngine.updatePerpMarketConfiguration(fuzzMarketConfig.marketId, newParams);

        PerpMarket.Data memory perpMarket = perpsEngine.exposed_PerpMarket_load(fuzzMarketConfig.marketId);

        assertEq(perpMarket.configuration.name, newParams.name, "Name should be updated");
        assertEq(perpMarket.configuration.symbol, newParams.symbol, "Symbol should be updated");
        assertEq(perpMarket.configuration.priceAdapter, newParams.priceAdapter, "PriceAdapter should be updated");
        assertEq(
            perpMarket.configuration.initialMarginRateX18,
            newParams.initialMarginRateX18,
            "InitialMarginRate should be updated"
        );
        assertEq(
            perpMarket.configuration.maintenanceMarginRateX18,
            newParams.maintenanceMarginRateX18,
            "MaintenanceMarginRate should be updated"
        );
        assertEq(
            perpMarket.configuration.maxOpenInterest, newParams.maxOpenInterest, "MaxOpenInterest should be updated"
        );
        assertEq(perpMarket.configuration.maxSkew, newParams.maxSkew, "MaxSkew should be updated");
        assertEq(
            perpMarket.configuration.maxFundingVelocity,
            newParams.maxFundingVelocity,
            "MaxFundingVelocity should be updated"
        );
        assertEq(perpMarket.configuration.skewScale, newParams.skewScale, "SkewScale should be updated");
        assertEq(
            perpMarket.configuration.minTradeSizeX18, newParams.minTradeSizeX18, "MinTradeSize should be updated"
        );
        assertEq(
            perpMarket.configuration.orderFees.makerFee, newParams.orderFees.makerFee, "MakerFee should be updated"
        );
        assertEq(
            perpMarket.configuration.orderFees.takerFee, newParams.orderFees.takerFee, "TakerFee should be updated"
        );
        assertEq(perpMarket.lastFundingTime, block.timestamp, "LastFundingTime should be updated");
    }
}
