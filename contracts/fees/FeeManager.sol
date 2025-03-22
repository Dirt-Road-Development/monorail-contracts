// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "../interfaces/IFeeManager.sol";

error FeeExceedsAmount(uint256 fee, uint256 amount);
error InvalidTokenAddress();
error FeeExceedsMaximum(uint256 fee, uint256 maximum);
error TokenNotFound();
error DecimalsTooHigh(uint8 decimals, uint8 maximum);
error DecimalsCannotBeZero();

/**
 * @title FeeManager
 * @author Monorail
 * @notice Manages fee calculations and discounts for protocol users based on token holdings
 * @dev Implements variable fee structures based on ERC20, ERC721, and ERC1155 token holdings
 */
contract FeeManager is IFeeManager, AccessControl {
    /**
     * @notice Role identifier for accounts that can manage fee configurations
     */
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    /**
     * @notice Default fee rate in basis points (1.5%)
     */
    uint256 public constant DEFAULT_FEE = 150; // 1.5% in basis points
    
    /**
     * @notice Denominator used for fee calculations (10000 = 100%)
     */
    uint256 public constant FEE_DENOMINATOR = 10000;

    /**
     * @notice Token configuration struct for custom fees
     * @dev Stores all information related to token-based fee discounts
     */
    struct TokenConfig {
        uint256 fee; // Custom fee in basis points (e.g., 100 = 1%)
        uint256 minThreshold; // Minimum token holding required for custom fee
        address tokenAddress; // The address of the ERC-20, ERC-721, or ERC-1155 token
        uint8 tokenType; // 1 = ERC-20, 2 = ERC-721, 3 = ERC-1155
        uint256 tokenId; // Used for ERC-1155
    }

    /**
     * @notice List of tokens with custom fees
     */
    TokenConfig[] public feeTokens;

    /**
     * @notice Emitted when a token fee configuration is added or modified
     * @param tokenAddress Address of the token being configured
     * @param customFee Custom fee rate in basis points
     * @param minThreshold Minimum token holding required for discount
     * @param tokenType Type of token (1=ERC20, 2=ERC721, 3=ERC1155)
     */
    event TokenFeeConfigured(address tokenAddress, uint256 customFee, uint256 minThreshold, uint8 tokenType);

    /**
     * @notice Initializes the contract and sets up the admin role
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Adds or updates a token configuration for fee discounts
     * @dev Only callable by accounts with MANAGER_ROLE
     * @param tokenAddress Address of the token
     * @param customFee Custom fee rate in basis points
     * @param minThreshold Minimum token holding required for discount
     * @param tokenId Token ID (used for ERC1155)
     * @param tokenType Type of token (1=ERC20, 2=ERC721, 3=ERC1155)
     */
    function configureTokenFee(
        address tokenAddress,
        uint256 customFee,
        uint256 minThreshold,
        uint256 tokenId,
        uint8 tokenType
    ) external onlyRole(MANAGER_ROLE) {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        if (customFee > FEE_DENOMINATOR) revert FeeExceedsMaximum(customFee, FEE_DENOMINATOR);

        feeTokens.push(
            TokenConfig({
                fee: customFee,
                minThreshold: minThreshold,
                tokenAddress: tokenAddress,
                tokenType: tokenType,
                tokenId: tokenId
            })
        );

        emit TokenFeeConfigured(tokenAddress, customFee, minThreshold, tokenType);
    }

    /**
     * @notice Removes a token from the fee configuration
     * @dev Only callable by accounts with MANAGER_ROLE
     * @param tokenAddress Address of the token to remove
     */
    function removeToken(address tokenAddress) external onlyRole(MANAGER_ROLE) {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();

        uint256 indexToRemove = type(uint256).max;
        uint256 tokensLength = feeTokens.length;

        for (uint256 i = 0; i < tokensLength; i++) {
            if (feeTokens[i].tokenAddress == tokenAddress) {
                indexToRemove = i;
                break;
            }
        }

        if (indexToRemove == type(uint256).max) revert TokenNotFound();

        feeTokens[indexToRemove] = feeTokens[feeTokens.length - 1];
        feeTokens.pop();

        emit TokenRemoved(tokenAddress);
    }

    /**
     * @notice Determines the applicable fee rate for a user based on their token holdings
     * @dev Checks all configured tokens and returns the lowest qualifying fee
     * @param user Address of the user to check
     * @return The applicable fee rate in basis points
     */
    function getApplicableFee(address user) public view returns (uint256) {
        uint256 applicableFee = DEFAULT_FEE;
        uint256 feeTokensLength = feeTokens.length;
        for (uint256 i = 0; i < feeTokensLength; i++) {
            TokenConfig memory config = feeTokens[i];
            bool meetsThreshold = false;

            if (config.tokenType == 1) {
                // ERC-20
                uint256 balance = IERC20(config.tokenAddress).balanceOf(user);
                meetsThreshold = balance >= config.minThreshold;
            } else if (config.tokenType == 2) {
                // ERC-721
                uint256 balance = IERC721(config.tokenAddress).balanceOf(user);
                meetsThreshold = balance >= config.minThreshold;
            } else if (config.tokenType == 3) {
                // ERC-1155
                uint256 balance = IERC1155(config.tokenAddress).balanceOf(user, config.tokenId);
                meetsThreshold = balance >= config.minThreshold;
            }

            if (meetsThreshold) {
                applicableFee = config.fee;
                break; // Use the first qualifying custom fee
            }
        }

        return applicableFee;
    }

    /**
     * @notice Calculates fee amounts for a given transfer
     * @dev Internal implementation of getFeeBreakdown
     * @param amount Total transfer amount
     * @param user Address of the user making the transfer
     * @param decimals Token decimals
     * @return userAmount Amount that will be received by the user
     * @return protocolFee Amount taken as protocol fee
     */
    function calculateFees(uint256 amount, address user, uint8 decimals)
        public
        view
        returns (uint256 userAmount, uint256 protocolFee)
    {
        uint256 feePercentage = getApplicableFee(user);

        // Calculate protocol fee in basis points
        protocolFee = (amount * feePercentage) / FEE_DENOMINATOR;

        // Ensure minimum fee for non-zero amounts
        if (protocolFee == 0 && amount > 0) {
            if (decimals > 18) revert DecimalsTooHigh(decimals, 18);
            if (decimals == 0) revert DecimalsCannotBeZero();
            protocolFee = 10 ** (18 - decimals); // Minimum fee
        }

        if (protocolFee > amount) revert FeeExceedsAmount(protocolFee, amount);
        userAmount = amount - protocolFee;
    }

    /**
     * @notice Gets the breakdown of a transfer amount into user amount and protocol fee
     * @param amount Total amount being transferred
     * @param user Address of the user making the transfer
     * @param decimals Token decimals
     * @return userAmount Amount that will be received by the user
     * @return protocolFee Amount taken as protocol fee
     */
    function getFeeBreakdown(uint256 amount, address user, uint8 decimals)
        external
        view
        returns (uint256 userAmount, uint256 protocolFee)
    {
        return calculateFees(amount, user, decimals);
    }

    /**
     * @notice Checks if a user meets any custom fee requirement
     * @param user Address of the user to check
     * @return Boolean indicating whether user qualifies for a custom fee
     */
    function meetsCustomFeeRequirement(address user) public view returns (bool) {
        return getApplicableFee(user) != DEFAULT_FEE;
    }
}