// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpMarketBranch } from "@zaros/perpetuals/branches/PerpMarketBranch.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { TradingAccountBranchTestnet } from "testnet/branches/TradingAccountBranchTestnet.sol";
import { PerpsEngineConfigurationHarness } from "test/harnesses/perpetuals/leaves/PerpsEngineConfigurationHarness.sol";
import { MarginCollateralConfigurationHarness } from
    "test/harnesses/perpetuals/leaves/MarginCollateralConfigurationHarness.sol";
import { MarketConfigurationHarness } from "test/harnesses/perpetuals/leaves/MarketConfigurationHarness.sol";
import { MarketOrderHarness } from "test/harnesses/perpetuals/leaves/MarketOrderHarness.sol";
import { PerpMarketHarness } from "test/harnesses/perpetuals/leaves/PerpMarketHarness.sol";
import { PositionHarness } from "test/harnesses/perpetuals/leaves/PositionHarness.sol";
import { SettlementConfigurationHarness } from "test/harnesses/perpetuals/leaves/SettlementConfigurationHarness.sol";
import { TradingAccountHarness } from "test/harnesses/perpetuals/leaves/TradingAccountHarness.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { VaultHarness } from "test/harnesses/market-making/leaves/VaultHarness.sol";
import { WithdrawalRequestHarness } from "test/harnesses/market-making/leaves/WithdrawalRequestHarness.sol";
import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { CollateralHarness } from "test/harnesses/market-making/leaves/CollateralHarness.sol";
import { DistributionHarness } from "test/harnesses/market-making/leaves/DistributionHarness.sol";
import { MarketHarness } from "test/harnesses/market-making/leaves/MarketHarness.sol";
import { MarketMakingEngineConfigurationHarness } from
    "test/harnesses/market-making/leaves/MarketMakingEngineConfigurationHarness.sol";
import { DexSwapStrategyHarness } from "test/harnesses/market-making/leaves/DexSwapStrategyHarness.sol";
import { CollateralHarness } from "test/harnesses/market-making/leaves/CollateralHarness.sol";
import { StabilityConfigurationHarness } from "test/harnesses/market-making/leaves/StabilityConfigurationHarness.sol";

// Open Zeppelin Upgradeable dependencies
import { EIP712Upgradeable } from "@openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// Perps Engine

function deployPerpsEngineBranches(bool isTestnet) returns (address[] memory) {
    address[] memory branches = new address[](8);

    address upgradeBranch = address(new UpgradeBranch());
    console.log("UpgradeBranch: ", upgradeBranch);

    address lookupBranch = address(new LookupBranch());
    console.log("LookupBranch: ", lookupBranch);

    address liquidationBranch = address(new LiquidationBranch());
    console.log("LiquidationBranch: ", liquidationBranch);

    address orderBranch = address(new OrderBranch());
    console.log("OrderBranch: ", orderBranch);

    address perpMarketBranch = address(new PerpMarketBranch());
    console.log("PerpMarketBranch: ", perpMarketBranch);

    address settlementBranch = address(new SettlementBranch());
    console.log("SettlementBranch: ", settlementBranch);

    address perpsEngineConfigurationBranch;
    address tradingAccountBranch;

    perpsEngineConfigurationBranch = address(new PerpsEngineConfigurationBranch());

    if (isTestnet) {
        tradingAccountBranch = address(new TradingAccountBranchTestnet());
    } else {
        tradingAccountBranch = address(new TradingAccountBranch());
    }
    console.log("PerpsEngineConfigurationBranch: ", perpsEngineConfigurationBranch);
    console.log("TradingAccountBranch: ", tradingAccountBranch);

    branches[0] = upgradeBranch;
    branches[1] = lookupBranch;
    branches[2] = perpsEngineConfigurationBranch;
    branches[3] = liquidationBranch;
    branches[4] = orderBranch;
    branches[5] = perpMarketBranch;
    branches[6] = tradingAccountBranch;
    branches[7] = settlementBranch;

    return branches;
}

