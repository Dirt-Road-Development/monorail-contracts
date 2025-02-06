// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IFeeManager {
    // Events
    event TokenAdded(
        address tokenAddress, uint256 baseFee, uint256 discountedFee, uint256 minThreshold, uint8 tokenType
    );
    event TokenRemoved(address tokenAddress);

    // Functions to add and remove token configurations
    function addToken(
        address tokenAddress,
        uint256 baseFee,
        uint256 discountedFee,
        uint256 minThreshold,
        uint8 tokenType, // 1 = ERC-20, 2 = ERC-721, 3 = ERC-1155
        uint256 tokenId // Used for ERC-721 (specific tokenId) or ERC-1155 (tokenId + required amount)
    ) external;

    function removeToken(address tokenAddress) external;

    // Function to calculate the highest discount for a user based on owned tokens
    function getHighestDiscount(address user) external view returns (uint256);

    // Function to calculate the fee breakdown for a specific transfer
    function getFeeBreakdown(address tokenAddress, uint256 amount, address user)
        external
        view
        returns (uint256 userAmount, uint256 protocolFee);

    // Helper function to check if the user meets the minimum requirement for the discount
    function meetsMinimumRequirement(address user) external view returns (bool);
}
