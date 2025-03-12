// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IInterchainRegistry} from "../interfaces/IInterchainRegistry.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITokenManagerERC20} from "../interfaces/ITokenManagerERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error FailedToUnwrap();

contract InterchainRouter is ReentrancyGuard {

	using SafeERC20 for IERC20;
	
	IInterchainRegistry public interchainRegistry;
	ITokenManagerERC20 public tokenManagerERC20;

	event FailedToWrap(address indexed nativeToken, address indexed wrapper, uint256 indexed amount);

	constructor(IInterchainRegistry _interchainRegistry) {
		tokenManagerERC20 = ITokenManagerERC20(0xD2aAA00500000000000000000000000000000000);
		interchainRegistry = _interchainRegistry;
	}
	
	function executeInterchainTranfer(address user, address sourceToken, bytes32 destinationChainHash, uint256 amount) public nonReentrant {
		
		if (destinationChainHash == bytes32(0)) {
			return;	
		}

		IInterchainRegistry.SupportedToken memory interchainSupportedToken = interchainRegistry.getTokenByRoute(destinationChainHash, sourceToken);
		
		if (!interchainSupportedToken.supported) {
			IERC20(sourceToken).safeTransfer(user, amount);
			return;
		}

		if (interchainSupportedToken.supported && interchainSupportedToken.hasWrapper) {
			_wrapTokens(user, IERC20(sourceToken), IERC20Wrapper(interchainSupportedToken.wrapper), amount);
		}

		tokenManagerERC20.transferToSchainERC20Direct(
			interchainSupportedToken.schainName,
			sourceToken,
			amount,
			user
		);
	}
	

	function _wrapTokens(address user, IERC20 sourceToken, IERC20Wrapper wrapper, uint256 amount) internal returns (bool) {
        bool success = wrapper.depositFor(address(this), amount);
        if (!success) {
            emit FailedToWrap(address(sourceToken), address(wrapper), amount);
            sourceToken.safeTransfer(user, amount);
        }
    }

    function _unwrapTokens(address user, IERC20Wrapper wrapper, uint256 amount) internal {
    	bool success = wrapper.withdrawTo(address(this), amount);
    	if (!success) {
    		revert FailedToUnwrap();
    	}
    	
    	wrapper.underlying().safeTransfer(user, amount);
    }
}