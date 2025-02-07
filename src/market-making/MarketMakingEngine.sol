// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";
import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";

// solhint-disable-next-line no-empty-blocks
abstract contract IMarketMakingEngine is
    UpgradeBranch,
    LookupBranch,
    CreditDelegationBranch,
    FeeDistributionBranch,
    MarketMakingEngineConfigurationBranch,
    StabilityBranch,
    VaultRouterBranch
{ }

contract MarketMakingEngine is RootProxy {
    constructor(InitParams memory initParams) RootProxy(initParams) { }
}
