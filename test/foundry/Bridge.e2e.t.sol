// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../../contracts/evm/SatelliteStation.sol";
import "../../contracts/evm/SKALEStation.sol";

import "../../contracts/mock/USDC.sol";
import "../../contracts/mock/USDCs.sol";
import "../../contracts/mock/SKALEToken.sol";

import { IMonorailNativeToken } from "../../contracts/interfaces/IMonorailNativeToken.sol";
// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract BridgeTest is TestHelperOz5 {

    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    SKALEStation private skaleStation;
    SatelliteStation private station;

    address private userA = address(0x1);
    address private feeCollector = address(0x02);
    address private liquidityCollector = address(0x3);
    

    USDC private usdc;
    USDCs private mUSDC;
    SKALEToken public skl;

    uint256 private oneHundredUSDC = 100 * 10 ** 6;

    address[] public nativeTokens;


    function setUp() public virtual override {
        super.setUp();
        
        vm.deal(userA, 1000 ether);
        vm.deal(feeCollector, 1000 ether);
        vm.deal(liquidityCollector, 1000 ether);
        
        skl = new SKALEToken("SKALE", "SKL");
        // address[] memory nativeERC20Tokens = new address[]();
        nativeTokens.push(address(0));
        nativeTokens.push(address(skl));

        // nativeERC20Tokens[0] = address(skl);
        // setUpEndpoints(2, LibraryType.UltraLightNode);
        createEndpoints(2, LibraryType.UltraLightNode, nativeTokens);

        station = SatelliteStation(payable(_deployOApp(type(SatelliteStation).creationCode, abi.encode(address(endpoints[aEid]), bEid, address(this)))));
        skaleStation = SKALEStation(payable(_deployOApp(type(SKALEStation).creationCode, abi.encode(address(endpoints[bEid]), feeCollector, liquidityCollector, address(this)))));

        address[] memory oapps = new address[](2);
        
        oapps[0] = address(station);
        oapps[1] = address(skaleStation);
        
        this.wireOApps(oapps);

        usdc = new USDC("USDC", "USDC");
        mUSDC = new USDCs("USDC.s", "USDC.s", 6, address(skaleStation));

        skaleStation.addToken(
            aEid,
            address(usdc),
            address(mUSDC)
        );

        station.addToken(address(mUSDC), address(usdc));
    }

    function test_constructor() public {
        assertEq(station.owner(), address(this));
        assertEq(skaleStation.owner(), address(this));
    }

    function test_bridge_native() public {
        
        // Step 1. Approve Token - 100 USDC
        usdc.approve(address(station), 100 * 10 ** 6);

        // Step 2. Prepare Message
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(1_000_000, 0);
        
        // Step 3. Prepare Trip Details
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(usdc), address(this), 100 * 10 ** 6);

        // Step 4. Get Quote Fee
        MessagingFee memory fee = station.quote(details, options, false);

        // Step 5. Send
        MessagingReceipt memory receipt = station.bridge{ value: fee.nativeFee }(details, options);

        // STEP 6 & 7. Deliver packet manually.
        verifyPackets(bEid, addressToBytes32(address(skaleStation)));

        // Step 8. Assert Balances
        assertEq(mUSDC.balanceOf(address(this)), 99_000_000);
        assertEq(mUSDC.balanceOf(feeCollector), 800_000);
        assertEq(mUSDC.balanceOf(liquidityCollector), 200_000);
        
        // Step 9. Asset Locked Supply
        assertEq(usdc.balanceOf(address(station)), oneHundredUSDC);

        // Step 10. Assert Minted Supply
        assertEq(skaleStation.supplyAvailable(IMonorailNativeToken(address(mUSDC))), oneHundredUSDC);

        // Step 11. Approve SKALEStation for 50 USDC
        mUSDC.approve(address(skaleStation), 50 * 10 ** 6);

        // Step 12. Prepare Options from SKALE
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(500_000, 0);

        // Step 13. Prepare Trip Details
        LibTypesV1.TripDetails memory details2 = LibTypesV1.TripDetails(address(mUSDC), address(this), 50 * 10 ** 6);

        // Step 14. Quote Native Gas Fee
        MessagingFee memory fee2 = skaleStation.quote(aEid, details2, options2, false);

        // Step 15. Approve SKL Tokens by Fee
        skl.approve(address(skaleStation), fee2.nativeFee);

        // Step 16. Send
        MessagingReceipt memory receipt2 = skaleStation.bridge(aEid, LibTypesV1.TokenType.Native, details2, fee2, options2);

        // STEP 17 & 18. Deliver packet manually.
        verifyPackets(aEid, addressToBytes32(address(station)));

        // Step 19. Verify Balances
        assertEq(mUSDC.balanceOf(feeCollector), 1_200_000);
        assertEq(mUSDC.balanceOf(liquidityCollector), 300_000);
        assertEq(mUSDC.balanceOf(address(this)), 49_000_000);

        // Step 20. Assert Minted Supply
        assertEq(skaleStation.supplyAvailable(IMonorailNativeToken(address(mUSDC))), 49_000_000 + 1_200_000 + 300_000);


    }
}