function getPerpsEngineBranchesSelectors(bool isTestnet) pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory upgradeBranchSelectors = new bytes4[](2);

    upgradeBranchSelectors[0] = UpgradeBranch.upgrade.selector;
    upgradeBranchSelectors[1] = OwnableUpgradeable.transferOwnership.selector;

    bytes4[] memory lookupBranchSelectors = new bytes4[](4);

    lookupBranchSelectors[0] = LookupBranch.branches.selector;
    lookupBranchSelectors[1] = LookupBranch.branchFunctionSelectors.selector;
    lookupBranchSelectors[2] = LookupBranch.branchAddresses.selector;
    lookupBranchSelectors[3] = LookupBranch.branchAddress.selector;

    bytes4[] memory perpsEngineConfigurationBranchSelectors = new bytes4[](16);

    perpsEngineConfigurationBranchSelectors[0] =
        PerpsEngineConfigurationBranch.getAccountsWithActivePositions.selector;
    perpsEngineConfigurationBranchSelectors[1] =
        PerpsEngineConfigurationBranch.getMarginCollateralConfiguration.selector;
    perpsEngineConfigurationBranchSelectors[2] = PerpsEngineConfigurationBranch.setTradingAccountToken.selector;
    perpsEngineConfigurationBranchSelectors[3] =
        PerpsEngineConfigurationBranch.configureCollateralLiquidationPriority.selector;
    perpsEngineConfigurationBranchSelectors[4] = PerpsEngineConfigurationBranch.configureLiquidators.selector;
    perpsEngineConfigurationBranchSelectors[5] = PerpsEngineConfigurationBranch.configureMarginCollateral.selector;
    perpsEngineConfigurationBranchSelectors[6] =
        PerpsEngineConfigurationBranch.removeCollateralFromLiquidationPriority.selector;
    perpsEngineConfigurationBranchSelectors[7] = PerpsEngineConfigurationBranch.configureSystemParameters.selector;
    perpsEngineConfigurationBranchSelectors[8] = PerpsEngineConfigurationBranch.createPerpMarket.selector;
    perpsEngineConfigurationBranchSelectors[9] = PerpsEngineConfigurationBranch.updatePerpMarketConfiguration.selector;
    perpsEngineConfigurationBranchSelectors[10] = PerpsEngineConfigurationBranch.updatePerpMarketStatus.selector;
    perpsEngineConfigurationBranchSelectors[11] =
        PerpsEngineConfigurationBranch.updateSettlementConfiguration.selector;
    perpsEngineConfigurationBranchSelectors[12] = PerpsEngineConfigurationBranch.setUsdToken.selector;
    perpsEngineConfigurationBranchSelectors[13] =
        PerpsEngineConfigurationBranch.getCustomReferralCodeReferrer.selector;
    perpsEngineConfigurationBranchSelectors[14] = PerpsEngineConfigurationBranch.createCustomReferralCode.selector;
    perpsEngineConfigurationBranchSelectors[15] = PerpsEngineConfigurationBranch.configureReferralModule.selector;

    bytes4[] memory liquidationBranchSelectors = new bytes4[](2);

    liquidationBranchSelectors[0] = LiquidationBranch.checkLiquidatableAccounts.selector;
    liquidationBranchSelectors[1] = LiquidationBranch.liquidateAccounts.selector;

    bytes4[] memory orderBranchSelectors = new bytes4[](7);

    orderBranchSelectors[0] = OrderBranch.getConfiguredOrderFees.selector;
    orderBranchSelectors[1] = OrderBranch.simulateTrade.selector;
    orderBranchSelectors[2] = OrderBranch.getMarginRequirementForTrade.selector;
    orderBranchSelectors[3] = OrderBranch.getActiveMarketOrder.selector;
    orderBranchSelectors[4] = OrderBranch.createMarketOrder.selector;
    orderBranchSelectors[5] = OrderBranch.cancelAllOffchainOrders.selector;
    orderBranchSelectors[6] = OrderBranch.cancelMarketOrder.selector;

    bytes4[] memory perpMarketBranchSelectors = new bytes4[](11);

    perpMarketBranchSelectors[0] = PerpMarketBranch.getName.selector;
    perpMarketBranchSelectors[1] = PerpMarketBranch.getSymbol.selector;
    perpMarketBranchSelectors[2] = PerpMarketBranch.getMaxOpenInterest.selector;
    perpMarketBranchSelectors[3] = PerpMarketBranch.getMaxSkew.selector;
    perpMarketBranchSelectors[4] = PerpMarketBranch.getSkew.selector;
    perpMarketBranchSelectors[5] = PerpMarketBranch.getOpenInterest.selector;
    perpMarketBranchSelectors[6] = PerpMarketBranch.getMarkPrice.selector;
    perpMarketBranchSelectors[7] = PerpMarketBranch.getSettlementConfiguration.selector;
    perpMarketBranchSelectors[8] = PerpMarketBranch.getFundingRate.selector;
    perpMarketBranchSelectors[9] = PerpMarketBranch.getFundingVelocity.selector;
    perpMarketBranchSelectors[10] = PerpMarketBranch.getPerpMarketConfiguration.selector;

    bytes4[] memory tradingAccountBranchSelectors = new bytes4[](isTestnet ? 15 : 13);

    tradingAccountBranchSelectors[0] = TradingAccountBranch.getTradingAccountToken.selector;
    tradingAccountBranchSelectors[1] = TradingAccountBranch.getAccountMarginCollateralBalance.selector;
    tradingAccountBranchSelectors[2] = TradingAccountBranch.getAccountEquityUsd.selector;
    tradingAccountBranchSelectors[3] = TradingAccountBranch.getAccountMarginBreakdown.selector;
    tradingAccountBranchSelectors[4] = TradingAccountBranch.getAccountTotalUnrealizedPnl.selector;
    tradingAccountBranchSelectors[5] = TradingAccountBranch.getAccountLeverage.selector;
    tradingAccountBranchSelectors[6] = TradingAccountBranch.getPositionState.selector;
    tradingAccountBranchSelectors[7] = TradingAccountBranch.createTradingAccount.selector;
    tradingAccountBranchSelectors[8] = TradingAccountBranch.createTradingAccountAndMulticall.selector;
    tradingAccountBranchSelectors[9] = TradingAccountBranch.depositMargin.selector;
    tradingAccountBranchSelectors[10] = TradingAccountBranch.withdrawMargin.selector;
    tradingAccountBranchSelectors[11] = TradingAccountBranch.notifyAccountTransfer.selector;
    tradingAccountBranchSelectors[12] = TradingAccountBranch.getUserReferralData.selector;

    if (isTestnet) {
        tradingAccountBranchSelectors[13] = TradingAccountBranchTestnet.isUserAccountCreated.selector;
        tradingAccountBranchSelectors[14] = TradingAccountBranchTestnet.createTradingAccountWithSender.selector;
    }

    bytes4[] memory settlementBranchSelectors = new bytes4[](4);

    settlementBranchSelectors[0] = EIP712Upgradeable.eip712Domain.selector;
    settlementBranchSelectors[1] = SettlementBranch.DOMAIN_SEPARATOR.selector;
    settlementBranchSelectors[2] = SettlementBranch.fillMarketOrder.selector;
    settlementBranchSelectors[3] = SettlementBranch.fillOffchainOrders.selector;

    selectors[0] = upgradeBranchSelectors;
    selectors[1] = lookupBranchSelectors;
    selectors[2] = perpsEngineConfigurationBranchSelectors;
    selectors[3] = liquidationBranchSelectors;
    selectors[4] = orderBranchSelectors;
    selectors[5] = perpMarketBranchSelectors;
    selectors[6] = tradingAccountBranchSelectors;
    selectors[7] = settlementBranchSelectors;

    return selectors;
}

