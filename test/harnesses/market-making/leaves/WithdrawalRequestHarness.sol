// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";

contract WithdrawalRequestHarness {
    function exposed_WithdrawalRequest_load(
        uint128 vaultId,
        address account,
        uint128 withdrawalRequestId
    )
        external
        pure
        returns (WithdrawalRequest.Data memory)
    {
        WithdrawalRequest.Data memory withdrawRequestData =
            WithdrawalRequest.load(vaultId, account, withdrawalRequestId);

        return withdrawRequestData;
    }

    function exposed_WithdrawalRequest_loadExisting(
        uint128 vaultId,
        address account,
        uint128 withdrawalRequestId
    )
        external
        view
        returns (WithdrawalRequest.Data memory)
    {
        WithdrawalRequest.Data memory withdrawRequestData =
            WithdrawalRequest.loadExisting(vaultId, account, withdrawalRequestId);

        return withdrawRequestData;
    }
}
