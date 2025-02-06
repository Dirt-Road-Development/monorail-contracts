// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract FeeManager is AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 constant FEE_DENOMINATOR = 10000; // Default to 1%

    // Token configuration struct for tracking discount eligibility
    struct TokenConfig {
        uint256 baseFee; // Base fee percentage (e.g., 1.5% = 150)
        uint256 discountedFee; // Discounted fee percentage (e.g., 0.5% = 50)
        uint256 minThreshold; // Minimum threshold required to get discounted fee (ERC-20 amount, ERC-1155 amount, or ERC-721 ownership)
        address tokenAddress; // The address of the ERC-20, ERC-721, or ERC-1155 token
        uint8 tokenType; // 1 = ERC-20, 2 = ERC-721, 3 = ERC-1155
        uint256 tokenId;
    }

    // List of discount tokens configured (could be ERC-20, ERC-721, or ERC-1155)
    TokenConfig[] public discountTokens;

    // Events
    event TokenAdded(
        address tokenAddress, uint256 baseFee, uint256 discountedFee, uint256 minThreshold, uint8 tokenType
    );
    event TokenRemoved(address tokenAddress);

    // Constructor to grant default roles
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    // Add token configuration (manager only)
    function addToken(
        address tokenAddress,
        uint256 baseFee,
        uint256 discountedFee,
        uint256 minThreshold,
        uint256 tokenId,
        uint8 tokenType // 1 = ERC-20, 2 = ERC-721, 3 = ERC-1155
    ) external onlyRole(MANAGER_ROLE) {
        require(tokenAddress != address(0), "Invalid token address");
        require(baseFee > 0, "Base fee must be greater than 0");
        require(discountedFee < baseFee, "Discounted fee cannot be higher than base fee");

        discountTokens.push(
            TokenConfig({
                baseFee: baseFee,
                discountedFee: discountedFee,
                minThreshold: minThreshold,
                tokenAddress: tokenAddress,
                tokenType: tokenType,
                tokenId: tokenId // default to 0 for ERC-20/ERC-721
            })
        );

        emit TokenAdded(tokenAddress, baseFee, discountedFee, minThreshold, tokenType);
    }

    // Remove a token from the configuration list by its address
    function removeToken(address tokenAddress) external onlyRole(MANAGER_ROLE) {
        require(tokenAddress != address(0), "Invalid token address");

        uint256 indexToRemove = type(uint256).max;

        // Find the token index in the array
        for (uint256 i = 0; i < discountTokens.length; i++) {
            if (discountTokens[i].tokenAddress == tokenAddress) {
                indexToRemove = i;
                break;
            }
        }

        // Ensure the token was found
        require(indexToRemove != type(uint256).max, "Token not found");

        // Shift the array elements to remove the token
        discountTokens[indexToRemove] = discountTokens[discountTokens.length - 1];
        discountTokens.pop(); // Remove the last element (now a duplicate)

        emit TokenRemoved(tokenAddress);
    }

    // Calculate the highest applicable discount for the user
    function getHighestDiscount(address user) public view returns (uint256) {
        uint256 highestDiscount = 0;

        // Loop through all discount tokens to find the highest discount
        for (uint256 i = 0; i < discountTokens.length; i++) {
            TokenConfig memory config = discountTokens[i];

            // Check eligibility for discount based on token type
            uint256 discount = 0;

            if (config.tokenType == 1) {
                // ERC-20 (e.g., SKL token)
                uint256 userBalance = IERC20(config.tokenAddress).balanceOf(user);
                if (userBalance >= config.minThreshold) {
                    discount = config.discountedFee; // Apply discounted fee if user holds enough tokens
                }
            } else if (config.tokenType == 2) {
                // ERC-721 (e.g., user must own a token)
                uint256 userBalance = IERC721(config.tokenAddress).balanceOf(user);
                if (userBalance >= config.minThreshold) {
                    discount = config.discountedFee; // Apply discounted fee if user holds enough tokens
                }
            } else if (config.tokenType == 3) {
                // ERC-1155 (e.g., user must own a minimum amount of tokens)
                uint256 userBalance = IERC1155(config.tokenAddress).balanceOf(user, config.tokenId);
                if (userBalance >= config.minThreshold) {
                    discount = config.discountedFee; // Apply discounted fee if user holds enough tokens
                }
            }

            // Track the highest discount
            if (discount > highestDiscount) {
                highestDiscount = discount;
            }
        }

        return highestDiscount;
    }

    // Calculate fee based on the user's balance of the ERC-20 token or token ownership
    function calculateFees(address tokenAddress, uint256 amount, address user)
        public
        view
        returns (uint256 userAmount, uint256 protocolFee)
    {
        uint256 highestDiscount = getHighestDiscount(user);

        // Default to base fee if no discount is found
        uint256 feePercentage = highestDiscount > 0 ? highestDiscount : 150; // Default to 1.5% if no discount is available

        // Calculate protocol fee
        protocolFee = (amount * feePercentage) / FEE_DENOMINATOR;

        // Ensure the protocol fee isn't zero
        if (protocolFee == 0) {
            uint8 decimals = IERC20Metadata(tokenAddress).decimals();
            protocolFee = 10 ** (18 - decimals); // Minimum fee (1 unit of smallest token)
        }

        // Calculate user amount after the fee
        userAmount = amount - protocolFee;
    }

    // Get fee breakdown for bridging tokens
    function getFeeBreakdown(address tokenAddress, uint256 amount, address user)
        external
        view
        returns (uint256 userAmount, uint256 protocolFee)
    {
        return calculateFees(tokenAddress, amount, user);
    }

    // Helper function to check if the user meets the minimum requirement for the discount
    function meetsMinimumRequirement(address user) public view returns (bool) {
        uint256 highestDiscount = getHighestDiscount(user);
        return highestDiscount > 0;
    }
}
