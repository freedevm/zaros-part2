# Zaros

## About the Project

```
Zaros is a Perpetuals DEX powered by Boosted (Re)Staking Vaults. It seeks to maximize LPs yield generation, while offering a top-notch trading experience on Arbitrum (and Monad in the future).

Zaros connects Liquid Re(Staking) Tokens (LSTs & LRTs) and other yield bearing collateral types with its Perpetual Futures Engine, allowing LPs to amplify their returns with additional APY coming from trading fees. The protocol is composed of two separate, interconnected smart contracts systems:

- The Perpetuals Trading Engine (PerpsEngine root proxy contract).
- The Market Making Engine (MarketMakingEngine root proxy contract).

The Market Making Engine is responsible by the creation of the ZLP Vaults and the delegation of their underlying liquidity to markets managed by the Perpetuals Trading Engine.

Market Making Engine Overview

### High-Level Explanation

The Market Making Engine serves as the liquidity backbone of Zaros' Perpetual Trading Engine. Its primary purpose is to allow liquidity providers to contribute to Zaros’ markets by supplying liquidity to ZLP (Zaros Liquidity Provider) vaults managed by the engine. This functionality is critical for ensuring that Zaros' markets are sufficiently capitalized, enabling efficient trading and market stability. The Market Making Engine has four core responsibilities:

- Dynamic Open Interest and Skew Caps
  - Current State: In the existing Perpetual Trading Engine, static values are used for determining the maximum open interest and maximum skew (also known as open interest caps and skew caps) for each market.
  - Market Making Engine Integration: The Market Making Engine will introduce dynamic calculation of these caps. Instead of relying on static values, the Perps Engine will call a view function within the Market Making Engine at the time a trade is being filled (whether from an order or a liquidation). This function will return the open interest caps and skew caps based on the liquidity available in the ZLP vaults.
  - Future Plans: The view function responsible for providing these dynamic caps will be located in a branch of the Market Making Engine, likely in the CreditDelegationBranch. The function getCreditForMarketId will be central to this operation, and plans include further enhancing it to interact seamlessly with the Perps Engine.

- Handling Fees and Margin Collateral
  - Collection of Fees and Collateral: The Market Making Engine is designed to receive various types of fees and margin collateral from the Perps Trading Engine. This could occur due to different scenarios such as account liquidations or the realization of a negative P&L (profit and loss) event.
  - Usage of Collected Assets: The collected fees and margin collateral are used for several purposes:
    - Backing USDz: USDz is a stablecoin used within the Zaros ecosystem to settle profits from profitable positions in the Perps Trading Engine. The stability and backing of USDz are critical, and the collected collateral helps maintain its 1:1 peg with the USD.
    - Fee Distribution to LPs: Fees are also distributed to liquidity providers (LPs) as compensation for their service and the risks they take by providing liquidity. These fees are converted into WETH (Wrapped Ether) and distributed to LPs staked in ZLP vaults.
  - Integration with Perps Engine: The Perps Engine will be configured to automatically route the collected fees and collateral to the Market Making Engine. This integration ensures that all assets are efficiently managed and utilized within the protocol.

- Informing Profit and Loss (P&L) for Trades
  - Current P&L Calculation: In the current Perps Engine, when a trade results in a positive P&L (profit), the system simply mints the corresponding amount of USDz and credits it to the trader's account. This method, while functional, does not align with the final version of the protocol.
  - Market Making Engine Role: The Market Making Engine will introduce a view function that informs the final P&L of a trade. In most cases, this function will return the same value as the calculated P&L, ensuring that the trader receives their due profit. However, the function also handles special cases, such as auto-deleveraging.
  - Auto-Deleveraging: If a ZLP vault accrues more debt than its programmed allowance, the Market Making Engine can trigger an auto-deleveraging state. In this state, the P&L of profitable positions may be globally reduced by a certain percentage. This reduction is governed by three parameters configured in the MarketCredit leaf:
    - Auto-Deleveraging Threshold: The point at which auto-deleveraging is triggered.
    - Auto-Deleveraging Factor: The percentage by which the P&L is reduced.
    - Auto-Deleveraging Scale: A configurable value that influences the severity of the auto-deleveraging.
  - Future View Functions: The function that handles P&L adjustments will be located within one of the branches of the Market Making Engine, likely within MarketCredit or a similar branch. This function will be designed to interface directly with the Perps Engine, ensuring that P&L calculations are accurate and reflective of the current market and vault states.

- Permissionless Market Making
  - Democratizing Market Making: One of the overarching goals of the Market Making Engine is to democratize the process of market making, allowing any crypto user to participate in market making for derivatives markets. This is achieved through ZLP vaults, each representing a single collateral type.
  - ZLP Vaults: Users can provide liquidity to these vaults, which are then used to support various markets on the Zaros platform. Each vault is associated with a list of market IDs it provides liquidity to, and these can be configured to cater to different risk categories or market clusters.
  - Integration and Scalability: The Market Making Engine will support a range of ZLP vaults, each tied to specific markets or market clusters. This setup not only provides flexibility but also allows the engine to scale as more markets are added to the Zaros ecosystem.

[Documentation](https://docs.zaros.fi/)
[Website](https://zaros.fi/)
[Twitter](https://x.com/zarosfi)
[GitHub](https://github.com/zaros-labs)
```