function deployPerpsEngineHarnesses(RootProxy.BranchUpgrade[] memory branchUpgrades)
    returns (RootProxy.BranchUpgrade[] memory)
{
    address[] memory harnesses = deployPerpsEngineAddressHarnesses();

    bytes4[][] memory harnessesSelectors = getPerpsEngineHarnessesSelectors();

    RootProxy.BranchUpgrade[] memory harnessesUpgrades =
        getBranchUpgrades(harnesses, harnessesSelectors, RootProxy.BranchUpgradeAction.Add);

    uint256 cachedBranchUpgradesLength = branchUpgrades.length;

    uint256 maxLength = cachedBranchUpgradesLength + harnessesUpgrades.length;

    RootProxy.BranchUpgrade[] memory brancheAndHarnessesUpgrades = new RootProxy.BranchUpgrade[](maxLength);

    for (uint256 i; i < maxLength; i++) {
        brancheAndHarnessesUpgrades[i] =
            i < cachedBranchUpgradesLength ? branchUpgrades[i] : harnessesUpgrades[i - cachedBranchUpgradesLength];
    }

    return brancheAndHarnessesUpgrades;
}

function deployPerpsEngineAddressHarnesses() returns (address[] memory) {
    address[] memory addressHarnesses = new address[](8);

    address perpsEngineConfigurationHarness = address(new PerpsEngineConfigurationHarness());
    console.log("PerpsEngineConfigurationHarness: ", perpsEngineConfigurationHarness);

    address marginCollateralConfigurationHarness = address(new MarginCollateralConfigurationHarness());
    console.log("MarginCollateralConfigurationHarness: ", marginCollateralConfigurationHarness);

    address marketConfigurationHarness = address(new MarketConfigurationHarness());
    console.log("MarketConfigurationHarness: ", marketConfigurationHarness);

    address marketOrderHarness = address(new MarketOrderHarness());
    console.log("MarketOrderHarness: ", marketOrderHarness);

    address perpMarketHarness = address(new PerpMarketHarness());
    console.log("PerpMarketHarness: ", perpMarketHarness);

    address positionHarness = address(new PositionHarness());
    console.log("PositionHarness: ", positionHarness);

    address settlementConfigurationHarness = address(new SettlementConfigurationHarness());
    console.log("SettlementConfigurationHarness: ", settlementConfigurationHarness);

    address tradingAccountHarness = address(new TradingAccountHarness());
    console.log("TradingAccountHarness: ", tradingAccountHarness);

    addressHarnesses[0] = perpsEngineConfigurationHarness;
    addressHarnesses[1] = marginCollateralConfigurationHarness;
    addressHarnesses[2] = marketConfigurationHarness;
    addressHarnesses[3] = marketOrderHarness;
    addressHarnesses[4] = perpMarketHarness;
    addressHarnesses[5] = positionHarness;
    addressHarnesses[6] = settlementConfigurationHarness;
    addressHarnesses[7] = tradingAccountHarness;

    return addressHarnesses;
}

