// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IMonorailNativeToken } from "../interfaces/IMonorailNativeToken.sol";
import { OApp, MessagingReceipt, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { LibFeeCalculatorV1 } from "../lib/LibFeeCalculatorV1.sol";
import { LibTypesV1 } from "../lib/LibTypesV1.sol";

error LzAltTokenUnavailable();

contract SKALEStation is OApp, AccessControl, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using SafeERC20 for IMonorailNativeToken;

    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address private feeCollector;
    address private liquidityCollector;
    address private withdrawlAccount;

    mapping(IMonorailNativeToken => uint256) public supplyAvailable;

    // LayerZero Chain Id => Origin Token => Local Native Token
    mapping(uint32 => mapping(address => IMonorailNativeToken)) public tokens;
    // Native Token => Supported Bool
    mapping(IMonorailNativeToken => mapping(uint32 => bool)) public supported;

    event AddToken(uint32 indexed layerZeroEndpointId, address indexed originTokenAddress, address indexed localTokenAddress);
    event BridgeReceived(address indexed token, address indexed to, uint256 indexed amount);
    event Withdrawal(address indexed withdrawer, uint256 indexed amount);

    constructor(
        address _layerZeroEndpoint,
        address _feeCollector,
        address _liquidityCollector
    ) OApp(_layerZeroEndpoint, _msgSender()) Ownable(_msgSender()) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(WITHDRAW_ROLE, _msgSender());

        if (_feeCollector == address(0)) {
            revert("Fee Collector Address Must Not Be 0");
        }

        if (_liquidityCollector == address(0)) {
            revert("Fee Collector Address Must Not Be 0");
        }

        // Set Fee Collector. If failed to set will revert when minting
        feeCollector = _feeCollector;
        liquidityCollector = _liquidityCollector;
        withdrawlAccount = _liquidityCollector;
    }

    function addToken(
        uint32 layerZeroEndpointId,
        address originTokenAddress,
        address localTokenAddress
    ) external onlyRole(MANAGER_ROLE) {

        if (address(tokens[layerZeroEndpointId][originTokenAddress]) != address(0)) {
            revert("Token Already Added + Active");
        }

        IMonorailNativeToken localToken = IMonorailNativeToken(localTokenAddress);
        tokens[layerZeroEndpointId][originTokenAddress] = localToken;
        supported[localToken][layerZeroEndpointId] = true;

        emit AddToken(layerZeroEndpointId, originTokenAddress, localTokenAddress);
    }

    function bridge(
        uint32 destinationLayerZeroEndpointId,
        LibTypesV1.TokenType tokenType,
        LibTypesV1.TripDetails memory details,
        MessagingFee memory fee,
        bytes calldata options
    ) nonReentrant external returns (MessagingReceipt memory receipt) {
        if (tokenType == LibTypesV1.TokenType.Native) {

            IMonorailNativeToken nativeToken = IMonorailNativeToken(details.token);

            // 1. Validate Token is Supported
            if (!supported[nativeToken][destinationLayerZeroEndpointId]) {
                revert("Token Not Supported");
            }

            // 2. Calculate FeeBreakdown
            LibFeeCalculatorV1.FeeBreakdown memory fees = LibFeeCalculatorV1.calculateFees(details.amount, nativeToken.decimals());
            
            // 3. User Transfers Tokens to Contract
            nativeToken.safeTransferFrom(_msgSender(), address(this), details.amount);

            // 4. Burn Native Tokens that will be unlocked on destination
            nativeToken.burn(fees.userAmount);

            // 5. Reduce Supply by Burn Token Amount
            supplyAvailable[nativeToken] -= fees.userAmount;

            // 6. Transfer Fees to Fee Collector + Liquidity Collector
            nativeToken.safeTransfer(feeCollector, fees.platformFee);
            nativeToken.safeTransfer(liquidityCollector, fees.liquidityFee);

            // 7. Send LZ Message -> Reminder MUST APPROVE SKL Token for Proper Fee Amount
            bytes memory _payload = abi.encode(details.token, details.to, details.amount);        
            receipt = _lzSend(destinationLayerZeroEndpointId, _payload, options, fee, msg.sender);

        } else if (tokenType == LibTypesV1.TokenType.OFT) {
            revert("OFT Type Not Supported");
        } else {
            revert("Invalid Transfer Type");   
        }
    }

    function quote(
        uint32 _dstEid,
        LibTypesV1.TripDetails memory _tripDetails,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_tripDetails);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
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

        LibFeeCalculatorV1.FeeBreakdown memory fees = LibFeeCalculatorV1.calculateFees(amount, nativeToken.decimals());
        
        nativeToken.mint(to, fees.userAmount);
        nativeToken.mint(feeCollector, fees.platformFee);
        nativeToken.mint(liquidityCollector, fees.liquidityFee);

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

    // sFUEL Management
        // Function to withdraw Ether from the contract
    function withdraw(uint256 amount) external onlyRole(WITHDRAW_ROLE) {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(withdrawlAccount).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawal(withdrawlAccount, amount);
    }

    receive() external payable {}


}