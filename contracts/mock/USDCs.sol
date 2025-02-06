// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {MonorailNativeToken} from "../tokens/MonorailNativeToken.sol";

contract USDCs is MonorailNativeToken {
    constructor(string memory _name, string memory _symbol, uint8 _decimalsValue, address station)
        MonorailNativeToken(_name, _symbol, _decimalsValue)
    {
        _grantRole(MINTER_ROLE, station);
    }
}
