// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {MonorailNativeToken} from "../tokens/MonorailNativeToken.sol";

contract NebulaUSDC is MonorailNativeToken {
    constructor(string memory _name, string memory _symbol) MonorailNativeToken(_name, _symbol, 6) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
    }
}