function getPerpsEngineHarnessesSelectors() pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory perpsEngineConfigurationHarnessSelectors = new bytes4[](13);
    perpsEngineConfigurationHarnessSelectors[0] =
        PerpsEngineConfigurationHarness.exposed_checkMarketIsEnabled.selector;
    perpsEngineConfigurationHarnessSelectors[1] = PerpsEngineConfigurationHarness.exposed_addMarket.selector;
    perpsEngineConfigurationHarnessSelectors[2] = PerpsEngineConfigurationHarness.exposed_removeMarket.selector;
    perpsEngineConfigurationHarnessSelectors[3] =
        PerpsEngineConfigurationHarness.exposed_configureCollateralLiquidationPriority.selector;
    perpsEngineConfigurationHarnessSelectors[4] =
        PerpsEngineConfigurationHarness.exposed_removeCollateralFromLiquidationPriority.selector;
    perpsEngineConfigurationHarnessSelectors[5] =
        PerpsEngineConfigurationHarness.workaround_getAccountIdWithActivePositions.selector;
    perpsEngineConfigurationHarnessSelectors[6] =
        PerpsEngineConfigurationHarness.workaround_getAccountsIdsWithActivePositionsLength.selector;
    perpsEngineConfigurationHarnessSelectors[7] =
        PerpsEngineConfigurationHarness.workaround_getTradingAccountToken.selector;
    perpsEngineConfigurationHarnessSelectors[8] = PerpsEngineConfigurationHarness.workaround_getUsdToken.selector;
    perpsEngineConfigurationHarnessSelectors[9] =
        PerpsEngineConfigurationHarness.workaround_getCollateralLiquidationPriority.selector;
    perpsEngineConfigurationHarnessSelectors[10] =
        PerpsEngineConfigurationHarness.workaround_getMaxPositionsPerAccount.selector;
    perpsEngineConfigurationHarnessSelectors[11] =
        PerpsEngineConfigurationHarness.workaround_getLiquidationFeeUsdX18.selector;
    perpsEngineConfigurationHarnessSelectors[12] =
        PerpsEngineConfigurationHarness.workaround_getReferralModule.selector;

    bytes4[] memory marginCollateralConfigurationHarnessSelectors = new bytes4[](6);
    marginCollateralConfigurationHarnessSelectors[0] =
        MarginCollateralConfigurationHarness.exposed_MarginCollateral_load.selector;
    marginCollateralConfigurationHarnessSelectors[1] =
        MarginCollateralConfigurationHarness.exposed_convertTokenAmountToUd60x18.selector;
    marginCollateralConfigurationHarnessSelectors[2] =
        MarginCollateralConfigurationHarness.exposed_convertUd60x18ToTokenAmount.selector;
    marginCollateralConfigurationHarnessSelectors[3] = MarginCollateralConfigurationHarness.exposed_getPrice.selector;
    marginCollateralConfigurationHarnessSelectors[4] = MarginCollateralConfigurationHarness.exposed_configure.selector;
    marginCollateralConfigurationHarnessSelectors[5] =
        MarginCollateralConfigurationHarness.workaround_getTotalDeposited.selector;

    bytes4[] memory marketConfigurationHarnessSelectors = new bytes4[](1);
    marketConfigurationHarnessSelectors[0] = MarketConfigurationHarness.exposed_update.selector;

    bytes4[] memory marketOrderHarnessSelectors = new bytes4[](5);
    marketOrderHarnessSelectors[0] = MarketOrderHarness.exposed_MarketOrder_load.selector;
    marketOrderHarnessSelectors[1] = MarketOrderHarness.exposed_MarketOrder_loadExisting.selector;
    marketOrderHarnessSelectors[2] = MarketOrderHarness.exposed_update.selector;
    marketOrderHarnessSelectors[3] = MarketOrderHarness.exposed_clear.selector;
    marketOrderHarnessSelectors[4] = MarketOrderHarness.exposed_checkPendingOrder.selector;

    bytes4[] memory perpMarketHarnessSelectors = new bytes4[](14);
    perpMarketHarnessSelectors[0] = PerpMarketHarness.exposed_PerpMarket_load.selector;
    perpMarketHarnessSelectors[1] = PerpMarketHarness.exposed_getIndexPrice.selector;
    perpMarketHarnessSelectors[2] = PerpMarketHarness.exposed_getMarkPrice.selector;
    perpMarketHarnessSelectors[3] = PerpMarketHarness.exposed_getCurrentFundingRate.selector;
    perpMarketHarnessSelectors[4] = PerpMarketHarness.exposed_getCurrentFundingVelocity.selector;
    perpMarketHarnessSelectors[5] = PerpMarketHarness.exposed_getOrderFeeUsd.selector;
    perpMarketHarnessSelectors[6] = PerpMarketHarness.exposed_getNextFundingFeePerUnit.selector;
    perpMarketHarnessSelectors[7] = PerpMarketHarness.exposed_getPendingFundingFeePerUnit.selector;
    perpMarketHarnessSelectors[8] = PerpMarketHarness.exposed_getProportionalElapsedSinceLastFunding.selector;
    perpMarketHarnessSelectors[9] = PerpMarketHarness.exposed_checkOpenInterestLimits.selector;
    perpMarketHarnessSelectors[10] = PerpMarketHarness.exposed_checkTradeSize.selector;
    perpMarketHarnessSelectors[11] = PerpMarketHarness.exposed_updateFunding.selector;
    perpMarketHarnessSelectors[12] = PerpMarketHarness.exposed_updateOpenInterest.selector;
    perpMarketHarnessSelectors[13] = PerpMarketHarness.exposed_create.selector;

    bytes4[] memory positionHarnessSelectors = new bytes4[](9);
    positionHarnessSelectors[0] = PositionHarness.exposed_Position_load.selector;
    positionHarnessSelectors[1] = PositionHarness.exposed_getState.selector;
    positionHarnessSelectors[2] = PositionHarness.exposed_update.selector;
    positionHarnessSelectors[3] = PositionHarness.exposed_clear.selector;
    positionHarnessSelectors[4] = PositionHarness.exposed_getAccruedFunding.selector;
    positionHarnessSelectors[5] = PositionHarness.exposed_getMarginRequirements.selector;
    positionHarnessSelectors[6] = PositionHarness.exposed_getNotionalValue.selector;
    positionHarnessSelectors[7] = PositionHarness.exposed_getUnrealizedPnl.selector;
    positionHarnessSelectors[8] = PositionHarness.exposed_isNotionalValueIncreasing.selector;

    bytes4[] memory settlementConfigurationHarnessSelectors = new bytes4[](6);
    settlementConfigurationHarnessSelectors[0] =
        SettlementConfigurationHarness.exposed_SettlementConfiguration_load.selector;
    settlementConfigurationHarnessSelectors[1] =
        SettlementConfigurationHarness.exposed_checkIsSettlementEnabled.selector;
    settlementConfigurationHarnessSelectors[2] =
        SettlementConfigurationHarness.exposed_requireDataStreamsReportIsVaid.selector;
    settlementConfigurationHarnessSelectors[3] = SettlementConfigurationHarness.exposed_update.selector;
    settlementConfigurationHarnessSelectors[4] = SettlementConfigurationHarness.exposed_verifyOffchainPrice.selector;
    settlementConfigurationHarnessSelectors[5] =
        SettlementConfigurationHarness.exposed_verifyDataStreamsReport.selector;

    bytes4[] memory tradingAccountHarnessSelectors = new bytes4[](24);
    tradingAccountHarnessSelectors[0] = TradingAccountHarness.exposed_TradingAccount_loadExisting.selector;
    tradingAccountHarnessSelectors[1] = TradingAccountHarness.exposed_loadExistingAccountAndVerifySender.selector;
    tradingAccountHarnessSelectors[2] = TradingAccountHarness.exposed_validatePositionsLimit.selector;
    tradingAccountHarnessSelectors[3] = TradingAccountHarness.exposed_validateMarginRequirements.selector;
    tradingAccountHarnessSelectors[4] = TradingAccountHarness.exposed_getMarginCollateralBalance.selector;
    tradingAccountHarnessSelectors[5] = TradingAccountHarness.exposed_getEquityUsd.selector;
    tradingAccountHarnessSelectors[6] = TradingAccountHarness.exposed_getMarginBalanceUsd.selector;
    tradingAccountHarnessSelectors[7] =
        TradingAccountHarness.exposed_getAccountMarginRequirementUsdAndUnrealizedPnlUsd.selector;
    tradingAccountHarnessSelectors[8] = TradingAccountHarness.exposed_getAccontUnrealizedPnlUsd.selector;
    tradingAccountHarnessSelectors[9] = TradingAccountHarness.exposed_verifySender.selector;
    tradingAccountHarnessSelectors[10] = TradingAccountHarness.exposed_isLiquidatable.selector;
    tradingAccountHarnessSelectors[11] = TradingAccountHarness.exposed_create.selector;
    tradingAccountHarnessSelectors[12] = TradingAccountHarness.exposed_deposit.selector;
    tradingAccountHarnessSelectors[13] = TradingAccountHarness.exposed_withdraw.selector;
    tradingAccountHarnessSelectors[14] = TradingAccountHarness.exposed_withdrawMarginUsd.selector;
    tradingAccountHarnessSelectors[15] = TradingAccountHarness.exposed_deductAccountMargin.selector;
    tradingAccountHarnessSelectors[16] = TradingAccountHarness.exposed_updateActiveMarkets.selector;
    tradingAccountHarnessSelectors[17] = TradingAccountHarness.exposed_isMarketWithActivePosition.selector;
    tradingAccountHarnessSelectors[18] = TradingAccountHarness.workaround_getActiveMarketId.selector;
    tradingAccountHarnessSelectors[19] = TradingAccountHarness.workaround_getActiveMarketsIdsLength.selector;
    tradingAccountHarnessSelectors[20] = TradingAccountHarness.workaround_getNonce.selector;
    tradingAccountHarnessSelectors[21] = TradingAccountHarness.workaround_hasOffchainOrderBeenFilled.selector;
    tradingAccountHarnessSelectors[22] =
        TradingAccountHarness.workaround_getIfMarginCollateralBalanceX18ContainsTheCollateral.selector;
    tradingAccountHarnessSelectors[23] = TradingAccountHarness.workaround_getTradingAccountIdAndOwner.selector;

    selectors[0] = perpsEngineConfigurationHarnessSelectors;
    selectors[1] = marginCollateralConfigurationHarnessSelectors;
    selectors[2] = marketConfigurationHarnessSelectors;
    selectors[3] = marketOrderHarnessSelectors;
    selectors[4] = perpMarketHarnessSelectors;
    selectors[5] = positionHarnessSelectors;
    selectors[6] = settlementConfigurationHarnessSelectors;
    selectors[7] = tradingAccountHarnessSelectors;

    return selectors;
}

