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

/**
 * @dev This contract should be inherited by another contract. It makes assumptions that the contract is properly tracking token allocations per user
 **/
contract InterchainRouter is ReentrancyGuard {

    using SafeERC20 for IERC20;

    /// Tokens that failed to transfer properly
    mapping(address => mapping(IERC20 => uint256)) public claimableTokens;

    IInterchainRegistry public interchainRegistry;
    ITokenManagerERC20 public tokenManagerERC20;

    event FailedToWrap(address indexed nativeToken, address indexed wrapper, uint256 indexed amount);
    event ClaimStuckTokens(address indexed user, address indexed token, uint256 indexed amount);

    constructor(IInterchainRegistry _interchainRegistry, ITokenManagerERC20 _tokenManagerERC20) {
        tokenManagerERC20 = _tokenManagerERC20;
        interchainRegistry = _interchainRegistry;
    }

    function _executeInterchainTranfer(address user, address sourceToken, bytes32 destinationChainHash, uint256 amount)
        internal
    {
        if (destinationChainHash == bytes32(0)) {
            return;
        }

        IInterchainRegistry.SupportedToken memory interchainSupportedToken =
            interchainRegistry.getTokenByRoute(destinationChainHash, sourceToken);

        if (!interchainSupportedToken.supported) {
            claimableTokens[user][IERC20(sourceToken)] = amount;
            return;
        }

        address interchainTokenAddress = sourceToken;
        if (interchainSupportedToken.supported && interchainSupportedToken.hasWrapper) {
            _wrapTokens(user, IERC20(sourceToken), IERC20Wrapper(interchainSupportedToken.wrapper), amount);
            interchainTokenAddress = interchainSupportedToken.wrapper;
            IERC20Wrapper(interchainSupportedToken.wrapper).approve(address(tokenManagerERC20), amount);
        }

        tokenManagerERC20.transferToSchainERC20Direct(
            interchainSupportedToken.schainName, interchainTokenAddress, amount, user
        );
    }

    function _wrapTokens(address user, IERC20 sourceToken, IERC20Wrapper wrapper, uint256 amount) internal {
        bool approveSuccess = sourceToken.approve(address(wrapper), amount);
        if (!approveSuccess) {
            claimableTokens[user][sourceToken] = amount;
            return;
        }

        bool depositSuccess = wrapper.depositFor(address(this), amount);
        if (!depositSuccess) {
            claimableTokens[user][sourceToken] = amount;
            return;
        }
    }

    function claimStuckTokens(address to, IERC20 token) external nonReentrant {
        uint256 amount = claimableTokens[to][token];
        if (amount == 0) revert NoTokensAvailable();
        delete claimableTokens[to][token];
        token.safeTransfer(to, amount);

        emit ClaimStuckTokens(msg.sender, address(token), amount);
    }
}
