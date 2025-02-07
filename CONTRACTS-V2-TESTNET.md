Contracts V2 Testnet

————————————————————————————————————————————————————

```bash
forge script script/01_DeployPerpsEngine.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv
```

```bash
== Logs ==
  Trading Account NFT Implementation:  0x6EBF081791E5759F333f68AFC361d9BBeAd4221A
  Trading Account NFT Proxy:  0x5aB9775a775b00b122dc85aEb8C869456b13b5E1
  UpgradeBranch:  0x4BD3194c8DC23c1A1aE06F96545b1a51Ccc3e1aB
  LookupBranch:  0x26a38e75E2ecbf0C632d44391F1523056235d13a
  LiquidationBranch:  0xeb4a38970E1355F8dbFc5D8159013932fCF951a3
  OrderBranch:  0x622A099e6698Ac888E88d9ef612f0198838b8614
  PerpMarketBranch:  0xf8e4E1AB165BA5E51d54C479b9D26a23698ccaB3
  SettlementBranch:  0x48695D4C5ef287C597885aE7B1DC7a2109Df9F17
  PerpsEngineConfigurationBranch:  0x9a9e18b79b7877FEBF6bEEA14A9ee60eb5Ab40E9
  TradingAccountBranch:  0x05a9ebfaA03fdB8Dc82DE21EE31B24A0e1C97ac8
  Perps Engine:  0x6f7b7e54a643E1285004AaCA95f3B2e6F5bcC1f3
```

- Update `TRADING_ACCOUNT_NFT` environment variable in the `.env` file
- Update `PERPS_ENGINE` environment variable in the `.env` file
- Update `PERPS_ENGINE` variable in the `LimitedMintingERC20.sol`
- Update `PERPS_ENGINE` variable in the `createListOfTradingAccounts.js`

**IMPORTANT**

- Add `Perps Engine` address to the allowlist of Chainlink or send some ETHs to the contract.

————————————————————————————————————————————————————

```bash
forge script script/testnet/DeployTestnetTokens.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv
```

```bash
== Logs ==
  Limited Minting ERC20 Implementation:  0x5D3EDD497625B4A83874Ac784324328753193cA5
  USDC Proxy:  0x95011b96c11A4cc96CD8351165645E00F68632a3
  USD Token Proxy:  0x8648d10fE74dD9b4B454B4db9B63b03998c087Ba
```

- Update `USDC_ADDRESS` in the `Usdc.sol`
- Update `USD_TOKEN_ADDRESS`in the `UsdToken.sol`
- Update `USDC` environment variable in the `.env` file
- Update `USD_TOKEN` environment variable in the `.env` file

————————————————————————————————————————————————————

```bash
forge script script/testnet/SetStartTimeMinting.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv
```

```bash
== Logs ==
  Start time minting set to: 1725380400
```

————————————————————————————————————————————————————

```bash
forge script script/02_ConfigurePerpsEngine.s.sol --sig "run(uint256,uint256)" 1 2 --rpc-url arbitrum_sepolia --broadcast -vvvv
```

```bash
== Logs ==
  Liquidation Keeper:  0xa16D95d24C2eB9515A1C2cB2Ef5D6079A606f249
```

**IMPORTANT**

Add the backend address to the liquidators list.

Backend address:

```bash
0x3eDe0C869bAdEa7cE520b8f166D83882d2f812e7
```

————————————————————————————————————————————————————

```bash
forge script script/03_CreatePerpMarkets.s.sol --sig "run(uint256,uint256)" 1 10 --rpc-url arbitrum_sepolia --broadcast -vvvv
```

```bash
== Logs ==
  MarketOrderKeeper Implementation:  0xF3E763C7Fca6f215e2291F4082bC5C37818ee18C
  Market Order Keeper Deployed: Market ID:  1  Keeper Address:  0x5402cD031cDd4be6EBC1e87c83F2CbF74910B8C0
  Market Order Keeper Deployed: Market ID:  2  Keeper Address:  0x2C21cE45A084f7F88751e39b07d3E6f5d0bafbF2
  Market Order Keeper Deployed: Market ID:  3  Keeper Address:  0xAFc82EA76337e0A517dD1D5b27c2f610853a5F9f
  Market Order Keeper Deployed: Market ID:  4  Keeper Address:  0x85d11a50B8af179B01726cEa7aDe0EAef3815FeC
  Market Order Keeper Deployed: Market ID:  5  Keeper Address:  0x96816189B5bbA8294d3223552220F0F1A9667e52
  Market Order Keeper Deployed: Market ID:  6  Keeper Address:  0x8590827E97dC690Aea5FA3cb0c2562003a81CE68
  Market Order Keeper Deployed: Market ID:  7  Keeper Address:  0x88f18fc20153aA83f85A84d516F4e97644B32823
  Market Order Keeper Deployed: Market ID:  8  Keeper Address:  0x28821973e91727a30637bf2897f99dD176815877
  Market Order Keeper Deployed: Market ID:  9  Keeper Address:  0x3ABCCc08a0c46D167C216D45ff659c7a38b5122b
  Market Order Keeper Deployed: Market ID:  10  Keeper Address:  0x55bBDcA16e61c92Bbfb3EeC6E6a4945733712f5C
```

