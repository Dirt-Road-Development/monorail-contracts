// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IMonorailNativeToken is IERC20, IERC20Metadata {
    
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}