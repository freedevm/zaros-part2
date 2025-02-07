// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, convert as convertToUd60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureFeeRecipient_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });

        marketMakingEngine.configureFeeRecipient(address(perpsEngine), 0);
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(address feeRecipient) external {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureFeeRecipient(feeRecipient, 1e18);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_TheFeeRecipientIsZero(uint256 share) external givenTheSenderIsTheOwner {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "feeRecipient") });

        marketMakingEngine.configureFeeRecipient(address(0), share);
    }

    modifier whenFeeRecipientIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheTotalOfFeeRecipientsShareIsGreaterThenTheMaxOfShares(
        uint256 quantityOfFeeRecipients
    )
        external
        givenTheSenderIsTheOwner
        whenFeeRecipientIsNotZero
    {
        UD60x18 maxOfSharesX18 = ud60x18(Constants.MAX_CONFIGURABLE_PROTOCOL_FEE_SHARES);

        quantityOfFeeRecipients = bound({ x: quantityOfFeeRecipients, min: 1, max: 10 });

        UD60x18 quantityTotalOfFeeRecipientsX18 = convertToUd60x18(quantityOfFeeRecipients);

        UD60x18 sharePerFeeRecipientX18 = maxOfSharesX18.div(quantityTotalOfFeeRecipientsX18);

        for (uint256 i = 0; i < quantityOfFeeRecipients; i++) {
            marketMakingEngine.configureFeeRecipient(address(uint160(i + 1)), sharePerFeeRecipientX18.intoUint256());
        }

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.FeeRecipientShareExceedsLimit.selector) });
        marketMakingEngine.configureFeeRecipient(users.naruto.account, maxOfSharesX18.intoUint256());
    }

    function testFuzz_WhenTheTotalOfFeeRecipientsShareIsLessOrEqualThenTheMaxOfShares(uint256 quantityOfFeeRecipients)
        external
        givenTheSenderIsTheOwner
        whenFeeRecipientIsNotZero
    {
        UD60x18 maxOfSharesX18 = ud60x18(Constants.MAX_CONFIGURABLE_PROTOCOL_FEE_SHARES / 2);

        quantityOfFeeRecipients = bound({ x: quantityOfFeeRecipients, min: 1, max: 10 });

        UD60x18 quantityTotalOfFeeRecipientsX18 = convertToUd60x18(quantityOfFeeRecipients);

        UD60x18 sharePerFeeRecipientX18 = maxOfSharesX18.div(quantityTotalOfFeeRecipientsX18);

        for (uint256 i; i < quantityOfFeeRecipients; i++) {
            address feeRecipient = address(uint160(i + 1));
            uint256 share = sharePerFeeRecipientX18.intoUint256();

            // it should emit {LogConfigureFeeRecipient} event
            vm.expectEmit({ emitter: address(marketMakingEngine) });
            emit MarketMakingEngineConfigurationBranch.LogConfigureFeeRecipient(feeRecipient, share);

            marketMakingEngine.configureFeeRecipient(feeRecipient, share);
        }

        for (uint256 i; i < quantityOfFeeRecipients; i++) {
            address feeRecipient = address(uint160(i + 1));

            // it should set the protocol fee recipients in the storage
            assertEq(
                marketMakingEngine.workaround_getFeeRecipientShare(feeRecipient),
                sharePerFeeRecipientX18.intoUint256(),
                "the protocol fee recipient share should be set in the storage"
            );
        }
    }
}
