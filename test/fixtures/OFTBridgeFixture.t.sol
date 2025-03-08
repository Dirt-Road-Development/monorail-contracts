// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {FeeManager} from "../../contracts/fees/FeeManager.sol";
import {IFeeManager} from "../../contracts/interfaces/IFeeManager.sol";
import {OFTBridge} from "../../contracts/oft/OFTBridge.sol";
import {SKALEToken} from "../../contracts/mock/SKALEToken.sol";

import {
    IOAppOptionsType3, EnforcedOptionParam
} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {OFTMock} from "@layerzerolabs/oft-evm/test/mocks/OFTMock.sol";
import {IOFT, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import "../../contracts/mock/SKALEToken.sol";

contract OFTBridgeFixture is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint256 public constant HUNDRED = 100e18;
    uint256 public constant THOUSAND = 1_000e18;
    uint256 public constant MILLION = 1_000_000e18;
    uint256 public constant TEN_MILLION = 10_000_000e18;

    uint32 public constant A_EID = 1;
    uint32 public constant B_EID = 2;
    uint32 public constant C_EID = 3;

    address public aUser = address(0x1);
    address public bUser = address(0x2);
    address public cUser = address(0x3);

    address public aFeeCollector = address(0x05);
    address public bFeeCollector = address(0x05);
    address public cFeeCollector = address(0x05);

    FeeManager public aFeeManager;
    FeeManager public bFeeManager;
    FeeManager public cFeeManager;

    OFTBridge public aOFTBridge;
    OFTBridge public bOFTBridge;
    OFTBridge public cOFTBridge;

    IOFT public aOFT;
    IOFT public bOFT;
    IOFT public cOFT;

    SKALEToken public skl;

    address[] public nativeTokens;

    bytes public options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(600_000, 0);

    function setUp() public virtual override {
        super.setUp();

        vm.deal(aUser, 1000 ether);
        vm.deal(bUser, 1000 ether);
        vm.deal(cUser, 1000 ether);

        vm.deal(aFeeCollector, 1000 ether);
        vm.deal(bFeeCollector, 1000 ether);
        vm.deal(cFeeCollector, 1000 ether);

        aFeeManager = new FeeManager();
        bFeeManager = new FeeManager();
        cFeeManager = new FeeManager();

        aOFTBridge = new OFTBridge(aFeeCollector, IFeeManager(address(aFeeManager)));
        bOFTBridge = new OFTBridge(bFeeCollector, IFeeManager(address(bFeeManager)));
        cOFTBridge = new OFTBridge(cFeeCollector, IFeeManager(address(cFeeManager)));

        aFeeManager.grantRole(aFeeManager.MANAGER_ROLE(), address(this));
        bFeeManager.grantRole(bFeeManager.MANAGER_ROLE(), address(this));
        cFeeManager.grantRole(cFeeManager.MANAGER_ROLE(), address(this));

        skl = new SKALEToken("SKALE", "SKL");

        nativeTokens.push(address(0));
        nativeTokens.push(address(skl));
        nativeTokens.push(address(0));

        createEndpoints(3, LibraryType.UltraLightNode, nativeTokens);

        OFTMock _aOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode, abi.encode("OFTa", "OFTa", address(endpoints[A_EID]), address(this))
            )
        );

        OFTMock _bOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode, abi.encode("OFTb", "OFTb", address(endpoints[B_EID]), address(this))
            )
        );

        OFTMock _cOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode, abi.encode("OFTc", "OFTc", address(endpoints[C_EID]), address(this))
            )
        );

        aOFT = IOFT(address(_aOFT));
        bOFT = IOFT(address(_bOFT));
        cOFT = IOFT(address(_cOFT));

        address[] memory oapps = new address[](3);

        oapps[0] = address(aOFT);
        oapps[1] = address(bOFT);
        oapps[2] = address(cOFT);

        this.wireOApps(oapps);

        _aOFT.mint(aUser, TEN_MILLION);
    }

    

    function _bridgeOFT(uint256 amount, address user, uint32 srcEndpointId, uint32 dstEndpointId) internal {

        IOFT oftFrom = _getOFT(srcEndpointId);
        IOFT oftTo = _getOFT(dstEndpointId);
        OFTBridge bridgeFrom = _getOFTBridge(srcEndpointId);

        // 1 Approve aOFT on OFT Bridge A
        vm.prank(user);
        IERC20(address(oftFrom)).approve(address(bridgeFrom), amount);

        // 3. Prepare the Sending Information
        SendParam memory sendParam = SendParam(
            dstEndpointId,
            addressToBytes32(user), // Recipient of bOFT
            amount,
            (amount * 9_500) / 10_000, // allow 1% slippage
            options,
            "",
            ""
        );

        // 4. Quote the LayerZero Fee (separate from tx fee)
        MessagingFee memory fee = oftFrom.quoteSend(sendParam, false);

        // 5. "Bridge" the token from aOFT -> bOFT
        vm.prank(user);
        bridgeFrom.bridge{value: fee.nativeFee}(address(oftFrom), sendParam, fee);

        // 6. Verify the Message on Endpoint B
        verifyPackets(dstEndpointId, addressToBytes32(address(oftTo)));

        // 7. Load Breakdown of Funds
        // Fee Manager Responses are Public
        // This allows the below assertions to be proven correct
        (uint256 userAmount, uint256 protocolFee) = _getFeeManager(srcEndpointId).getFeeBreakdown(amount, user, IERC20Metadata(address(oftFrom)).decimals());

        // 8. Prove User Balance on New Chain
        assertEq(IERC20(address(oftTo)).balanceOf(user), _handleLayerZeroSlippage(amount - protocolFee, oftTo));

        // 9. Prove Fee Collector Balance
        assertEq(IERC20(address(oftFrom)).balanceOf(aFeeCollector), protocolFee);
    }

    function _handleLayerZeroSlippage(uint256 amount, IOFT layerZeroOFT) internal view returns (uint256) {
        uint8 decimals = 18 - layerZeroOFT.sharedDecimals();
        return (amount / (10 ** decimals)) * (10 ** decimals);
    }

    function _getFeeManager(uint32 endpointId) internal view returns (FeeManager) {
        if (endpointId == A_EID) return aFeeManager;
        if (endpointId == B_EID) return bFeeManager;
        if (endpointId == C_EID) return cFeeManager;
        revert("Unknown Endpoint");
    }

    function _getOFT(uint32 endpointId) internal view returns (IOFT) {
        if (endpointId == A_EID) return aOFT;
        if (endpointId == B_EID) return bOFT;
        if (endpointId == C_EID) return cOFT;
        revert("Unknown Endpoint");
    }

    function _getOFTBridge(uint32 endpointId) internal view returns (OFTBridge) {
        if (endpointId == A_EID) return aOFTBridge;
        if (endpointId == B_EID) return bOFTBridge;
        if (endpointId == C_EID) return cOFTBridge;
        revert("Unknown Endpoint");
    }
}
