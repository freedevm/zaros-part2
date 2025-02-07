// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WEthBluechipVault {
    uint128 internal constant WETH_BLUECHIP_VAULT_ID = 13;
    string internal constant WETH_BLUECHIP_VAULT_NAME = "WEth Bluechip ZLP Vault";
    string internal constant WETH_BLUECHIP_VAULT_SYMBOL = "WEth-ZLP Bluechip";
    uint128 internal constant WETH_BLUECHIP_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WETH_BLUECHIP_VAULT_IS_ENABLED = true;
    uint256 internal constant WETH_BLUECHIP_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant WETH_BLUECHIP_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WETH_BLUECHIP_VAULT_REDEEM_FEE = 0.05e18;
    address internal constant WETH_BLUECHIP_VAULT_ENGINE = address(0); // the address will be updated in the mainnet
}
