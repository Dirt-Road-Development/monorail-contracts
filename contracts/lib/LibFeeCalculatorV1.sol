// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

library LibFeeCalculatorV1 {
    uint256 constant FEE_DENOMINATOR = 10000; // To represent percentages (100 = 1%)

    struct FeeBreakdown {
        uint256 userAmount;
        uint256 protocolFee;
    }

    // Calculate fee distribution with dynamic decimal support
    function calculateFees(uint256 amount, uint8 decimals) public pure returns (FeeBreakdown memory) {
        require(amount > 0, "Amount must be greater than zero");
        require(decimals >= 1 && decimals <= 18, "Unsupported token decimals");

        // Calculate 1% fee based on decimals
        uint256 protocolFee = (amount * 100) / FEE_DENOMINATOR; // 1% of the amount

        // If protocolFee is zero, set it to a minimum value (1 unit in the smallest unit)
        if (protocolFee == 0) {
            protocolFee = 10 ** (18 - decimals); // Ensure at least 1 unit of fee
        }

        // Calculate user amount after fee
        uint256 userAmount = amount - protocolFee;

        return FeeBreakdown(userAmount, protocolFee);
    }
}
