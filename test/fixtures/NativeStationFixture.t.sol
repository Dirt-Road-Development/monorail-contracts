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

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

// Forge imports
import "forge-std/console.sol";

contract NativeStationFixture is TestHelperOz5 {
    
    using OptionsBuilder for bytes;
    
    uint256 public constant HUNDRED_USDC = 100 * 10 ** 6;
    uint256 public constant THOUSAND_USDC = 1_000 * 10 ** 6;
    uint256 public constant MILLION_USDC = 1_000_000 * 10 ** 6;
    uint256 public constant TEN_MILLION_USDC = 10_000_000 * 10 ** 6;

    uint32 public constant A_EID = 1;
    uint32 public constant B_EID = 2;
    uint32 public constant C_EID = 3;
    uint32 public constant D_EID = 4;
    uint32 public constant E_EID = 5;
    uint32 public constant F_EID = 6;

    NativeSkaleStation public aSkaleStation;
    NativeStation public bStation;
    NativeStation public cStation;
    NativeStation public dStation;
    NativeStation public eStation;
    NativeStation public fStation;

    USDCs public aUSDC;
    USDC public bUSDC;
    USDC public cUSDC;
    USDC public dUSDC;
    USDC public eUSDC;
    USDC public fUSDC;
    SKALEToken public skl;

    FeeManager public feeManager;

    address public userA = address(0x1);
    address public feeCollector = address(0x2);

    address[] public nativeTokens;

    bytes public options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(1_000_000, 0);

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

    /*
     * @notice This functions bridges from some arbitrary chain to SKALE
     * @param tokenA The token on arbitrary chain
     * @param tokenB The token on SKALE Chain
     */
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

    /*
     * @notice This functions bridges from SKALE to some arbitrary chain
     * @param tokenA The token on SKALE Chain
     * @param tokenB The token on arbitrary chain
     */
    function _bridgeFromSkaleStation(uint256 amount, IERC20Metadata tokenA, IERC20Metadata tokenB, NativeStation station, uint32 dstEndpointId) internal {

        uint256 startingTokenAUserBalance = tokenA.balanceOf(address(this));
        uint256 startingTokenBUserBalance = tokenB.balanceOf(address(this));
        uint256 startingFeeCollectorBalance = tokenA.balanceOf(feeCollector);
        
        // 1 Approve
        tokenA.approve(address(aSkaleStation), amount);
        
        // 2 Trip Details
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(tokenA), address(this), amount);
        
        // 3 Get Quote Fee
        MessagingFee memory fee = aSkaleStation.quote(dstEndpointId, details, options, false);
        
        skl.approve(address(aSkaleStation), fee.nativeFee);

        // 4 Bridge to A
        aSkaleStation.bridge(dstEndpointId, details, fee, options);
        
        // 5 Deliver
        verifyPackets(dstEndpointId, addressToBytes32(address(station)));
 
        /*
         * @notice Use tokenB since fee is taken from chain b 
         */
        (uint256 userAmount, uint256 protocolFee) = _getFee(amount, IERC20Metadata(tokenA).decimals());
        
        // 7 Check Balance
        // Notice -> the user balance is subtracted on token A
        // Notice -> the protoocl fee is increase on token A
        // Notice -> the user amount is added to token B        
        assertEq(tokenA.balanceOf(address(this)), startingTokenAUserBalance - amount);
        assertEq(tokenA.balanceOf(feeCollector), protocolFee + startingFeeCollectorBalance);
        assertEq(tokenB.balanceOf(address(this)), startingTokenBUserBalance + userAmount);
    }

    function _getFee(uint256 amount, uint8 decimals) internal view returns (uint256 userAmount, uint256 protocolFee) {
        return feeManager.getFeeBreakdown(amount, address(this), decimals);
    }
}