————————————————————————————————————————————————————

```bash
forge script script/testnet/CreateListOfCustomReferrals.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv
```

```bash
== Logs ==
  Custom referral codes created successfully
```

———————————————————————————————————————————————————— <br/> You can run in 50 by 50 with solidity script:

```bash
forge script script/testnet/CreateListOfTradingAccounts.s.sol --sig "run(uint256,uint256)" 0 50 --rpc-url arbitrum_sepolia --broadcast --legacy -vvvv
```

Or use the js script to run all at once:

```bash
node createListOfTradingAccounts.js
```

———————————————————————————————————————————————————— <br/> Market order keepers in the Chalink Automation:

```bash
BTC-USD Market ID: 1: https://automation.chain.link/arbitrum-sepolia/90288828766752025420065681979340487832907615164954474878130858312114572802820

ETH-USD Market ID: 2: https://automation.chain.link/arbitrum-sepolia/22724859653427040038333265196992261532600691781038222874262656527374323591436

LINK-USD Market ID: 3: https://automation.chain.link/arbitrum-sepolia/71280062757094415063577176279764411083044785898586669699989754562255680645047

ARB-USD Market ID: 4: https://automation.chain.link/arbitrum-sepolia/52421709066767344843019016708061370815671179932347678584237148917104442131304

BNB-USD Market ID: 5: https://automation.chain.link/arbitrum-sepolia/109549509299905944702164110313233113535309560685321601450478694536609972147182

DOGE-USD Market ID: 6: https://automation.chain.link/arbitrum-sepolia/104654517578662551959531702300175355227488660496497810788334776721028354514947

SOL-USD Market ID: 7: https://automation.chain.link/arbitrum-sepolia/35621757010058026145014009818377710677272340625864424800924593996152817697230

MATIC-USD Market ID: 8: https://automation.chain.link/arbitrum-sepolia/30214420403468262678569815066631317573545403301451271178037657656521827838679

LTC-USD Market ID: 9: https://automation.chain.link/arbitrum-sepolia/101208860049589550361438360855108562231942372946435897962569807109826448078229

FTM-USD Market ID: 10: https://automation.chain.link/arbitrum-sepolia/11886920437632908777712314774151618776394941799843815047975461379531670939078
```

———————————————————————————————————————————————————— <br/>

```bash
forge script script/utils/SetForwarders.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv
```

```bash
== Logs ==
  Setting forwarder for 0x5402cD031cDd4be6EBC1e87c83F2CbF74910B8C0 to 0xd07284c6eF58ebaaD73D5e04CB856E04cd7B6A6F
  Setting forwarder for 0x2C21cE45A084f7F88751e39b07d3E6f5d0bafbF2 to 0xD6e66f5533FB8D9aca018E1823eb9421239347be
  Setting forwarder for 0xAFc82EA76337e0A517dD1D5b27c2f610853a5F9f to 0x96f03bF3Aa48DF56F488a48b7B78877A53F716de
  Setting forwarder for 0x85d11a50B8af179B01726cEa7aDe0EAef3815FeC to 0x2787786Ec13137145014d10C43B3C1CDeF508fb4
  Setting forwarder for 0x96816189B5bbA8294d3223552220F0F1A9667e52 to 0xAd4a9E0BC0ad15d0438Fac49641bC3C12F046Ae1
  Setting forwarder for 0x8590827E97dC690Aea5FA3cb0c2562003a81CE68 to 0x32A596a0dDA92e882cf503fdDeCADC861dDFE1C7
  Setting forwarder for 0x88f18fc20153aA83f85A84d516F4e97644B32823 to 0xdf1C1CAD465085B290Fc0E4335bC527196d57132
  Setting forwarder for 0x28821973e91727a30637bf2897f99dD176815877 to 0x88Cf545bbDD68AAa84B44495C56E50F3106dA978
  Setting forwarder for 0x3ABCCc08a0c46D167C216D45ff659c7a38b5122b to 0xA2391BdA5c88f21018Bd8506798B1Ac24B83A75f
  Setting forwarder for 0x55bBDcA16e61c92Bbfb3EeC6E6a4945733712f5C to 0x84115F77DC31F4808c24f6848A35f4f920721509
```
