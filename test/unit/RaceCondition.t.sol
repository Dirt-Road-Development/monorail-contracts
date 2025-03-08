// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../../contracts/native/NativeStation.sol";
import "../../contracts/native/NativeSkaleStation.sol";
import "../../contracts/fees/FeeManager.sol";
import "../../contracts/interfaces/IFeeManager.sol";

import "../../contracts/mock/USDC.sol";
import "../../contracts/mock/USDCs.sol";
import "../../contracts/mock/SKALEToken.sol";

import {IMonorailNativeToken} from "../../contracts/interfaces/IMonorailNativeToken.sol";
// OApp imports
import {
    IOAppOptionsType3, EnforcedOptionParam
} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

// OZ imports
import {IERC20,IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


// Forge imports
import "forge-std/console.sol";

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract RaceConditionTest is TestHelperOz5 {
    
    using OptionsBuilder for bytes;
    
    uint256 private constant HUNDRED_USDC = 100 * 10 ** 6;
    uint256 private constant THOUSAND_USDC = 1_000 * 10 ** 6;
    uint256 private constant MILLION_USDC = 1_000_000 * 10 ** 6;
    uint256 private constant TEN_MILLION_USDC = 10_000_000 * 10 ** 6;

    uint32 private constant A_EID = 1;
    uint32 private constant B_EID = 2;
    uint32 private constant C_EID = 3;
    uint32 private constant D_EID = 4;
    uint32 private constant E_EID = 5;
    uint32 private constant F_EID = 6;

    NativeSkaleStation private aSkaleStation;
    NativeStation private bStation;
    NativeStation private cStation;
    NativeStation private dStation;
    NativeStation private eStation;
    NativeStation private fStation;

    USDCs private aUSDC;
    USDC private bUSDC;
    USDC private cUSDC;
    USDC private dUSDC;
    USDC private eUSDC;
    USDC private fUSDC;
    SKALEToken private skl;

    FeeManager private feeManager;

    address private userA = address(0x1);
    address private feeCollector = address(0x2);

    address[] private nativeTokens;

    bytes private options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(1_000_000, 0);

    function setUp() public virtual override {
        super.setUp();

        vm.deal(userA, 100 ether);

        // Setup Native Tokens
        skl = new SKALEToken("SKALE", "SKL");

        address aNativeToken = address(skl);
        address bNativeToken = address(0);
        address cNativeToken = address(0);
        address dNativeToken = address(0);
        address eNativeToken = address(0);
        address fNativeToken = address(0);

        nativeTokens.push(aNativeToken);
        nativeTokens.push(bNativeToken);
        nativeTokens.push(cNativeToken);
        nativeTokens.push(dNativeToken);
        nativeTokens.push(eNativeToken);
        nativeTokens.push(fNativeToken);
        // End Native Tokens Setup

        // Setup LayerZero Endpoints
        createEndpoints(6, LibraryType.UltraLightNode, nativeTokens);

        // Setup Fee Manager
        feeManager = new FeeManager();
        feeManager.grantRole(feeManager.MANAGER_ROLE(), address(this));

        address[] memory oapps = new address[](6);

        aSkaleStation = NativeSkaleStation(
            payable(
                _deployOApp(
                    type(NativeSkaleStation).creationCode,
                    abi.encode(address(endpoints[A_EID]), feeCollector, IFeeManager(address(feeManager)))
                )
            )
        );

        bStation = NativeStation(
            payable(
                _deployOApp(type(NativeStation).creationCode, abi.encode(address(endpoints[B_EID]), A_EID, address(this)))
            )
        );

        cStation = NativeStation(
            payable(
                _deployOApp(type(NativeStation).creationCode, abi.encode(address(endpoints[C_EID]), A_EID, address(this)))
            )
        );

        dStation = NativeStation(
            payable(
                _deployOApp(type(NativeStation).creationCode, abi.encode(address(endpoints[D_EID]), A_EID, address(this)))
            )
        );

        eStation = NativeStation(
            payable(
                _deployOApp(type(NativeStation).creationCode, abi.encode(address(endpoints[E_EID]), A_EID, address(this)))
            )
        );

        fStation = NativeStation(
            payable(
                _deployOApp(type(NativeStation).creationCode, abi.encode(address(endpoints[F_EID]), A_EID, address(this)))
            )
        );
        
        oapps[0] = address(aSkaleStation);
        oapps[1] = address(bStation);
        oapps[2] = address(cStation);
        oapps[3] = address(dStation);
        oapps[4] = address(eStation);
        oapps[5] = address(fStation);

        this.wireOApps(oapps);

        aUSDC = new USDCs("USDC", "USDC", 6, address(aSkaleStation));
        bUSDC = new USDC("USDC", "USDC");
        cUSDC = new USDC("USDC", "USDC");
        dUSDC = new USDC("USDC", "USDC");
        eUSDC = new USDC("USDC", "USDC");
        fUSDC = new USDC("USDC", "USDC");

        aSkaleStation.addToken(B_EID, address(bUSDC), address(aUSDC));
        aSkaleStation.addToken(C_EID, address(cUSDC), address(aUSDC));
        aSkaleStation.addToken(D_EID, address(dUSDC), address(aUSDC));
        aSkaleStation.addToken(E_EID, address(eUSDC), address(aUSDC));
        aSkaleStation.addToken(F_EID, address(fUSDC), address(aUSDC));

        bStation.addToken(address(aUSDC), address(bUSDC));
        cStation.addToken(address(aUSDC), address(cUSDC));
        dStation.addToken(address(aUSDC), address(dUSDC));
        eStation.addToken(address(aUSDC), address(eUSDC));
        fStation.addToken(address(aUSDC), address(fUSDC));
    }

    function test_constructor() public {
        assertEq(aSkaleStation.owner(), address(this));
        assertEq(bStation.owner(), address(this));
        assertEq(cStation.owner(), address(this));
        assertEq(dStation.owner(), address(this));
        assertEq(eStation.owner(), address(this));
        assertEq(fStation.owner(), address(this));
    }

    function test_multichain100() public {
        _bridgeAllStableToASkaleStation(HUNDRED_USDC);
    }

    function test_multichain1000() public {
        _bridgeAllStableToASkaleStation(THOUSAND_USDC);
    }

    function test_multichain1000000() public {
        _bridgeAllStableToASkaleStation(MILLION_USDC);
    }

    function test_multichain10000000() public {
        _bridgeAllStableToASkaleStation(TEN_MILLION_USDC);
    }

    function testFuzz_multichainDeposit6Dec(uint256 amount) public {
        vm.assume(amount <= 100_000_000 * 1e6); // 100_000_000 * 1e6 === Amount Created to Deployer of USDC Mocks
        vm.assume(amount >= 100); // At least 0.0001 USDC
        _bridgeAllStableToASkaleStation(amount);
    }

    function test_multichainConsolidatedExit() public {
        _bridgeAllStableToASkaleStation(HUNDRED_USDC);
    }

    function _bridgeAllStableToASkaleStation(uint256 amount) internal {

        // 1. Get Shared Fee
        (uint256 userAmount, uint256 protocolFee) = _getFee(amount, aUSDC.decimals());

        _bridgeToSkaleStation(amount, bUSDC, aUSDC, bStation);
        _bridgeToSkaleStation(amount, cUSDC, aUSDC, cStation);
        _bridgeToSkaleStation(amount, dUSDC, aUSDC, dStation);
        _bridgeToSkaleStation(amount, eUSDC, aUSDC, eStation);
        _bridgeToSkaleStation(amount, fUSDC, aUSDC, fStation);

        assertEq(aUSDC.balanceOf(address(this)), userAmount * 5);
        assertEq(aUSDC.balanceOf(feeCollector), protocolFee * 5);
        assertEq(aSkaleStation.supplyAvailable(IMonorailNativeToken(address(aUSDC))), userAmount * 5 + protocolFee * 5);
    }

    function _bridgeToSkaleStation(uint256 amount, IERC20Metadata tokenA, IERC20Metadata tokenB, NativeStation station) internal {
        
        uint256 startingUserBalance = tokenB.balanceOf(address(this));
        uint256 startingFeeCollectorBalance = tokenB.balanceOf(feeCollector);
        // 1 Approve
        tokenA.approve(address(station), amount);
        
        // 2 Trip Details
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(tokenA), address(this), amount);
        
        // 3 Get Quote Fee
        MessagingFee memory fee = station.quote(details, options, false);
        
        // 4 Bridge to A
        station.bridge{value: fee.nativeFee}(details, options);
        
        // 5 Deliver
        verifyPackets(A_EID, addressToBytes32(address(aSkaleStation)));
 
        /*
         * @notice Use tokenB since fee is taken from chain b 
         */
        (uint256 userAmount, uint256 protocolFee) = _getFee(amount, IERC20Metadata(tokenB).decimals());
        
        // 7 Check Balance
        assertEq(tokenB.balanceOf(address(this)), userAmount + startingUserBalance);
        assertEq(tokenB.balanceOf(feeCollector), protocolFee + startingFeeCollectorBalance);
    }

    function _getFee(uint256 amount, uint8 decimals) internal view returns (uint256 userAmount, uint256 protocolFee) {
        return feeManager.getFeeBreakdown(amount, address(this), decimals);
    }
}