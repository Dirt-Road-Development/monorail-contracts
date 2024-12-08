// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { Station } from "../evm/Station.sol";
import { IMonorailNativeToken } from "../interfaces/IMonorailNativeToken.sol";
import { MessagingReceipt, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error LzAltTokenUnavailable();

contract SKALEStation is Station {

    using SafeERC20 for IERC20;

    // Chain Id => From Chain Token => SKALE Chain Token
    mapping(uint32 => mapping(address => address)) public tokensByChain;

    function mapToken(
        uint32 fromChain,
        address fromToken,
        address skaleToken
    ) external onlyRole(MANAGER_ROLE) {
        if (tokensByChain[fromChain][fromToken] != address(0)) revert("Token already Setup");
        tokensByChain[fromChain][fromToken] = skaleToken;
    }

    constructor(
        address _endpoint,
        address _feeManager,
        address _feeCollector
    ) Station(_endpoint, _feeManager, _feeCollector) {}

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

    /**
     * @dev Called when data is received from the protocol. It overrides the equivalent function in the parent contract.
     * Protocol messages are defined as packets, comprised of the following parameters.
     * @param _origin A struct containing information about where the packet came from.
     * @param _guid A global unique identifier for tracking the packet.
     * @param payload Encoded message.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address,  // Executor address as specified by the OApp.
        bytes calldata  // Any extra data or options to trigger on receipt.
    ) internal virtual override {
        // Decode the payload to get the message
        // In this case, type is string, but depends on your encoding!
        TripDetails memory details = abi.decode(payload, (TripDetails));
        address skaleTokenAddress = tokensByChain[_origin.srcEid][details.token];

        IMonorailNativeToken(skaleTokenAddress).mint(details.recipientAddress, details.amount);

    }   
}