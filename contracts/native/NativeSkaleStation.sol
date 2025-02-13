// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IMonorailNativeToken} from "../interfaces/IMonorailNativeToken.sol";
import {MessagingReceipt, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {LibTypesV1} from "../lib/LibTypesV1.sol";
import {SKALEOApp} from "../SKALEOApp.sol";

contract NativeSkaleStation is SKALEOApp, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IMonorailNativeToken;

    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address private feeCollector;
    IFeeManager public feeManager;

    mapping(IMonorailNativeToken => uint256) public supplyAvailable;

    // LayerZero Chain Id => Origin Token => Local Native Token
    mapping(uint32 => mapping(address => IMonorailNativeToken)) public tokens;
    // Native Token => Supported Bool
    mapping(IMonorailNativeToken => mapping(uint32 => bool)) public supported;

    event AddToken(
        uint32 indexed layerZeroEndpointId, address indexed originTokenAddress, address indexed localTokenAddress
    );
    event BridgeReceived(address indexed token, address indexed to, uint256 indexed amount);

    constructor(address _layerZeroEndpoint, address _feeCollector, IFeeManager _feeManager)
        SKALEOApp(_layerZeroEndpoint)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(WITHDRAW_ROLE, _msgSender());

        if (_feeCollector == address(0)) {
            revert("Fee Collector Address Must Not Be 0");
        }

        // Set Fee Collector. If failed to set will revert when minting
        feeCollector = _feeCollector;
        feeManager = _feeManager;
    }

    function addToken(uint32 layerZeroEndpointId, address originTokenAddress, address localTokenAddress)
        external
        onlyRole(MANAGER_ROLE)
    {
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
        LibTypesV1.TripDetails memory details,
        MessagingFee memory fee,
        bytes calldata options
    ) external nonReentrant returns (MessagingReceipt memory receipt) {
        IMonorailNativeToken nativeToken = IMonorailNativeToken(details.token);

        // 1. Validate Token is Supported
        if (!supported[nativeToken][destinationLayerZeroEndpointId]) {
            revert("Token Not Supported");
        }

        // 2. Calculate FeeBreakdown
        // LibFeeCalculatorV1.FeeBreakdown memory fees = LibFeeCalculatorV1.calculateFees(
        //     details.amount,
        //     nativeToken.decimals()
        // );
        (uint256 userAmount, uint256 protocolFee) =
            feeManager.getFeeBreakdown(details.amount, _msgSender(), nativeToken.decimals());

        // 3. User Transfers Tokens to Contract
        nativeToken.safeTransferFrom(_msgSender(), address(this), details.amount);

        // 4. Reduce Supply by Burn Token Amount
        supplyAvailable[nativeToken] -= userAmount;

        // 5. Transfer Fees to Fee Collector
        nativeToken.safeTransfer(feeCollector, protocolFee);

        // 6. Send LZ Message -> Reminder MUST APPROVE SKL Token for Proper Fee Amount
        bytes memory _payload = abi.encode(details.token, details.to, userAmount);
        receipt = _lzSend(destinationLayerZeroEndpointId, _payload, options, fee, msg.sender);

        // 7. Burn Native Tokens that will be unlocked on destination
        nativeToken.burn(userAmount);
    }

    function quote(uint32 dstEid, LibTypesV1.TripDetails memory tripDetails, bytes memory options, bool payInLzToken)
        public
        view
        returns (MessagingFee memory fee)
    {
        bytes memory payload = abi.encode(tripDetails);
        fee = _quote(dstEid, payload, options, payInLzToken);
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
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    ) internal virtual override {
        // Decode the payload to get the message
        // In this case, type is string, but depends on your encoding!
        (address token, address to, uint256 amount) = abi.decode(payload, (address, address, uint256)); // TripDetails

        IMonorailNativeToken nativeToken = tokens[_origin.srcEid][token];

        // LibFeeCalculatorV1.FeeBreakdown memory fees = LibFeeCalculatorV1.calculateFees(amount, nativeToken.decimals());
        (uint256 userAmount, uint256 protocolFee) = feeManager.getFeeBreakdown(amount, to, nativeToken.decimals());

        emit BridgeReceived(address(nativeToken), to, userAmount);

        supplyAvailable[nativeToken] += amount;

        nativeToken.mint(to, userAmount);
        nativeToken.mint(feeCollector, protocolFee);
    }
}
