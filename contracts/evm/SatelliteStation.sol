// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { LibTypesV1 } from "../lib/LibTypesV1.sol";

error TokenBridgingPaused();
error TokenNotAdded();
error UnsupportedChain();
error UnsupportedToken();

contract SatelliteStation is OApp, AccessControl {

    using SafeERC20 for IERC20;

    struct Token {
        bool isPaused;
        bool isOFT;
        uint256 deposits;
    }

    bytes32 public MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint32 skaleEndpointId;

    // SKALE Token Address => Local Token Address
    mapping(address => IERC20) public tokens;
    
    // Local Token Address (IERC20) => Supported
    mapping(address => bool) public supported;

    mapping(IERC20 => uint256) public deposits;

    event AddToken(address indexed token);
    event Bridge(address indexed token, uint256 indexed amount);

    constructor(
        address _layerZeroEndpoint,
        uint32 _skaleEndpointId,
        address owner
    ) OApp(_layerZeroEndpoint, _msgSender()) Ownable(owner) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MANAGER_ROLE, owner);
        _grantRole(MANAGER_ROLE, _msgSender());
        skaleEndpointId = _skaleEndpointId;
    }

    event AddToken(address indexed skaleTokenAddress, address indexed localTokenAddress);

    function addToken(
        address skaleTokenAddress,
        address localTokenAddress
    ) external onlyRole(MANAGER_ROLE) {
        
        if (address(tokens[skaleTokenAddress]) != address(0)) {
            revert("Token Already Added + Active");
        }

        IERC20 localToken = IERC20(localTokenAddress);
        tokens[skaleTokenAddress] = localToken;
        supported[localTokenAddress] = true;

        emit AddToken(skaleTokenAddress, localTokenAddress);
    }

    function bridge(
        LibTypesV1.TripDetails memory details,
        bytes calldata options
    ) external payable returns (MessagingReceipt memory receipt) {

        if (!supported[details.token]) {
            revert("Unsupported Token");
        }

        if (details.to == address(0)) { 
            revert("To must not be address(0)");
        }

        IERC20(details.token).safeTransferFrom(_msgSender(), address(this), details.amount);

        deposits[IERC20(details.token)] += details.amount;

        // Encodes message as bytes.
        bytes memory _payload = abi.encode(details.token, details.to, details.amount);        
        receipt = _lzSend(skaleEndpointId, _payload, options, MessagingFee(msg.value, 0), payable(msg.sender));

        // Emit Successful Bridge
        emit Bridge(details.token, details.amount);
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
        LibTypesV1.TripDetails memory details = abi.decode(payload, (LibTypesV1.TripDetails));
    }

    function quote(
        LibTypesV1.TripDetails memory _tripDetails,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_tripDetails);
        fee = _quote(skaleEndpointId, payload, _options, _payInLzToken);
    }

    receive() external payable {}
}