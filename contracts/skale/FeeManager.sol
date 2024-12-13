// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract FeeManager is AccessControl {
    // Struct to return fee breakdown
    struct FeeDistribution {
        uint256 userAmount;     // 99% of original amount
        uint256 platformFee;    // 0.7% platform fee
        uint256 liquidityFee;   // 0.3% liquidity fee
    }

    // Constant for fee calculation precision
    uint256 private constant FEE_DENOMINATOR = 10000;

    // Calculate fee distribution with dynamic decimal support
    function calculateFees(uint256 amount, uint8 decimals) public view returns (FeeDistribution memory) {
        require(amount > 0, "Amount must be greater than zero");
        require(decimals >= 6 && decimals <= 18, "Unsupported token decimals");

        // Ensure minimum fee even for small amounts
        uint256 userAmount = (amount * (FEE_DENOMINATOR - 100)) / FEE_DENOMINATOR;
        uint256 platformFee = (amount * 80) / FEE_DENOMINATOR;
        uint256 liquidityFee = (amount * 20) / FEE_DENOMINATOR;

        // Minimum fee enforcement for tokens with fewer decimals
        if (decimals < 18) {
            uint256 minFeeUnit = 10 ** (18 - decimals);
            
            // Ensure at least 1 unit of fee for small amounts
            platformFee = platformFee == 0 ? minFeeUnit : platformFee;
            liquidityFee = liquidityFee == 0 ? minFeeUnit : liquidityFee;
        }

        // Sanity check to ensure total matches original amount
        require(
            userAmount + platformFee + liquidityFee == amount, 
            "Fee calculation error"
        );

        return FeeDistribution(
            userAmount,
            platformFee,
            liquidityFee
        );
    }
}