// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WeEthCoreVault {
    uint128 internal constant WEETH_CORE_VAULT_ID = 2;
    string internal constant WEETH_CORE_VAULT_NAME = "weETH Core ZLP Vault";
    string internal constant WEETH_CORE_VAULT_SYMBOL = "weETH-ZLP Core";
    uint128 internal constant WEETH_CORE_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WEETH_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WEETH_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant WEETH_CORE_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant WEETH_CORE_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WEETH_CORE_VAULT_REDEEM_FEE = 0.05e18;
    address internal constant WEETH_CORE_VAULT_ENGINE = address(0); // the address will be updated in the mainnet
}
