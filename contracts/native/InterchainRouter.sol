// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;
import {IInterchainRegistry} from "../interfaces/IInterchainRegistry.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITokenManagerERC20} from "../interfaces/ITokenManagerERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error FailedToUnwrap();
error NoTokensAvailable();
error InvalidParameters();
error RegistryInitFailed();
error TokenManagerInitFailed();

/**
 * @title InterchainRouter
 * @author Monorail
 * @notice Facilitates token transfers between different chains in a cross-chain environment
 * @dev This contract should be inherited by another contract. It makes assumptions that the contract is properly tracking token allocations per user
 */
contract InterchainRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @notice Mapping of tokens that failed to transfer properly and can be claimed later
     * @dev Maps user address -> token address -> claimable amount
     */
    mapping(address => mapping(IERC20 => uint256)) public claimableTokens;

    /**
     * @notice Interface for checking supported tokens across chains
     */
    IInterchainRegistry public interchainRegistry;

    /**
     * @notice Interface for managing token transfers across chains
     */
    ITokenManagerERC20 public tokenManagerERC20;

    /**
     * @notice Emitted when a token wrapping operation fails
     * @param nativeToken Address of the original token
     * @param wrapper Address of the wrapper contract
     * @param amount Amount that failed to wrap
     */
    event FailedToWrap(address indexed nativeToken, address indexed wrapper, uint256 indexed amount);

    /**
     * @notice Emitted when stuck tokens are claimed
     * @param user Address of the user claiming tokens
     * @param token Address of the token being claimed
     * @param amount Amount of tokens claimed
     */
    event ClaimStuckTokens(address indexed user, address indexed token, uint256 indexed amount);

    /**
     * @notice Initializes the InterchainRouter with required dependencies
     * @param _interchainRegistry Address of the interchain registry contract
     * @param _tokenManagerERC20 Address of the token manager contract
     * @dev Sets up the core components needed for interchain transfers
     */
    constructor(IInterchainRegistry _interchainRegistry, ITokenManagerERC20 _tokenManagerERC20) {
        if (address(_tokenManagerERC20) == address(0)) revert TokenManagerInitFailed();
        if (address(_interchainRegistry) == address(0)) revert RegistryInitFailed();
        
        tokenManagerERC20 = _tokenManagerERC20;
        interchainRegistry = _interchainRegistry;
    }

    /**
     * @notice Executes a token transfer across chains
     * @dev Internal function to be called by inheriting contracts
     * @param user Address of the user initiating the transfer
     * @param sourceToken Address of the token being transferred
     * @param destinationChainHash Identifier hash of the destination chain
     * @param amount Amount of tokens to transfer
     */
    function _executeInterchainTranfer(address user, address sourceToken, bytes32 destinationChainHash, uint256 amount)
        internal
    {
        if (user == address(0) || sourceToken == address(0) || amount == 0) revert InvalidParameters();
        
        // If destination chain is not specified, do nothing
        if (destinationChainHash == bytes32(0)) {
            return;
        }
        
        IInterchainRegistry.SupportedToken memory interchainSupportedToken =
            interchainRegistry.getTokenByRoute(destinationChainHash, sourceToken);
            
        // If token is not supported on destination chain, store for later claiming
        if (!interchainSupportedToken.supported) {
            claimableTokens[user][IERC20(sourceToken)] = amount;
            return;
        }
        
        address interchainTokenAddress = sourceToken;
        
        // If token needs wrapping before transfer
        if (interchainSupportedToken.supported && interchainSupportedToken.hasWrapper) {
            _wrapTokens(user, IERC20(sourceToken), IERC20Wrapper(interchainSupportedToken.wrapper), amount);
            interchainTokenAddress = interchainSupportedToken.wrapper;
            IERC20Wrapper(interchainSupportedToken.wrapper).approve(address(tokenManagerERC20), amount);
        }
        
        // Execute the cross-chain transfer
        tokenManagerERC20.transferToSchainERC20Direct(
            interchainSupportedToken.schainName, interchainTokenAddress, amount, user
        );
    }

    /**
     * @notice Wraps tokens before interchain transfer
     * @dev Handles failures gracefully by storing tokens for later claiming
     * @param user Address of the user who will be able to claim tokens if wrapping fails
     * @param sourceToken Original token to be wrapped
     * @param wrapper Wrapper contract interface
     * @param amount Amount of tokens to wrap
     */
    function _wrapTokens(address user, IERC20 sourceToken, IERC20Wrapper wrapper, uint256 amount) internal {
        bool approveSuccess = sourceToken.approve(address(wrapper), amount);
        if (!approveSuccess) {
            claimableTokens[user][sourceToken] = amount;
            emit FailedToWrap(address(sourceToken), address(wrapper), amount);
            return;
        }
        
        bool depositSuccess = wrapper.depositFor(address(this), amount);
        if (!depositSuccess) {
            claimableTokens[user][sourceToken] = amount;
            emit FailedToWrap(address(sourceToken), address(wrapper), amount);
            return;
        }
    }

    /**
     * @notice Allows users to claim tokens that failed to transfer in previous operations
     * @param to Address to send the claimed tokens
     * @param token Token to claim
     */
    function claimStuckTokens(address to, IERC20 token) external nonReentrant {
        if (to == address(0)) revert InvalidParameters();
        
        uint256 amount = claimableTokens[to][token];
        if (amount == 0) revert NoTokensAvailable();
        
        delete claimableTokens[to][token];
        token.safeTransfer(to, amount);
        emit ClaimStuckTokens(msg.sender, address(token), amount);
    }
}