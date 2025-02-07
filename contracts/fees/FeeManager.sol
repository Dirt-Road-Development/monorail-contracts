// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract FeeManager is AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint256 public constant DEFAULT_FEE = 150; // 1.5% in basis points
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Token configuration struct for custom fees
    struct TokenConfig {
        uint256 fee; // Custom fee in basis points (e.g., 100 = 1%)
        uint256 minThreshold; // Minimum token holding required for custom fee
        address tokenAddress; // The address of the ERC-20, ERC-721, or ERC-1155 token
        uint8 tokenType; // 1 = ERC-20, 2 = ERC-721, 3 = ERC-1155
        uint256 tokenId; // Used for ERC-1155
    }

    // List of tokens with custom fees
    TokenConfig[] public feeTokens;

    // Events
    event TokenFeeConfigured(address tokenAddress, uint256 customFee, uint256 minThreshold, uint8 tokenType);
    event TokenRemoved(address tokenAddress);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function configureTokenFee(
        address tokenAddress,
        uint256 customFee,
        uint256 minThreshold,
        uint256 tokenId,
        uint8 tokenType
    ) external onlyRole(MANAGER_ROLE) {
        require(tokenAddress != address(0), "Invalid token address");
        require(customFee <= FEE_DENOMINATOR, "Fee exceeds 100%");

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

    function removeToken(address tokenAddress) external onlyRole(MANAGER_ROLE) {
        require(tokenAddress != address(0), "Invalid token address");

        uint256 indexToRemove = type(uint256).max;
        uint256 tokensLength = feeTokens.length;

        for (uint256 i = 0; i < tokensLength; i++) {
            if (feeTokens[i].tokenAddress == tokenAddress) {
                indexToRemove = i;
                break;
            }
        }

        require(indexToRemove != type(uint256).max, "Token not found");

        feeTokens[indexToRemove] = feeTokens[feeTokens.length - 1];
        feeTokens.pop();

        emit TokenRemoved(tokenAddress);
    }

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
            require(decimals <= 18, "Token decimals too high");
            require(decimals > 0, "Decimals Can't be 0");
            protocolFee = 10 ** (18 - decimals); // Minimum fee
        }

        require(protocolFee <= amount, "Fee exceeds amount");
        userAmount = amount - protocolFee;
    }

    function getFeeBreakdown(uint256 amount, address user, uint8 decimals)
        external
        view
        returns (uint256 userAmount, uint256 protocolFee)
    {
        return calculateFees(amount, user, decimals);
    }

    function meetsCustomFeeRequirement(address user) public view returns (bool) {
        return getApplicableFee(user) != DEFAULT_FEE;
    }
}
