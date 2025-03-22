// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IInterchainRegistry} from "../interfaces/IInterchainRegistry.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITokenManagerERC20} from "../interfaces/ITokenManagerERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error FailedToUnwrap();

/**
 * @dev This contract should be inherited by another contract. It makes assumptions that the contract is properly tracking token allocations per user
 **/
abstract contract InterchainRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IInterchainRegistry public interchainRegistry;
    ITokenManagerERC20 public tokenManagerERC20;

    event FailedToWrap(address indexed nativeToken, address indexed wrapper, uint256 indexed amount);

    constructor(IInterchainRegistry _interchainRegistry, ITokenManagerERC20 _tokenManagerERC20) {
        tokenManagerERC20 = _tokenManagerERC20;
        interchainRegistry = _interchainRegistry;
    }

    function executeInterchainTranfer(address user, address sourceToken, bytes32 destinationChainHash, uint256 amount)
        public
        nonReentrant
    {
        if (destinationChainHash == bytes32(0)) {
            return;
        }

        IInterchainRegistry.SupportedToken memory interchainSupportedToken =
            interchainRegistry.getTokenByRoute(destinationChainHash, sourceToken);

        if (!interchainSupportedToken.supported) {
            IERC20(sourceToken).safeTransfer(user, amount);
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
            emit FailedToWrap(address(sourceToken), address(wrapper), amount);
            sourceToken.safeTransfer(user, amount);
        }
        bool depositSuccess = wrapper.depositFor(address(this), amount);
        if (!depositSuccess) {
            emit FailedToWrap(address(sourceToken), address(wrapper), amount);
            sourceToken.safeTransfer(user, amount);
        }
    }

    // function _unwrapTokens(address user, IERC20Wrapper wrapper, uint256 amount) internal {
    //     bool success = wrapper.withdrawTo(address(this), amount);
    //     if (!success) {
    //         revert FailedToUnwrap();
    //     }

    //     wrapper.underlying().safeTransfer(user, amount);
    // }
}
