// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IMonorailNativeToken } from "../interfaces/IMonorailNativeToken.sol";
import { OApp, MessagingReceipt, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FeeManager } from "./FeeManager.sol";

error LzAltTokenUnavailable();

contract SKALEStation is OApp, FeeManager {

    struct TripDetails {
        address token;
        address to;
        uint256 amount;
    }

    using SafeERC20 for IERC20;

    bytes32 public MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address private feeCollector;
    mapping(IMonorailNativeToken => uint256) public supplyAvailable;

    // LayerZero Chain Id => Origin Token => Local Native Token
    mapping(uint32 => mapping(address => IMonorailNativeToken)) public tokens;
    mapping(IMonorailNativeToken => bool) public stable;

    event AddToken(uint32 indexed layerZeroEndpointId, address indexed originTokenAddress, address indexed localTokenAddress);
    event BridgeReceived(address indexed token, address indexed to, uint256 indexed amount);

    constructor(
        address _layerZeroEndpoint,
        address _feeCollector,
        address owner
    ) OApp(_layerZeroEndpoint, _msgSender()) Ownable(owner) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MANAGER_ROLE, _msgSender());

        // Set Fee Collector. If failed to set will revert when minting
        feeCollector = _feeCollector;
    }

    function addToken(
        uint32 layerZeroEndpointId,
        address originTokenAddress,
        address localTokenAddress,
        bool isStable
    ) external onlyRole(MANAGER_ROLE) {

        if (address(tokens[layerZeroEndpointId][originTokenAddress]) != address(0)) {
            revert("Token Already Added + Active");
        }

        IMonorailNativeToken localToken = IMonorailNativeToken(localTokenAddress);
        tokens[layerZeroEndpointId][originTokenAddress] = localToken;
        stable[localToken] = isStable;

        emit AddToken(layerZeroEndpointId, originTokenAddress, localTokenAddress);
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
        (address token, address to, uint256 amount) = abi.decode(payload, (address,address,uint256)); // TripDetails

        IMonorailNativeToken nativeToken = tokens[_origin.srcEid][token];

        FeeDistribution memory fees = calculateFees(amount, nativeToken.decimals());
        
        nativeToken.mint(to, fees.userAmount);
        // nativeToken.mint(feeCollector, fees.platformFee);
        // nativeToken.mint(feeCollector, fees.liquidityFee);

        supplyAvailable[nativeToken] += amount;

        emit BridgeReceived(address(nativeToken), to, fees.userAmount);
    }

    /*******************************************************************************************/
    /*******************************************************************************************/
    /*                       Required Overrides for SKALE. DO NOT REMOVE BELOW.                */
    /*******************************************************************************************/
    /*******************************************************************************************/
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