// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract CreditDelegationBranch_DepositCreditForMarket_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheRegisteredEngine(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount);
    }

    modifier givenTheSenderIsTheRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(
        uint256 marketId,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
    {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: address(fuzzMarketConfig.engine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, 0);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheCollateralIsNotEnabled(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        address assetNotEnabled = address(123);

        changePrank({ msgSender: users.owner.account });

        marketMakingEngine.configureEngine(address(fuzzMarketConfig.engine), address(usdToken), true);

        changePrank({ msgSender: address(fuzzMarketConfig.engine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, assetNotEnabled, amount);
    }

    modifier whenTheCollateralIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketIsNotLive(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: users.owner.account });

        marketMakingEngine.pauseMarket(fuzzMarketConfig.marketId);

        changePrank({ msgSender: address(fuzzMarketConfig.engine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketIsDisabled.selector, fuzzMarketConfig.marketId));

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount);
    }

    modifier whenTheMarketIsLive() {
        _;
    }

    function testFuzz_RevertWhen_TheTotalDelegatedCreditUsdIsZero(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
        whenTheMarketIsLive
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 0);

        deal({ token: address(wEth), to: address(fuzzMarketConfig.engine), give: amount });
        changePrank({ msgSender: address(fuzzMarketConfig.engine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.NoDelegatedCredit.selector, fuzzMarketConfig.marketId));

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount);
    }

    modifier whenTheTotalDelegatedCreditUsdIsGreaterThanZero() {
        _;
    }

    function testFuzz_WhenTheCollateralTypeIsNotUsdc(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
        whenTheMarketIsLive
        whenTheTotalDelegatedCreditUsdIsGreaterThanZero
    {
        amount = bound({ x: amount, min: 1, max: type(uint128).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        vm.assume(fuzzVaultConfig.asset != address(usdc));

        deal({ token: address(fuzzVaultConfig.asset), to: address(fuzzMarketConfig.engine), give: amount });
        changePrank({ msgSender: address(fuzzMarketConfig.engine) });

        // it should emit {LogDepositCreditForMarket} event
        vm.expectEmit();
        emit CreditDelegationBranch.LogDepositCreditForMarket(
            address(fuzzMarketConfig.engine), fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount
        );

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount);

        uint256 mmBalance = IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine));

        // it should deposit credit for market
        assertEq(mmBalance, amount);
    }

    function testFuzz_WhenTheCollateralTypeIsUsdc(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
        whenTheMarketIsLive
        whenTheTotalDelegatedCreditUsdIsGreaterThanZero
    {
        amount = bound({ x: amount, min: 1, max: type(uint64).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureEngine(fuzzMarketConfig.engine, address(usdc), true);

        deal({ token: address(usdc), to: address(fuzzMarketConfig.engine), give: amount });
        changePrank({ msgSender: address(fuzzMarketConfig.engine) });

        // it should emit {LogDepositCreditForMarket} event
        vm.expectEmit();
        emit CreditDelegationBranch.LogDepositCreditForMarket(
            address(fuzzMarketConfig.engine), fuzzMarketConfig.marketId, address(usdc), amount
        );

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, address(usdc), amount);

        int128 usdTokenIssuance = marketMakingEngine.workaround_getMarketUsdTokenIssuance(fuzzMarketConfig.marketId);
        int128 amountIssued = -int128(convertTokenAmountToUd60x18(address(usdc), amount).intoUint128());

        // it should update net usd token issuance
        assertEq(usdTokenIssuance, amountIssued);
    }
}
