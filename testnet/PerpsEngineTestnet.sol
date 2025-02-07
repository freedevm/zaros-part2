// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpMarketBranch } from "@zaros/perpetuals/branches/PerpMarketBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { TradingAccountBranchTestnet } from "./branches/TradingAccountBranchTestnet.sol";

abstract contract IPerpsEngineTestnet is
    UpgradeBranch,
    LookupBranch,
    PerpsEngineConfigurationBranch,
    LiquidationBranch,
    OrderBranch,
    PerpMarketBranch,
    SettlementBranch,
    TradingAccountBranchTestnet
{ }