// Market Making Engine

function deployMarketMakingEngineBranches() returns (address[] memory) {
    address[] memory branches = new address[](6);

    address upgradeBranch = address(new UpgradeBranch());
    console.log("UpgradeBranch: ", upgradeBranch);

    address creditDelegationBranch = address(new CreditDelegationBranch());
    console.log("CreditDelegationBranch: ", creditDelegationBranch);

    address marketMakingEnginConfigBranch = address(new MarketMakingEngineConfigurationBranch());
    console.log("MarketMakingEnginConfigBranch: ", marketMakingEnginConfigBranch);

    address vaultRouterBranch = address(new VaultRouterBranch());
    console.log("VaultRouterBranch: ", vaultRouterBranch);

    address feeDistributionBranch = address(new FeeDistributionBranch());
    console.log("FeeDistributionBranch: ", feeDistributionBranch);

    address stabillityBranch = address(new StabilityBranch());
    console.log("StabilityBranch: ", stabillityBranch);

    branches[0] = upgradeBranch;
    branches[1] = marketMakingEnginConfigBranch;
    branches[2] = vaultRouterBranch;
    branches[3] = feeDistributionBranch;
    branches[4] = stabillityBranch;
    branches[5] = creditDelegationBranch;

    return branches;
}

function getMarketMakerBranchesSelectors() pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](6);

    bytes4[] memory upgradeBranchSelectors = new bytes4[](2);

    upgradeBranchSelectors[0] = UpgradeBranch.upgrade.selector;
    upgradeBranchSelectors[1] = OwnableUpgradeable.transferOwnership.selector;

    bytes4[] memory marketMakingEngineConfigBranchSelectors = new bytes4[](32);
    marketMakingEngineConfigBranchSelectors[0] =
        MarketMakingEngineConfigurationBranch.configureSystemParameters.selector;
    marketMakingEngineConfigBranchSelectors[1] =
        MarketMakingEngineConfigurationBranch.createCustomReferralCode.selector;
    marketMakingEngineConfigBranchSelectors[2] = MarketMakingEngineConfigurationBranch.createVault.selector;
    marketMakingEngineConfigBranchSelectors[3] =
        MarketMakingEngineConfigurationBranch.getCustomReferralCodeReferrer.selector;
    marketMakingEngineConfigBranchSelectors[4] =
        MarketMakingEngineConfigurationBranch.updateVaultConfiguration.selector;
    marketMakingEngineConfigBranchSelectors[5] = MarketMakingEngineConfigurationBranch.configureSystemKeeper.selector;
    marketMakingEngineConfigBranchSelectors[6] = MarketMakingEngineConfigurationBranch.configureEngine.selector;
    marketMakingEngineConfigBranchSelectors[7] = MarketMakingEngineConfigurationBranch.setWeth.selector;
    marketMakingEngineConfigBranchSelectors[8] = MarketMakingEngineConfigurationBranch.configureCollateral.selector;
    marketMakingEngineConfigBranchSelectors[9] = MarketMakingEngineConfigurationBranch.configureMarket.selector;
    marketMakingEngineConfigBranchSelectors[10] =
        MarketMakingEngineConfigurationBranch.configureDexSwapStrategy.selector;
    marketMakingEngineConfigBranchSelectors[11] = MarketMakingEngineConfigurationBranch.configureFeeRecipient.selector;
    marketMakingEngineConfigBranchSelectors[12] =
        MarketMakingEngineConfigurationBranch.connectVaultsAndMarkets.selector;
    marketMakingEngineConfigBranchSelectors[13] =
        MarketMakingEngineConfigurationBranch.configureReferralModule.selector;
    marketMakingEngineConfigBranchSelectors[14] =
        MarketMakingEngineConfigurationBranch.updateVaultAssetAllowance.selector;
    marketMakingEngineConfigBranchSelectors[15] =
        MarketMakingEngineConfigurationBranch.updateStabilityConfiguration.selector;
    marketMakingEngineConfigBranchSelectors[16] = MarketMakingEngineConfigurationBranch.getCollateralData.selector;
    marketMakingEngineConfigBranchSelectors[17] =
        MarketMakingEngineConfigurationBranch.configureUsdTokenSwapConfig.selector;
    marketMakingEngineConfigBranchSelectors[18] = MarketMakingEngineConfigurationBranch.unpauseMarket.selector;
    marketMakingEngineConfigBranchSelectors[19] = MarketMakingEngineConfigurationBranch.pauseMarket.selector;
    marketMakingEngineConfigBranchSelectors[20] = MarketMakingEngineConfigurationBranch.getLiveMarketIds.selector;
    marketMakingEngineConfigBranchSelectors[21] =
        MarketMakingEngineConfigurationBranch.configureAssetCustomSwapPath.selector;
    marketMakingEngineConfigBranchSelectors[22] = MarketMakingEngineConfigurationBranch.getAssetSwapPath.selector;
    marketMakingEngineConfigBranchSelectors[23] = MarketMakingEngineConfigurationBranch.getUsdTokenSwapFees.selector;
    marketMakingEngineConfigBranchSelectors[24] =
        MarketMakingEngineConfigurationBranch.configureDepositAndRedeemFees.selector;
    marketMakingEngineConfigBranchSelectors[25] =
        MarketMakingEngineConfigurationBranch.configureVaultDepositAndRedeemFeeRecipient.selector;
    marketMakingEngineConfigBranchSelectors[26] = MarketMakingEngineConfigurationBranch.setUsdc.selector;
    marketMakingEngineConfigBranchSelectors[27] =
        MarketMakingEngineConfigurationBranch.setSettlementBaseFeeUsdX18.selector;
    marketMakingEngineConfigBranchSelectors[28] =
        MarketMakingEngineConfigurationBranch.updateVaultSwapStrategy.selector;
    marketMakingEngineConfigBranchSelectors[29] =
        MarketMakingEngineConfigurationBranch.getUsdTokenAvailableForEngine.selector;
    marketMakingEngineConfigBranchSelectors[30] = MarketMakingEngineConfigurationBranch.setVaultEngine.selector;
    MarketMakingEngineConfigurationBranch.getUsdTokenAvailableForEngine.selector;
    marketMakingEngineConfigBranchSelectors[31] = MarketMakingEngineConfigurationBranch.configureWhitelist.selector;

    bytes4[] memory vaultRouterBranchSelectors = new bytes4[](12);
    vaultRouterBranchSelectors[0] = VaultRouterBranch.deposit.selector;
    vaultRouterBranchSelectors[1] = VaultRouterBranch.getIndexTokenSwapRate.selector;
    vaultRouterBranchSelectors[2] = VaultRouterBranch.getVaultData.selector;
    vaultRouterBranchSelectors[3] = VaultRouterBranch.initiateWithdrawal.selector;
    vaultRouterBranchSelectors[4] = VaultRouterBranch.redeem.selector;
    vaultRouterBranchSelectors[5] = VaultRouterBranch.stake.selector;
    vaultRouterBranchSelectors[6] = VaultRouterBranch.unstake.selector;
    vaultRouterBranchSelectors[7] = VaultRouterBranch.getVaultAssetSwapRate.selector;
    vaultRouterBranchSelectors[8] = VaultRouterBranch.getStakedSharesOfAccount.selector;
    vaultRouterBranchSelectors[9] = VaultRouterBranch.getDepositCap.selector;
    vaultRouterBranchSelectors[10] = VaultRouterBranch.getTotalAndAccountStakingData.selector;
    vaultRouterBranchSelectors[11] = VaultRouterBranch.getVaultCreditCapacity.selector;

    bytes4[] memory feeDistributionBranchSelectors = new bytes4[](9);
    feeDistributionBranchSelectors[0] = FeeDistributionBranch.getEarnedFees.selector;
    feeDistributionBranchSelectors[1] = FeeDistributionBranch.receiveMarketFee.selector;
    feeDistributionBranchSelectors[2] = FeeDistributionBranch.convertAccumulatedFeesToWeth.selector;
    feeDistributionBranchSelectors[3] = FeeDistributionBranch.sendWethToFeeRecipients.selector;
    feeDistributionBranchSelectors[4] = FeeDistributionBranch.claimFees.selector;
    feeDistributionBranchSelectors[5] = FeeDistributionBranch.getAssetValue.selector;
    feeDistributionBranchSelectors[6] = FeeDistributionBranch.getReceivedMarketFees.selector;
    feeDistributionBranchSelectors[7] = FeeDistributionBranch.getDexSwapStrategy.selector;
    feeDistributionBranchSelectors[8] = FeeDistributionBranch.getWethRewardDataRaw.selector;

    bytes4[] memory stabilityBranchSelectors = new bytes4[](7);

    stabilityBranchSelectors[0] = StabilityBranch.getSwapRequest.selector;
    stabilityBranchSelectors[1] = StabilityBranch.getAmountOfAssetOut.selector;
    stabilityBranchSelectors[2] = StabilityBranch.getFeesForAssetsAmountOut.selector;
    stabilityBranchSelectors[3] = StabilityBranch.getFeesForUsdTokenAmountIn.selector;
    stabilityBranchSelectors[4] = StabilityBranch.initiateSwap.selector;
    stabilityBranchSelectors[5] = StabilityBranch.fulfillSwap.selector;
    stabilityBranchSelectors[6] = StabilityBranch.refundSwap.selector;

    bytes4[] memory creditDelegationBranchSelectors = new bytes4[](11);
    creditDelegationBranchSelectors[0] = CreditDelegationBranch.getCreditCapacityForMarketId.selector;
    creditDelegationBranchSelectors[1] = CreditDelegationBranch.getAdjustedProfitForMarketId.selector;
    creditDelegationBranchSelectors[2] = CreditDelegationBranch.depositCreditForMarket.selector;
    creditDelegationBranchSelectors[3] = CreditDelegationBranch.withdrawUsdTokenFromMarket.selector;
    creditDelegationBranchSelectors[4] = CreditDelegationBranch.settleVaultsDebt.selector;
    creditDelegationBranchSelectors[5] = CreditDelegationBranch.rebalanceVaultsAssets.selector;
    creditDelegationBranchSelectors[6] = CreditDelegationBranch.updateMarketCreditDelegations.selector;
    creditDelegationBranchSelectors[7] =
        CreditDelegationBranch.updateMarketCreditDelegationsAndReturnCapacity.selector;
    creditDelegationBranchSelectors[8] = CreditDelegationBranch.updateVaultCreditCapacity.selector;
    creditDelegationBranchSelectors[9] = CreditDelegationBranch.calculateSwapAmount.selector;
    creditDelegationBranchSelectors[10] = CreditDelegationBranch.convertMarketsCreditDepositsToUsdc.selector;

    selectors[0] = upgradeBranchSelectors;
    selectors[1] = marketMakingEngineConfigBranchSelectors;
    selectors[2] = vaultRouterBranchSelectors;
    selectors[3] = feeDistributionBranchSelectors;
    selectors[4] = stabilityBranchSelectors;
    selectors[5] = creditDelegationBranchSelectors;

    return selectors;
}

