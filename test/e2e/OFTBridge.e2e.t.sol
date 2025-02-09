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


// Forge imports
import "forge-std/console.sol";

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import "../../contracts/mock/SKALEToken.sol";

contract OFTBridgeTest is TestHelperOz5 {

	using OptionsBuilder for bytes;

    uint32 internal constant A_EID = 1;
    uint32 internal constant B_EID = 2;

    address private aUser = address(0x1);
    address private bUser = address(0x2);
    address private aFeeCollector = address(0x03);
    address private bFeeCollector = address(0x04);

    FeeManager internal aFeeManager;
    FeeManager internal bFeeManager;

    OFTBridge internal aOFTBridge;
    OFTBridge internal bOFTBridge;

    OFTMock internal aOFT;
    OFTMock internal bOFT;

    SKALEToken internal skl;

    address[] internal nativeTokens;

    function setUp() public virtual override {
        super.setUp();

        vm.deal(aUser, 1000 ether);
        vm.deal(bUser, 1000 ether);
        vm.deal(aFeeCollector, 1000 ether);
        vm.deal(bFeeCollector, 1000 ether);

        aFeeManager = new FeeManager();
        bFeeManager = new FeeManager();

        aOFTBridge = new OFTBridge(aFeeCollector, IFeeManager(address(aFeeManager)));
        bOFTBridge = new OFTBridge(bFeeCollector, IFeeManager(address(bFeeManager)));

        aFeeManager.grantRole(aFeeManager.MANAGER_ROLE(), address(this));
        bFeeManager.grantRole(bFeeManager.MANAGER_ROLE(), address(this));

        skl = new SKALEToken("SKALE", "SKL");

        nativeTokens.push(address(0));
        nativeTokens.push(address(skl));

        createEndpoints(2, LibraryType.UltraLightNode, nativeTokens);

        aOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode,
                abi.encode("OFTa", "OFTa", address(endpoints[A_EID]), address(this))
            )
        );

        bOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode,
                abi.encode("OFTb", "OFTb", address(endpoints[B_EID]), address(this))
            )
        );

        address[] memory oapps = new address[](2);

        oapps[0] = address(aOFT);
        oapps[1] = address(bOFT);

        this.wireOApps(oapps);

        aOFT.mint(aUser, 100 ether);
        bOFT.mint(bUser, 100 ether);
    }

    function test_constructor() public {
    	console.log("Run");
    }

    function test_initialBalances() public {
    	assertEq(aOFT.balanceOf(aUser), 100 ether);
    	assertEq(aOFT.balanceOf(bUser), 0);
    	assertEq(bOFT.balanceOf(bUser), 100 ether);
    	assertEq(bOFT.balanceOf(aUser), 0);
    }

    function test_bridge() public {

    	// 1. Approve aOFT on OFT Bridge A
    	aOFT.approve(address(aOFTBridge), 100 ether);
		
		// 2. Setup Options
		bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        
        SendParam memory sendParam = SendParam(
            B_EID,
            addressToBytes32(userB),
            tokensToSend,
            (tokensToSend * 9_500) / 10_000, // allow 1% slippage
            options,
            "",
            ""
        );

        MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

        assertEq(aOFT.balanceOf(userA), 100 ether);
        assertEq(bOFT.balanceOf(userB), 100 ether);

    }
}