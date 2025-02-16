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
import {IOFT,SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


// Forge imports
import "forge-std/console.sol";

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import "../../contracts/mock/SKALEToken.sol";

contract OFTBridgeE2ETest is TestHelperOz5 {

	using OptionsBuilder for bytes;
	

    uint32 internal constant A_EID = 1;
    uint32 internal constant B_EID = 2;
    uint32 internal constant C_EID = 3;

    address private aUser = address(0x1);
    address private bUser = address(0x2);
    address private cUser = address(0x3);

    address private aFeeCollector = address(0x05);
    address private bFeeCollector = address(0x05);
    address private cFeeCollector = address(0x05);

    FeeManager internal aFeeManager;
    FeeManager internal bFeeManager;
    FeeManager internal cFeeManager;

    OFTBridge internal aOFTBridge;
    OFTBridge internal bOFTBridge;
    OFTBridge internal cOFTBridge;

    IOFT internal aOFT;
    IOFT internal bOFT;
    IOFT internal cOFT;

    SKALEToken internal skl;

    address[] internal nativeTokens;

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
                type(OFTMock).creationCode,
                abi.encode("OFTa", "OFTa", address(endpoints[A_EID]), address(this))
            )
        );

        OFTMock _bOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode,
                abi.encode("OFTb", "OFTb", address(endpoints[B_EID]), address(this))
            )
        );

        OFTMock _cOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode,
                abi.encode("OFTc", "OFTc", address(endpoints[C_EID]), address(this))
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

        _aOFT.mint(aUser, 100 ether);
    }

    function test_constructor() public {
    	console.log("Run");
    }

    function test_initialBalances() public {
    	assertEq(IERC20(address(aOFT)).balanceOf(aUser), 100 ether);
    	assertEq(IERC20(address(aOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(aOFT)).balanceOf(cUser), 0);

    	assertEq(IERC20(address(bOFT)).balanceOf(aUser), 0);
        assertEq(IERC20(address(bOFT)).balanceOf(bUser), 0);
    	assertEq(IERC20(address(bOFT)).balanceOf(cUser), 0);

        assertEq(IERC20(address(cOFT)).balanceOf(aUser), 0);
        assertEq(IERC20(address(cOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(cOFT)).balanceOf(cUser), 0);
    }

    function test_bridge(uint256 tokensToSend) public {
    	// uint256 tokensToSend = 1 ether;
    	vm.assume(tokensToSend > 0.001 ether && tokensToSend < 100 ether);

		// 1. Approve aOFT on OFT Bridge A
        vm.prank(aUser);
		IERC20(address(aOFT)).approve(address(aOFTBridge), tokensToSend);
    	
		// 2. Setup Options
		bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(400_000, 0);
        
        // 3. Prepare the Sending Information
        SendParam memory sendParam = SendParam(
            B_EID,
            addressToBytes32(aUser), // Recipient of bOFT
            tokensToSend,
            (tokensToSend * 9_500) / 10_000, // allow 1% slippage
            options,
            "",
            ""
        );

        // 4. Quote the LayerZero Fee (separate from tx fee)
        MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

        // 5. "Bridge" the token from aOFT -> bOFT
        vm.prank(aUser);
       	aOFTBridge.bridge{value: fee.nativeFee}(address(aOFT), sendParam, fee);

        // 6. Verify the Message on Endpoint B
        verifyPackets(B_EID, addressToBytes32(address(bOFT)));

        // 7. Load Breakdown of Funds
        // Fee Manager Responses are Public
        // This allows the below assertions to be proven correct
        (uint256 userAmount, uint256 protocolFee) = aFeeManager.getFeeBreakdown(tokensToSend, aUser, IERC20Metadata(address(aOFT)).decimals());

        // 8. Prove User Balance on New Chain
       	assertEq(IERC20(address(bOFT)).balanceOf(aUser), _handleLayerZeroSlippage(tokensToSend - protocolFee, bOFT));

        // 9. Prove Fee Collector Balance
        assertEq(IERC20(address(aOFT)).balanceOf(aFeeCollector), protocolFee);

    }

    function _handleLayerZeroSlippage(uint256 amount, IOFT layerZeroOFT) internal view returns (uint256) {
        uint8 decimals = 18 - layerZeroOFT.sharedDecimals();
        console.log("Decimals: ", decimals);
        return (amount / (10 ** decimals)) * (10 ** decimals);
    }
}