function deployMarketMakingHarnesses(RootProxy.BranchUpgrade[] memory branchUpgrades)
    returns (RootProxy.BranchUpgrade[] memory)
{
    address[] memory harnesses = deployMarketMakingAddressHarnesses();

    bytes4[][] memory harnessesSelectors = getMarketMakingHarnessSelectors();

    RootProxy.BranchUpgrade[] memory harnessesUpgrades =
        getBranchUpgrades(harnesses, harnessesSelectors, RootProxy.BranchUpgradeAction.Add);

    uint256 cachedBranchUpgradesLength = branchUpgrades.length;
    uint256 maxLength = cachedBranchUpgradesLength + harnessesUpgrades.length;

    RootProxy.BranchUpgrade[] memory brancheAndHarnessesUpgrades = new RootProxy.BranchUpgrade[](maxLength);

    for (uint256 i; i < maxLength; i++) {
        brancheAndHarnessesUpgrades[i] =
            i < cachedBranchUpgradesLength ? branchUpgrades[i] : harnessesUpgrades[i - cachedBranchUpgradesLength];
    }

    return brancheAndHarnessesUpgrades;
}

function deployMarketMakingAddressHarnesses() returns (address[] memory) {
    address[] memory addressHarnesses = new address[](8);

    address vaultHarness = address(new VaultHarness());
    console.log("VaultHarness: ", vaultHarness);

    address withdrawalRequestHarness = address(new WithdrawalRequestHarness());
    console.log("WithdrawalRequestHarness: ", withdrawalRequestHarness);

    address collateralHarness = address(new CollateralHarness());
    console.log("CollateralHarness: ", collateralHarness);

    address distributionHarness = address(new DistributionHarness());
    console.log("DistributionHarness: ", distributionHarness);

    address marketHarness = address(new MarketHarness());
    console.log("MarketHarness: ", marketHarness);

    address marketMakingEngineConfigurationHarness = address(new MarketMakingEngineConfigurationHarness());
    console.log("MarketMakingEngineConfigurationHarness: ", marketMakingEngineConfigurationHarness);

    address dexSwapStrategyHarness = address(new DexSwapStrategyHarness());
    console.log("DexSwapStrategyHarness: ", dexSwapStrategyHarness);

    address stabilityConfigurationHarness = address(new StabilityConfigurationHarness());
    console.log("StabilityConfigurationHarness: ", stabilityConfigurationHarness);

    addressHarnesses[0] = vaultHarness;
    addressHarnesses[1] = withdrawalRequestHarness;
    addressHarnesses[2] = collateralHarness;
    addressHarnesses[3] = distributionHarness;
    addressHarnesses[4] = marketHarness;
    addressHarnesses[5] = marketMakingEngineConfigurationHarness;
    addressHarnesses[6] = dexSwapStrategyHarness;
    addressHarnesses[7] = stabilityConfigurationHarness;

    return addressHarnesses;
}