## Actors

```
Trusted Actors:
    Perps Engine: The perps engine root proxy contract address
    Market Making Engine: The market making engine root proxy contract address
    System Keeper: A trusted system keeper, often a Chainlink Automation upkeep, responsible by calling specific protocol functions based on a log or custom trigger, or by an arbitrary call.
    Chainlink Automation Forwarder: Trusted Chainlink Automation upkeep's forwarder address.

Non-Trusted Actors:
    USDz swapper: Someone that holds USDz and desires to sell it for a Vault 's collateral asset.
    LPs: The market making engine's liquidity providers, i.e users that deposit supported Collateral tokens into a ZLP Vault, providing credit to the system. It can be any non-trusted address.
    Clients: Any offchain consumer, such as Zaros’ UI, an API service, etc.
```

[//]: # (contest-details-close)



## Scope (contracts)

```js
src/
├── external/
│   └── chainlink/
│   │   └── keepers/
│   │   │    ├── debt-settlement-keeper/
│   │   │    │   └── DebtSettlementKeeper.sol
│   │   │    ├── fee-conversion-keeper/
│   │   │    │    └── FeeConversionKeeper.sol
│   │   │    └── usd-token-swap-keeper/
│   │   │         └── UsdTokenSwapKeeper.sol
├── market-making/
│   ├── branches/
│   │   ├── CreditDelegationBranch.sol
│   │   ├── FeeDistributionBranch.sol
│   │   ├── MarketMakingEngineConfigurationBranch.sol
│   │   ├── StabilityBranch.sol
│   │   └── VaultRouterBranch.sol
│   ├── interfaces/
│   │   └── IEngine.sol
│   ├── leaves/
│   │   ├── AssetSwapPath.sol
│   │   ├── Collateral.sol
│   │   ├── CreditDelegation.sol
│   │   ├── DexSwapStrategy.sol
│   │   ├── Distribution.sol
│   │   ├── LiveMarkets.sol
│   │   ├── Market.sol
│   │   ├── MarketMakingEngineConfiguration.sol
│   │   ├── StabilityConfiguration.sol
│   │   ├── Swap.sol
│   │   ├── UsdTokenSwapConfig.sol
│   │   ├── Vault.sol
│   │   └── WithdrawalRequest.sol
│   └── MarketMakingEngine.sol
├── perpetuals/
│   ├── LiquidationBranch::liquidateAccounts
│   └── SettlementBranch::_fillOrder
├── referral/
│   ├── interfaces/
│   │   └── IReferral.sol
│   ├── leaves/
│   │   ├── CustomReferralConfiguration.sol
│   │   └── ReferralConfiguration.sol
│   └── Referral.sol
├── utils/
│   ├── dex-adapters/
│   │   ├── BaseAdapter.sol
│   │   ├── CurveAdapter.sol
│   │   ├── UniswapV2Adapter.sol
│   │   └── UniswapV3Adapter.sol
│   ├── interfaces/
│   │   ├── ICurveSwapRouter.sol
│   │   ├── IDexAdapter.sol
│   │   ├── ISwapAssetConfig.sol
│   │   ├── IUniswapV2Router01.sol
│   │   ├── IUniswapV2Router02.sol
│   │   ├── IUniswapV3RouterInterface.sol
│   │   └── IUniswapV3SwapCallback.sol
│   ├── EngineAccessControl.sol
│   └── Whitelist.sol
└── zlp
    └── ZlpVault.sol
```

## Compatibilities

```
Compatibilities:
  Chain(s) to deploy to::
      - Arbitrum
      - Monad
  Tokens:
      - ETH
      - WETH
      - WEETH
      - WSTETH
      - WBTC
      - USDC
      - USDT
      - USDE
      - SUSDE
      - ERC721 (Zaros Account NFT, AccountNFT.sol)
```

[//]: # (scope-close)

[//]: # (getting-started-open)

## Setup

Build:

```bash
make install
forge build
```

Tests:

```bash
Forge test
```

[//]: # (getting-started-close)

