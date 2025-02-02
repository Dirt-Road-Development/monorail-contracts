// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { OApp, MessagingReceipt, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMonorailNativeToken } from "./interfaces/IMonorailNativeToken.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error LzAltTokenUnavailable();

abstract contract SKALEOApp is OApp {
    using SafeERC20 for IERC20;
    using SafeERC20 for IMonorailNativeToken;

    event Withdrawal(address indexed withdrawer, uint256 indexed amount);

    constructor(address _layerZeroEndpoint) OApp(_layerZeroEndpoint, _msgSender()) Ownable(_msgSender()) {}

    /**
     *
     */
    /**
     *
     */
    /*                       Required Overrides for SKALE. DO NOT REMOVE BELOW.                */
    /**
     *
     */
    /**
     *
     */
    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal virtual override returns (MessagingReceipt memory receipt) {
        // Push corresponding fees to the endpoint, any excess is sent back to the _refundAddress from the endpoint
        _payNative(_fee.nativeFee);
        if (_fee.lzTokenFee > 0) {
            _payLzToken(_fee.lzTokenFee);
        }

        return
            endpoint.send(
                // solhint-disable-next-line check-send-result
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0),
                _refundAddress
            );
    }

    /// @dev Internal function to pay the alt token fee associated with the message
    /// @param _nativeFee The alt token fee to be paid
    /// @return nativeFee The amount of native currency paid
    /// @dev If the OApp needs to initiate MULTIPLE LayerZero messages in a single transaction,
    ///      this will need to be overridden because alt token would contain multiple lzFees
    function _payNative(uint256 _nativeFee) internal virtual override returns (uint256 nativeFee) {
        address nativeErc20 = endpoint.nativeToken();
        if (nativeErc20 == address(0)) {
            revert LzAltTokenUnavailable();
        }

        // Pay Alt token fee by sending tokens to the endpoint
        IERC20(nativeErc20).safeTransferFrom(msg.sender, address(endpoint), _nativeFee);

        return 0;
    }

    // sFUEL Management
    // Function to withdraw Ether from the contract
    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");

        emit Withdrawal(owner(), amount);

        payable(owner()).transfer(amount);
    }

    receive() external payable {}
}
