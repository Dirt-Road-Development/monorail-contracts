// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

/// @title Monorail OFT
/// @notice Base Contract for Monorail OFT
/// @dev Implements the ERC20 and the Omnichain Fungible Token (OFT) standards.
/// @author TheGreatAxios - <thegreataxios@dirtroad.dev>
contract MonorailOFT is OFT, AccessControl {
    
    using SafeERC20 for IERC20;

    /// @dev Error used to handle cases where the native ERC20 token 
    ///      for fee payment is not set in the EndpointV2Alt contract
    error LzAltTokenUnavailable();

    constructor(
        string memory _name,
        string memory _symbol,
        address _layerZeroEndpoint
    )  OFT(_name, _symbol, _layerZeroEndpoint, _msgSender()) Ownable(_msgSender()) {
            _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }

    function withdrawStuckTokens(IERC20 token) 
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        token.safeTransferFrom(address(this), _msgSender(), token.balanceOf(address(this)));
    }


    /**
     * @dev Internal function to interact with the LayerZero EndpointV2.send() for sending a message.
     * @param _dstEid The destination endpoint ID.
     * @param _message The message payload.
     * @param _options Additional options for the message.
     * @param _fee The calculated LayerZero fee for the message.
     *      - nativeFee: The native fee.
     *      - lzTokenFee: The lzToken fee.
     * @param _refundAddress The address to receive any excess fee values sent to the endpoint.
     * @return receipt The receipt for the sent message.
     *      - guid: The unique identifier for the sent message.
     *      - nonce: The nonce of the sent message.
     *      - fee: The LayerZero fee incurred for the message.
     */
    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal virtual override returns (MessagingReceipt memory receipt) 
    {
        // Push corresponding fees to the endpoint, any excess is sent back to the _refundAddress from the endpoint
        _payNative(_fee.nativeFee);
        if (_fee.lzTokenFee > 0)
        {
            _payLzToken(_fee.lzTokenFee);
        }

        return
            // solhint-disable-next-line check-send-result
            endpoint.send(
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0),
                _refundAddress
            );
    }


    /// @dev Internal function to pay the alt token fee associated with the message
    /// @param _nativeFee The alt token fee to be paid
    /// @return nativeFee The amount of native currency paid
    /// @dev If the OApp needs to initiate MULTIPLE LayerZero messages in a single transaction,
    ///      this will need to be overridden because alt token would contain multiple lzFees
    function _payNative(uint _nativeFee) 
        internal virtual override returns(uint nativeFee) 
    {
        address nativeErc20 = endpoint.nativeToken();
        if (nativeErc20 == address(0)) 
        {
            revert LzAltTokenUnavailable();
        }

        // Pay Alt token fee by sending tokens to the endpoint
        IERC20(nativeErc20).safeTransferFrom(
            msg.sender, address(endpoint), _nativeFee);

        return 0;
    }
}