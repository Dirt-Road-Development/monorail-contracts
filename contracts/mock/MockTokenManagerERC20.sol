// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMonorailNativeToken} from "../interfaces/IMonorailNativeToken.sol";
import {ITokenManagerERC20} from "../interfaces/ITokenManagerERC20.sol";
import {console} from "forge-std/console.sol";

error UnimplementedFunction();

contract MockTokenManagerERC20 is ITokenManagerERC20 {
    struct Token {
        address sourceToken;
        address destinationToken;
        string destinationChain;
    }

    // Source Token => Destination Chain => Destination Token
    mapping(address => mapping(string => address)) public tokenMappings;

    // Constructor to set up supported tokens (optional)
    constructor(Token[] memory tokens) {
        for (uint256 i = 0; i < tokens.length; i++) {
            addSupportedToken(tokens[i]);
        }
    }

    function transferToSchainERC20Direct(string calldata schainName, address token, uint256 amount, address receiver)
        external
    {
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "TransferFrom failed");

        IMonorailNativeToken(tokenMappings[token][schainName]).mint(receiver, amount);
    }

    // Optional: Helper to add supported tokens in tests
    function addSupportedToken(Token memory token) public {
        tokenMappings[token.sourceToken][token.destinationChain] = token.destinationToken;
    }

    function exitToMainERC20(address, /*contractOnMainnet */ uint256 /* amount */ ) external pure {
        revert UnimplementedFunction();
    }

    function transferToSchainERC20(
        string calldata, /* targetSchainName */
        address, /* contractOnMainnet */
        uint256 /* amount */
    ) external pure {
        revert UnimplementedFunction();
    }

    function addERC20TokenByOwner(
        string calldata, /* targetChainName */
        address, /* erc20OnMainnet */
        address /* erc20OnSchain */
    ) external pure {
        revert UnimplementedFunction();
    }
}
