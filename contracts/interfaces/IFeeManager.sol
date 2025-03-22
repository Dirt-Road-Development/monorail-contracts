// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IFeeManager is IAccessControl {
    // Events
    event TokenAdded(
        address tokenAddress, uint256 baseFee, uint256 discountedFee, uint256 minThreshold, uint8 tokenType
    );
    event TokenRemoved(address tokenAddress);

    // Functions to add and remove token configurations
    function configureTokenFee(
        address tokenAddress,
        uint256 customFee,
        uint256 minThreshold,
        uint256 tokenId,
        uint8 tokenType
    ) external;

    function removeToken(address tokenAddress) external;

    // Function to calculate the highest discount for a user based on owned tokens
    function getApplicableFee(address user) external view returns (uint256);

    // Function to calculate the fee breakdown for a specific transfer
    function getFeeBreakdown(uint256 amount, address user, uint8 decimals)
        external
        view
        returns (uint256 userAmount, uint256 protocolFee);

    // Helper function to check if the user meets the minimum requirement for the discount
    function meetsCustomFeeRequirement(address user) external view returns (bool);
}
