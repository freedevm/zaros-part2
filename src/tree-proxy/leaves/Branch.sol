// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Branch {
    struct Data {
        address branch;
        bytes4[] selectors;
    }
}
