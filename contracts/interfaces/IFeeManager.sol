// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;
import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IFeeManager
 * @dev Interface for managing fee configurations and calculations in the protocol.
 * Extends OpenZeppelin's IAccessControl for role-based access control.
 */
interface IFeeManager is IAccessControl {
    // Events
    /**
     * @dev Emitted when a new token is added to the fee configuration.
     * @param tokenAddress The address of the token being configured
     * @param baseFee The base fee percentage applied to transfers
     * @param discountedFee The discounted fee percentage for qualifying users
     * @param minThreshold The minimum amount of tokens required to qualify for the discount
     * @param tokenType The type of token (e.g., ERC20, ERC721, etc.)
     */
    event TokenAdded(
        address tokenAddress, uint256 baseFee, uint256 discountedFee, uint256 minThreshold, uint8 tokenType
    );

    /**
     * @dev Emitted when a token is removed from the fee configuration.
     * @param tokenAddress The address of the token being removed
     */
    event TokenRemoved(address tokenAddress);

    /**
     * @dev Configures fee parameters for a specific token.
     * @param tokenAddress The address of the token to configure
     * @param customFee The custom fee percentage to apply for this token
     * @param minThreshold The minimum amount of tokens required to qualify for discounts
     * @param tokenId The ID of the token (relevant for NFTs or token collections)
     * @param tokenType The type of token being configured (e.g., ERC20, ERC721)
     */
    function configureTokenFee(
        address tokenAddress,
        uint256 customFee,
        uint256 minThreshold,
        uint256 tokenId,
        uint8 tokenType
    ) external;

    /**
     * @dev Removes a token from the fee configuration.
     * @param tokenAddress The address of the token to remove
     */
    function removeToken(address tokenAddress) external;

    /**
     * @dev Calculates the highest discount a user is eligible for based on tokens they own.
     * @param user The address of the user to check
     * @return The applicable fee percentage for the user
     */
    function getApplicableFee(address user) external view returns (uint256);

    /**
     * @dev Calculates the breakdown of a transfer amount into user amount and protocol fee.
     * @param amount The total amount being transferred
     * @param user The address of the user making the transfer
     * @param decimals The number of decimals for the token being transferred
     * @return userAmount The amount that will be received by the user after fees
     * @return protocolFee The amount that will be taken as protocol fee
     */
    function getFeeBreakdown(uint256 amount, address user, uint8 decimals)
        external
        view
        returns (uint256 userAmount, uint256 protocolFee);

    /**
     * @dev Checks if a user meets the minimum requirements for custom fee discounts.
     * @param user The address of the user to check
     * @return A boolean indicating whether the user qualifies for discounted fees
     */
    function meetsCustomFeeRequirement(address user) external view returns (bool);
}