// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

struct TradingAccountData {
    address sender;
    address referrer;
    bool shouldUseReferrerField;
}

struct ListOfTradingAccounts {
    TradingAccountData[] data;
}

interface IPerpsEngineTestnet {
    function createTradingAccountWithSender(
        address sender,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external;
}

/// @dev This script creates a list of trading accounts.
contract CreateListOfTradingAccounts is BaseScript {
    IPerpsEngineTestnet internal perpsEngine;

    function run(uint256 initialIndex, uint256 finalIndex) public broadcaster {
        perpsEngine = IPerpsEngineTestnet(vm.envAddress("PERPS_ENGINE"));

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/testnet/listOfTradingAccounts.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        ListOfTradingAccounts memory listOfTradingAccounts = abi.decode(data, (ListOfTradingAccounts));

        uint256 limit = (finalIndex - initialIndex) + initialIndex;

        for (uint256 i = initialIndex; i < limit; i++) {
            address userSender;
            address referrer;

            bytes memory referralCode;

            if (listOfTradingAccounts.data[i].shouldUseReferrerField == true) {
                userSender = listOfTradingAccounts.data[i].referrer;
                referrer = (listOfTradingAccounts.data[i].sender);

                referralCode = abi.encode(referrer);
            } else {
                userSender = listOfTradingAccounts.data[i].sender;
                referrer = (listOfTradingAccounts.data[i].referrer);

                referralCode = bytes("");
            }

            perpsEngine.createTradingAccountWithSender(userSender, referralCode, false);
        }

        console.log("List of trading accounts created");
    }
}
