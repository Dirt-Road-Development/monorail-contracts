// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IFeeManager } from "../interfaces/IFeeManager.sol";
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

error TokenBridgingPaused();
error TokenNotAdded();
error UnsupportedChain();
error UnsupportedToken();

contract Station is OApp, AccessControl {

    using SafeERC20 for IERC20;

    struct Chain {
        string chainName;
        bool isSupported;
        mapping(address => bool) supportedTokens;
        uint32 layerZeroDestinationId;
    }

    struct Token {
        uint256 deposits;
        bool isPaused;
        bool isActive;
        bool isStable;
    }

    struct TripDetails {
        address token;
        address recipientAddress;
        bytes32 destination;
        uint256 amount;
    }

    IFeeManager public feeManager;
    address public feeCollector;

    mapping(bytes32 => Chain) public chains;
    mapping(address => Token) public tokens;

    bytes32 public MANAGER_ROLE = keccak256("MANAGER_ROLE");

    event Bridge(bytes32 indexed destination, address indexed token, uint256 indexed amount);

    constructor(
        address _layerZeroEndpoint,
        address _feeManager,
        address _feeCollector
    ) OApp(_layerZeroEndpoint, _msgSender()) Ownable(_msgSender()) {
        feeManager = IFeeManager(_feeManager);
        feeCollector = _feeCollector;
    }


    function bridge(
        TripDetails memory tripDetails,
        bytes calldata options
    ) external payable {

        if (!chains[tripDetails.destination].isSupported) {
            revert UnsupportedChain();
        }

        if (!chains[tripDetails.destination].supportedTokens[tripDetails.token]) {
            revert UnsupportedToken();
        }

        if (!tokens[tripDetails.token].isActive) {
            revert TokenNotAdded();
        }

        if (tokens[tripDetails.token].isPaused) {
            revert TokenBridgingPaused();
        }

        IFeeManager.Fees memory fees = tokens[tripDetails.token].isStable
            ? feeManager.calculateStablecoinFees(tripDetails.amount)
            : feeManager.calculateNonStableTokenFees(tripDetails.amount);

        
        uint256 deposit = tripDetails.amount - fees.totalFee;

        IERC20(tripDetails.token).safeTransferFrom(_msgSender(), feeCollector, fees.totalFee);
        IERC20(tripDetails.token).safeTransferFrom(_msgSender(), address(this), deposit);

        tokens[tripDetails.token].deposits += deposit;

        tripDetails.amount = deposit;
        // TODO: Send Message Via Layer Zero (requires msg.value)
        // Sends a message from the source to destination chain.
        bytes memory _payload = abi.encode(tripDetails); // Encodes message as bytes.
        
        _lzSend(
            chains[tripDetails.destination].layerZeroDestinationId, // Destination chain's endpoint ID.
            _payload, // Encoded message payload being sent.
            options, // Message execution options (e.g., gas to use on destination).
            MessagingFee(msg.value, 0), // Fee struct containing native gas and ZRO token.
            payable(msg.sender) // The refund address in case the send call reverts.
        );

        // Emit Successful Bridge
        emit Bridge(tripDetails.destination, tripDetails.token, tripDetails.amount);
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
    }

    receive() external payable {}
}