// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../contracts/native/NativeStation.sol";
import "../contracts/native/NativeSkaleStation.sol";
import "../contracts/fees/FeeManager.sol";
import "../contracts/interfaces/IFeeManager.sol";

import "../contracts/mock/USDC.sol";
import "../contracts/mock/USDCs.sol";
import "../contracts/mock/SKALEToken.sol";

import {IMonorailNativeToken} from "../contracts/interfaces/IMonorailNativeToken.sol";
// OApp imports
import {
    IOAppOptionsType3, EnforcedOptionParam
} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

// OZ imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract NativeBridgeE2ETest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    NativeSkaleStation private skaleStation;
    NativeStation private station;
    FeeManager private feeManager;

    address private userA = address(0x1);
    address private feeCollector = address(0x02);

    USDC private usdc;
    USDCs private mUSDC;
    SKALEToken public skl;
    SKALEToken public tokenA;
    SKALEToken public tokenB;
    SKALEToken public tokenC;

    uint256 private oneHundredUSDC = 100 * 10 ** 6;

    address[] public nativeTokens;

    function setUp() public virtual override {
        super.setUp();

        vm.deal(userA, 1000 ether);
        vm.deal(feeCollector, 1000 ether);

        skl = new SKALEToken("SKALE", "SKL");
        tokenA = new SKALEToken("TokenA", "TKA");
        tokenB = new SKALEToken("TokenB", "TKB");
        tokenC = new SKALEToken("TokenB", "TKC");

        nativeTokens.push(address(0));
        nativeTokens.push(address(skl));

        createEndpoints(2, LibraryType.UltraLightNode, nativeTokens);

        feeManager = new FeeManager();

        feeManager.grantRole(feeManager.MANAGER_ROLE(), address(this));

        station = NativeStation(
            payable(
                _deployOApp(type(NativeStation).creationCode, abi.encode(address(endpoints[aEid]), bEid, address(this)))
            )
        );
        skaleStation = NativeSkaleStation(
            payable(
                _deployOApp(
                    type(NativeSkaleStation).creationCode,
                    abi.encode(address(endpoints[bEid]), feeCollector, IFeeManager(address(feeManager)))
                )
            )
        );

        address[] memory oapps = new address[](2);

        oapps[0] = address(station);
        oapps[1] = address(skaleStation);

        this.wireOApps(oapps);

        usdc = new USDC("USDC", "USDC");
        mUSDC = new USDCs("USDC.s", "USDC.s", 6, address(skaleStation));

        skaleStation.addToken(aEid, address(usdc), address(mUSDC));

        station.addToken(address(mUSDC), address(usdc));
    }

    function test_constructor() public {
        assertEq(station.owner(), address(this));
        assertEq(skaleStation.owner(), address(this));
    }

    function test_multichainBridge() public {
        // Step 1. Approve Token - 100 USDC
        usdc.approve(address(station), 100 * 10 ** 6);

        // Step 2. Prepare Message
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(1_000_000, 0);

        // Step 3. Prepare Trip Details
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(usdc), address(this), 100 * 10 ** 6);

        // Step 4. Get Quote Fee
        MessagingFee memory fee = station.quote(details, options, false);

        // Step 5. Send
        /* MessagingReceipt memory receipt = */
        station.bridge{value: fee.nativeFee}(details, options);

        // STEP 6 & 7. Deliver packet manually.
        verifyPackets(bEid, addressToBytes32(address(skaleStation)));

        // Step 8. Assert Balances
        assertEq(mUSDC.balanceOf(address(this)), 98_500_000);
        assertEq(mUSDC.balanceOf(feeCollector), 1_500_000);

        // Step 9. Asset Locked Supply
        assertEq(usdc.balanceOf(address(station)), oneHundredUSDC);

        // Step 10. Assert Minted Supply
        assertEq(skaleStation.supplyAvailable(IMonorailNativeToken(address(mUSDC))), oneHundredUSDC);

        // Step 11. Approve SKALEStation for 50 USDC
        mUSDC.approve(address(skaleStation), 50 * 10 ** 6);

        // Step 13. Prepare Trip Details
        LibTypesV1.TripDetails memory details2 = LibTypesV1.TripDetails(address(mUSDC), address(this), 50 * 10 ** 6);

        // Step 14. Quote Native Gas Fee
        MessagingFee memory fee2 = skaleStation.quote(aEid, details2, options, false);

        // Step 15. Approve SKL Tokens by Fee
        skl.approve(address(skaleStation), fee2.nativeFee);

        // Step 16. Send
        /* MessagingReceipt memory receipt2 = */
        skaleStation.bridge(aEid, details2, fee2, options);

        // STEP 17 & 18. Deliver packet manually.
        verifyPackets(aEid, addressToBytes32(address(station)));

        // Step 19. Verify Balances
        assertEq(mUSDC.balanceOf(feeCollector), 2_250_000);
        assertEq(mUSDC.balanceOf(address(this)), 48_500_000);

        // Step 20. Assert Minted Supply
        assertEq(skaleStation.supplyAvailable(IMonorailNativeToken(address(mUSDC))), 50750000);

        // Step 21. Check Fainal User Balance
        assertEq(usdc.balanceOf(address(this)), 99999949250000);
        assertEq(usdc.balanceOf(address(station)), 50750000);
    }

    function test_customERC20CustomFees() public {
        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), mUSDC.decimals());

        assertEq(userAmountA, 98500000000);
        assertEq(protocolFeeA, 1500000000);

        uint256 balance = tokenA.balanceOf(address(this));

        feeManager.configureTokenFee(
            address(tokenA),
            100, // 100 basis points = 1%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );

        (uint256 userAmountB, uint256 protocolFeeB) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), mUSDC.decimals());

        assertEq(userAmountB, 99000000000);
        assertEq(protocolFeeB, 1000000000);
    }
}
