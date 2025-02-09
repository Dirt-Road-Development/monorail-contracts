// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {MessagingFee, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOFT,SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LibTypesV1} from "../lib/LibTypesV1.sol";

contract OFTBridge is AccessControl, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    IFeeManager public feeManager;

    address private feeCollector;

    // Events
    event BridgeInitiated(
        address indexed sender, 
        uint32 indexed dstChainId, 
        uint256 amount, 
        uint256 fee
    );
    
    constructor(
        address _feeCollector,
        IFeeManager _feeManager
    ) {

        if (_feeCollector == address(0)) {
            revert("Fee Collector Address Must Not Be 0");
        }

        // Set Fee Collector. If failed to set will revert when minting
        feeCollector = _feeCollector;
        feeManager = _feeManager;
        
    }

    function bridge(
        address token,
        SendParam memory sendParam,
        MessagingFee memory fee
    ) external nonReentrant payable {

        IOFT oft = IOFT(token);
        
        IERC20 erc20 = IERC20(token);
        (uint256 userAmount, uint256 protocolFee) = feeManager.getFeeBreakdown(sendParam.amountLD, _msgSender(), oft.sharedDecimals());

        erc20.safeTransferFrom(_msgSender(), address(this), sendParam.amountLD);
        erc20.safeTransfer(feeCollector, protocolFee);
        
        oft.send(
            sendParam,
            fee,
            _msgSender()
        );

        emit BridgeInitiated(msg.sender, sendParam.dstEid, sendParam.amountLD, protocolFee);
    }

    // Fallback for receiving native tokens
    receive() external payable {}
}