function getMarketMakingHarnessSelectors() pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory vaultHarnessSelectors = new bytes4[](18);
    vaultHarnessSelectors[0] = VaultHarness.workaround_Vault_getIndexToken.selector;
    vaultHarnessSelectors[1] = VaultHarness.workaround_Vault_getActorStakedShares.selector;
    vaultHarnessSelectors[2] = VaultHarness.workaround_Vault_getTotalStakedShares.selector;
    vaultHarnessSelectors[3] = VaultHarness.workaround_Vault_getWithdrawDelay.selector;
    vaultHarnessSelectors[4] = VaultHarness.workaround_Vault_getDepositCap.selector;
    vaultHarnessSelectors[5] = VaultHarness.workaround_Vault_getIsLive.selector;
    vaultHarnessSelectors[6] = VaultHarness.exposed_Vault_create.selector;
    vaultHarnessSelectors[7] = VaultHarness.exposed_Vault_update.selector;
    vaultHarnessSelectors[8] = VaultHarness.workaround_Vault_getVaultAsset.selector;
    vaultHarnessSelectors[9] = VaultHarness.workaround_Vault_setTotalStakedShares.selector;
    vaultHarnessSelectors[10] = VaultHarness.workaround_Vault_getValuePerShare.selector;
    vaultHarnessSelectors[11] = VaultHarness.workaround_Vault_getConnectedMarkets.selector;
    vaultHarnessSelectors[12] = VaultHarness.workaround_Vault_setTotalCreditDelegationWeight.selector;
    vaultHarnessSelectors[13] = VaultHarness.workaround_setVaultDebt.selector;
    vaultHarnessSelectors[14] = VaultHarness.workaround_getVaultDebt.selector;
    vaultHarnessSelectors[15] = VaultHarness.workaround_setVaultDepositedUsdc.selector;
    vaultHarnessSelectors[16] = VaultHarness.workaround_getVaultDepositedUsdc.selector;
    vaultHarnessSelectors[17] = VaultHarness.workaround_getVaultTotalDebt.selector;

    bytes4[] memory collateralHarnessSelectors = new bytes4[](2);
    collateralHarnessSelectors[0] = CollateralHarness.exposed_Collateral_load.selector;
    collateralHarnessSelectors[1] = CollateralHarness.workaround_Collateral_setParams.selector;

    bytes4[] memory withdrawalRequestHarnessSelectors = new bytes4[](2);
    withdrawalRequestHarnessSelectors[0] = WithdrawalRequestHarness.exposed_WithdrawalRequest_load.selector;
    withdrawalRequestHarnessSelectors[1] = WithdrawalRequestHarness.exposed_WithdrawalRequest_loadExisting.selector;

    bytes4[] memory distributionHarnessSelectors = new bytes4[](4);
    distributionHarnessSelectors[0] = DistributionHarness.exposed_setActorShares.selector;
    distributionHarnessSelectors[1] = DistributionHarness.exposed_distributeValue.selector;
    distributionHarnessSelectors[2] = DistributionHarness.exposed_accumulateActor.selector;
    distributionHarnessSelectors[3] = DistributionHarness.exposed_getActorValueChange.selector;

    bytes4[] memory marketHarnessSelectors = new bytes4[](18);
    marketHarnessSelectors[0] = MarketHarness.workaround_getMarketId.selector;
    marketHarnessSelectors[1] = MarketHarness.workaround_setMarketId.selector;
    marketHarnessSelectors[2] = MarketHarness.workaround_getReceivedMarketFees.selector;
    marketHarnessSelectors[3] = MarketHarness.workaround_setReceivedMarketFees.selector;
    marketHarnessSelectors[4] = MarketHarness.workaround_getPendingProtocolWethReward.selector;
    marketHarnessSelectors[5] = MarketHarness.workaround_getIfReceivedMarketFeesContainsTheAsset.selector;
    marketHarnessSelectors[6] = MarketHarness.workaround_getMarketEngine.selector;
    marketHarnessSelectors[7] = MarketHarness.workaround_getAutoDeleverageStartThreshold.selector;
    marketHarnessSelectors[8] = MarketHarness.workaround_getAutoDeleverageEndThreshold.selector;
    marketHarnessSelectors[9] = MarketHarness.workaround_getAutoDeleveragePowerScale.selector;
    marketHarnessSelectors[10] = MarketHarness.workaround_updateMarketTotalDelegatedCreditUsd.selector;
    marketHarnessSelectors[11] = MarketHarness.workaround_getMarketCreditDeposit.selector;
    marketHarnessSelectors[12] = MarketHarness.workaround_getTotalDelegatedCreditUsd.selector;
    marketHarnessSelectors[13] = MarketHarness.workaround_getTotalMarketDebt.selector;
    marketHarnessSelectors[14] = MarketHarness.workaround_getMarketUsdTokenIssuance.selector;
    marketHarnessSelectors[15] = MarketHarness.workaround_setMarketUsdTokenIssuance.selector;
    marketHarnessSelectors[16] = MarketHarness.workaround_getAutoDeleverageFactor.selector;
    marketHarnessSelectors[17] = MarketHarness.workaround_getCreditDepositsValueUsd.selector;

    bytes4[] memory marketMakingEngineConfigurationSelectors = new bytes4[](7);
    marketMakingEngineConfigurationSelectors[0] =
        MarketMakingEngineConfigurationHarness.workaround_setWethAddress.selector;
    marketMakingEngineConfigurationSelectors[1] =
        MarketMakingEngineConfigurationHarness.exposed_getTotalFeeRecipientsShares.selector;
    marketMakingEngineConfigurationSelectors[2] =
        MarketMakingEngineConfigurationHarness.workaround_getIfSystemKeeperIsEnabled.selector;
    marketMakingEngineConfigurationSelectors[3] =
        MarketMakingEngineConfigurationHarness.workaround_getWethAddress.selector;
    marketMakingEngineConfigurationSelectors[4] =
        MarketMakingEngineConfigurationHarness.workaround_getFeeRecipientShare.selector;
    marketMakingEngineConfigurationSelectors[5] =
        MarketMakingEngineConfigurationHarness.workaround_getIfEngineIsRegistered.selector;
    marketMakingEngineConfigurationSelectors[6] =
        MarketMakingEngineConfigurationHarness.workaround_getUsdTokenOfEngine.selector;

    bytes4[] memory dexSwapStrategyHarnessSelectors = new bytes4[](1);
    dexSwapStrategyHarnessSelectors[0] = DexSwapStrategyHarness.exposed_dexSwapStrategy_load.selector;

    bytes4[] memory stabilityConfigurationHarnessSelectors = new bytes4[](1);
    stabilityConfigurationHarnessSelectors[0] =
        StabilityConfigurationHarness.exposed_StabilityConfiguration_load.selector;

    selectors[0] = vaultHarnessSelectors;
    selectors[1] = withdrawalRequestHarnessSelectors;
    selectors[2] = collateralHarnessSelectors;
    selectors[3] = distributionHarnessSelectors;
    selectors[4] = marketHarnessSelectors;
    selectors[5] = marketMakingEngineConfigurationSelectors;
    selectors[6] = dexSwapStrategyHarnessSelectors;
    selectors[7] = stabilityConfigurationHarnessSelectors;

    return selectors;
}

