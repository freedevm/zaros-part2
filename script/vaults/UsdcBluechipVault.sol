// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract UsdcBluechipVault {
    uint128 internal constant USDC_BLUECHIP_VAULT_ID = 7;
    string internal constant USDC_BLUECHIP_VAULT_NAME = "Usdc Bluechip ZLP Vault";
    string internal constant USDC_BLUECHIP_VAULT_SYMBOL = "Usdc-ZLP Bluechip";
    uint128 internal constant USDC_BLUECHIP_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant USDC_BLUECHIP_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant USDC_BLUECHIP_VAULT_IS_ENABLED = true;
    uint256 internal constant USDC_BLUECHIP_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant USDC_BLUECHIP_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant USDC_BLUECHIP_VAULT_REDEEM_FEE = 0.05e18;
    address internal constant USDC_BLUECHIP_VAULT_ENGINE = address(0); // the address will be updated in the mainnet
}
