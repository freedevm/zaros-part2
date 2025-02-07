// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_SetWeth_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function test_RevertGiven_TheSenderIsNotTheOwner() external {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.setWeth(address(wEth));
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function test_RevertWhen_SetWethIsZero() external givenTheSenderIsTheOwner {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "wEth") });

        marketMakingEngine.setWeth(address(0));
    }

    function test_WhenWethIsNotZero() external givenTheSenderIsTheOwner {
        // it should emit {LogSetWeth} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogSetWeth(address(wEth));

        marketMakingEngine.setWeth(address(wEth));

        // it should update the market making engine configuration storage
        assertEq(
            marketMakingEngine.workaround_getWethAddress(),
            address(wEth),
            "wEth address is not set correctly in the storage"
        );
    }
}