// Shared Utils

function getInitializables(address[] memory branches) pure returns (address[] memory) {
    address[] memory initializables = new address[](1);

    address upgradeBranch = branches[0];

    initializables[0] = upgradeBranch;

    return initializables;
}

function getInitializePayloads(address deployer) pure returns (bytes[] memory) {
    bytes[] memory initializePayloads = new bytes[](1);

    bytes memory rootUpgradeInitializeData = abi.encodeWithSelector(UpgradeBranch.initialize.selector, deployer);

    initializePayloads = new bytes[](1);

    initializePayloads[0] = rootUpgradeInitializeData;

    return initializePayloads;
}

function getBranchUpgrades(
    address[] memory branches,
    bytes4[][] memory branchesSelectors,
    RootProxy.BranchUpgradeAction action
)
    pure
    returns (RootProxy.BranchUpgrade[] memory)
{
    require(branches.length == branchesSelectors.length, "TreeProxyUtils: branchesSelectors length mismatch");
    RootProxy.BranchUpgrade[] memory branchUpgrades = new RootProxy.BranchUpgrade[](branches.length);

    for (uint256 i; i < branches.length; i++) {
        bytes4[] memory selectors = branchesSelectors[i];
        branchUpgrades[i] = RootProxy.BranchUpgrade({ branch: branches[i], action: action, selectors: selectors });
    }

    return branchUpgrades;
}
