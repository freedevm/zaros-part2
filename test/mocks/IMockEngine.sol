// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IMockEngine {
    function setUnrealizedDebt(int256 newDebt) external;
}
