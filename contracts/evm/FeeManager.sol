// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract FeeManager is AccessControl {
    struct FeeRates {
        uint256 baseFee; // Fixed fee in token decimals
        uint256 variableRate; // Variable rate in basis points (1% = 100 bps)
        uint256 liquidityRate; // Liquidity rate in basis points (1% = 100 bps)
    }

    struct Fees {
        uint256 baseFee;
        uint256 variableFee;
        uint256 liquidityFee;
        uint256 totalFee;
    }

    // Mapping for stablecoin fee tiers
    mapping(uint256 => FeeRates) public stablecoinFeeTiers;

    // Array to store thresholds for stablecoin tiers (sorted order)
    uint256[] public feeThresholds;

    // Non-stable token fees
    FeeRates public nonStableTokenFees;

    // Roles
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    constructor() {
        // Grant the deployer the admin role
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(FEE_MANAGER_ROLE, _msgSender());
        

        // Initialize fee thresholds (must be in ascending order)
        feeThresholds = [1000, 10000, 100000, 1000000, type(uint256).max];

        // Initialize stablecoin fee tiers
        stablecoinFeeTiers[feeThresholds[0]] = FeeRates(1 * 10**6, 50, 50); // <=1000: $1 + 0.5% + 0.5%
        stablecoinFeeTiers[feeThresholds[1]] = FeeRates(5 * 10**6, 50, 40); // <=10,000: $5 + 0.5% + 0.4%
        stablecoinFeeTiers[feeThresholds[2]] = FeeRates(50 * 10**6, 40, 40); // <=100,000: $50 + 0.4% + 0.4%
        stablecoinFeeTiers[feeThresholds[3]] = FeeRates(100 * 10**6, 35, 30); // <=1,000,000: $100 + 0.35% + 0.3%
        stablecoinFeeTiers[feeThresholds[4]] = FeeRates(500 * 10**6, 30, 20); // >1,000,000: $500 + 0.3% + 0.2%

        // Initialize non-stable token fees
        nonStableTokenFees = FeeRates(0, 100, 50); // No base fee + 1% + 0.5%
    }

    // Calculate fees for stablecoins
    function calculateStablecoinFees(uint256 amount) public view returns (Fees memory) {
        FeeRates memory rates = getStablecoinFeeRates(amount);
        return calculateFees(amount, rates);
    }

    // Calculate fees for non-stable tokens
    function calculateNonStableTokenFees(uint256 amount) public view returns (Fees memory) {
        return calculateFees(amount, nonStableTokenFees);
    }

    // Internal function to calculate fees
    function calculateFees(uint256 amount, FeeRates memory rates) internal pure returns (Fees memory) {
        uint256 baseFee = rates.baseFee;
        uint256 variableFee = (amount * rates.variableRate) / 10000; // Variable Fee = amount * rate
        uint256 liquidityFee = (amount * rates.liquidityRate) / 10000; // Liquidity Fee = amount * rate
        uint256 totalFee = baseFee + variableFee + liquidityFee;

        return Fees(baseFee, variableFee, liquidityFee, totalFee);
    }

    // Fetch stablecoin fee rates based on amount
    function getStablecoinFeeRates(uint256 amount) public view returns (FeeRates memory) {
        for (uint256 i = 0; i < feeThresholds.length; i++) {
            if (amount <= feeThresholds[i]) {
                return stablecoinFeeTiers[feeThresholds[i]];
            }
        }

        // Default case, should never reach here
        revert("Fee rates not found for the given amount");
    }

    // Update or add a fee tier for stablecoins (requires FEE_MANAGER_ROLE)
    function updateFeeTier(uint256 threshold, FeeRates memory rates) external onlyRole(FEE_MANAGER_ROLE) {
        require(threshold > 0, "Threshold must be greater than zero");
        stablecoinFeeTiers[threshold] = rates;

        // Add to thresholds if it doesn't exist
        if (!_thresholdExists(threshold)) {
            feeThresholds.push(threshold);
            _sortThresholds();
        }
    }

    // Remove a fee tier (requires FEE_MANAGER_ROLE)
    function removeFeeTier(uint256 threshold) external onlyRole(FEE_MANAGER_ROLE) {
        require(_thresholdExists(threshold), "Threshold does not exist");
        delete stablecoinFeeTiers[threshold];

        // Remove from thresholds
        for (uint256 i = 0; i < feeThresholds.length; i++) {
            if (feeThresholds[i] == threshold) {
                feeThresholds[i] = feeThresholds[feeThresholds.length - 1];
                feeThresholds.pop();
                break;
            }
        }

        _sortThresholds();
    }

    // Update non-stable token fees (requires FEE_MANAGER_ROLE)
    function updateNonStableTokenFees(FeeRates memory rates) external onlyRole(FEE_MANAGER_ROLE) {
        nonStableTokenFees = rates;
    }

    // Check if a threshold already exists
    function _thresholdExists(uint256 threshold) internal view returns (bool) {
        for (uint256 i = 0; i < feeThresholds.length; i++) {
            if (feeThresholds[i] == threshold) {
                return true;
            }
        }
        return false;
    }

    // Sort thresholds in ascending order
    function _sortThresholds() internal {
        for (uint256 i = 0; i < feeThresholds.length; i++) {
            for (uint256 j = i + 1; j < feeThresholds.length; j++) {
                if (feeThresholds[i] > feeThresholds[j]) {
                    uint256 temp = feeThresholds[i];
                    feeThresholds[i] = feeThresholds[j];
                    feeThresholds[j] = temp;
                }
            }
        }
    }

    function getThresholds() external view returns (uint256[] memory) {
        return feeThresholds;
    }
}
