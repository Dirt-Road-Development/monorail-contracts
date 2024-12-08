// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IFeeManager {
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

    // Events
    event FeeTierUpdated(uint256 threshold, FeeRates rates);
    event FeeTierRemoved(uint256 threshold);
    event NonStableTokenFeesUpdated(FeeRates rates);

    // View Functions
    function calculateStablecoinFees(uint256 amount) external view returns (Fees memory);
    function calculateNonStableTokenFees(uint256 amount) external view returns (Fees memory);
    function getStablecoinFeeRates(uint256 amount) external view returns (FeeRates memory);
    function stablecoinFeeTiers(uint256 threshold) external view returns (FeeRates memory);
    function nonStableTokenFees() external view returns (FeeRates memory);
    function feeThresholds(uint256 index) external view returns (uint256);
    function feeThresholdsLength() external view returns (uint256);

    // Mutative Functions
    function updateFeeTier(uint256 threshold, FeeRates memory rates) external;
    function removeFeeTier(uint256 threshold) external;
    function updateNonStableTokenFees(FeeRates memory rates) external;
}
