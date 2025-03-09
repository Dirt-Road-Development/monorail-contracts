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

error InsufficentBalance(uint256 attemptedAmount, uint256 actualBalance);
error TokenSupplyInsufficent(uint256 expectedAmount, uint256 actualAmount);
error TokenSupplyInsufficentForChain(uint256 expectedAmount, uint256 actualAmount, uint256 layerZeroDstEid);
error SupplyInbalance(address token, uint256 countedSupply, uint256 expectedSupply);

contract NativeSkaleStation is SKALEOApp, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IMonorailNativeToken;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address private feeCollector;
    IFeeManager public feeManager;

    /// @notice any monorail tokens should have a list of supported endpoints
    /// @dev this is used in conjunction with supportedEndpoints to properly balance supply
    mapping(IMonorailNativeToken => uint32[]) public endpointsByToken;

    /// @notice this is the total amount of supply for a given token [on the SKALE Side]
    mapping(IMonorailNativeToken => uint256) public supplyAvailable;

    /// @notice SKALE Token -> LayerZero Dest. Endpoint Id -> Total Supply
    mapping(IMonorailNativeToken => mapping(uint32 => uint256)) public supplyAvailableByChain;

    /// @notice Native Token -> LayerZero Dest. Endpoint Id -> Supported Bool
    /// @dev While this is technically a duplicate of above, it helps when there is no active balance
    mapping(IMonorailNativeToken => mapping(uint32 => bool)) public supported;

    /// @notice LayerZero Chain Id => Origin Token => Local Native Token
    /// @dev This extra mapping is insurance on the exit bridge to ensure that an incorrect
    /// value is not inputted for the origin tokne that is being exited too
    mapping(uint32 => mapping(address => IMonorailNativeToken)) public tokens;

    event AddToken(
        uint32 indexed layerZeroEndpointId, address indexed originTokenAddress, address indexed localTokenAddress
    );
    event BridgeReceived(address indexed token, address indexed to, uint256 indexed amount);
    event SupplyImbalance(address indexed nativeToken, uint256 indexed countedSupply, uint256 indexed expectedSupply);

    constructor(address _layerZeroEndpoint, address _feeCollector, IFeeManager _feeManager)
        SKALEOApp(_layerZeroEndpoint)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());

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
        
        // 1 -> Add Support for Token
        // Local Token === Address on this chain
        // LayerZeroEndpointId === Destination Id
        supported[localToken][layerZeroEndpointId] = true;

        // 2 -> Add Cross Chain Address Mapping to Ensure Proper Linking
        // LayerZeroEndpointId === Destination Id
        // Origin Token Address === Address on the origin chain
        // Local Token === Address on this chain
        tokens[layerZeroEndpointId][originTokenAddress] = localToken;
        
        // 3 -> Add Endpoint to token bucket
        // LayerZeroEndpointId === Destination Id
        // Local Token === Address on this chain
        endpointsByToken[localToken].push(layerZeroEndpointId);
        

        emit AddToken(layerZeroEndpointId, originTokenAddress, localTokenAddress);
    }

    function bridge(
        uint32 destinationLayerZeroEndpointId,
        LibTypesV1.TripDetails memory details,
        MessagingFee memory fee,
        bytes calldata options
    ) external nonReentrant returns (MessagingReceipt memory receipt) {
        IMonorailNativeToken nativeToken = IMonorailNativeToken(details.token);

        // 1 Validate Token is Supported
        if (!supported[nativeToken][destinationLayerZeroEndpointId]) {
            revert("Token Not Supported");
        }

        // 2 Explicit Check Occurs here. Without getFeeBreakdown throws arithmetic underflow/overflow error
        if (details.amount > nativeToken.balanceOf(_msgSender())) {
            revert InsufficentBalance(details.amount, nativeToken.balanceOf(_msgSender()));
        }

        // 3 Calculate FeeBreakdown
        (uint256 userAmount, uint256 protocolFee) =
            feeManager.getFeeBreakdown(details.amount, _msgSender(), nativeToken.decimals());

        // 4 Check Supply of Token
        if (userAmount > supplyAvailable[nativeToken]) { // Is this check necessary?
            revert TokenSupplyInsufficent(userAmount, supplyAvailable[nativeToken]);
        }

        // 5 Check Supply by Chain
        if (userAmount > supplyAvailableByChain[nativeToken][destinationLayerZeroEndpointId]) {
            revert TokenSupplyInsufficentForChain(userAmount, supplyAvailableByChain[nativeToken][destinationLayerZeroEndpointId], destinationLayerZeroEndpointId);
        }

        // Reduce Supply
        supplyAvailable[nativeToken] -= userAmount;
        supplyAvailableByChain[nativeToken][destinationLayerZeroEndpointId] -= userAmount;

        // 7 User Transfers Tokens to Contract
        nativeToken.safeTransferFrom(_msgSender(), address(this), details.amount);
        
        // 8 Transfer Protocol Fee to Fee Collector
        nativeToken.safeTransfer(feeCollector, protocolFee);
        
        // 9 Burn User Amount of Native Tokens that will be unlocked on destination
        nativeToken.burn(userAmount);

        // 10 Book balance Check -> remove?
        (bool isBalanced, uint256 countedSupply, uint256 availableSupply) = isSupplyBalanced(nativeToken);
        if (!isBalanced) {
            revert SupplyInbalance(address(nativeToken), countedSupply, availableSupply);
        }

        // 11 Send LZ Message -> Reminder MUST APPROVE SKL Token for Proper Fee Amount
        bytes memory _payload = abi.encode(details.token, details.to, userAmount);
        receipt = _lzSend(destinationLayerZeroEndpointId, _payload, options, fee, msg.sender);
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
        supplyAvailableByChain[nativeToken][_origin.srcEid] += amount;

        (bool isBalanced, uint256 countedSupply, uint256 availableSupply) = isSupplyBalanced(nativeToken);
        if (!isBalanced) {
            // Emit Event instead of Reverting. Why? This ensures that tokens are minted to the user
            // We could potentially put these in a separate valut with a timelock and claim mechanism 
            // to manually handle imbalances
            // The reality is that an imbalance is impossible I'm just paranoid :)
            emit SupplyImbalance(address(nativeToken), countedSupply, availableSupply);
        }

        // End Supply Balance Section
        // Should these be moved before the state changes?
        nativeToken.mint(to, userAmount);
        nativeToken.mint(feeCollector, protocolFee);
    }

    function isSupplyBalanced(IMonorailNativeToken nativeToken) public view returns (bool, uint256, uint256){
        /**
          * @notice Start Supply Balance Section
          * @dev This section is used to keep the books. Auditors may tell me it's unecessary
                 but the belief is that if this occurs we can audit the flow of funds to determine
                 where the imbalance occured and work to fix it through the manual movement of funds
         */
        uint32[] memory endpoints = endpointsByToken[nativeToken];
        uint256 endpointsLength = endpoints.length;
        uint256 countedSupply;
        for (uint256 i = 0; i < endpointsLength; i++) {
            countedSupply += supplyAvailableByChain[nativeToken][endpoints[i]];
        }

        return (countedSupply == supplyAvailable[nativeToken], countedSupply, supplyAvailable[nativeToken]);
    }
}
