// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {NativeStation} from "../../contracts/native/NativeStation.sol";
import {NativeSkaleStation} from "../../contracts/native/NativeSkaleStation.sol";
import {FeeManager} from "../../contracts/fees/FeeManager.sol";
import {IFeeManager} from "../../contracts/interfaces/IFeeManager.sol";

import {USDC} from "../../contracts/mock/USDC.sol";
import {USDCs} from "../../contracts/mock/USDCs.sol";
import {SKALEToken} from "../../contracts/mock/SKALEToken.sol";

import {IMonorailNativeToken} from "../../contracts/interfaces/IMonorailNativeToken.sol";

// OZ imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

// DevTools imports
// import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract FeeManagerUnitTest is Test {
    FeeManager private feeManager;

    address private userA = address(0x1);
    address private feeCollector = address(0x02);

    USDC private usdc;
    SKALEToken public skl;
    SKALEToken public tokenA;
    SKALEToken public tokenB;
    SKALEToken public tokenC;

    uint256 private oneHundredUSDC = 100 * 10 ** 6;

    function setUp() public virtual {
        vm.deal(userA, 1000 ether);
        vm.deal(feeCollector, 1000 ether);

        skl = new SKALEToken("SKALE", "SKL");
        tokenA = new SKALEToken("TokenA", "TKA");
        tokenB = new SKALEToken("TokenB", "TKB");
        tokenC = new SKALEToken("TokenB", "TKC");
        usdc = new USDC("USDC", "USDC");

        feeManager = new FeeManager();
        feeManager.grantRole(feeManager.MANAGER_ROLE(), address(this));
    }

    function test_constructor() public {
        assertEq(feeManager.hasRole(bytes32(0), address(this)), true);
    }

    function test_noDiscount() public {
        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), usdc.decimals());
        assertEq(userAmountA, 98500000000);
        assertEq(protocolFeeA, 1500000000);
    }

    function test_addDiscount() public {
        feeManager.configureTokenFee(
            address(tokenA),
            100, // 100 basis points = 1%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );

        (,,, uint8 tokenType, uint256 tokenId) = feeManager.feeTokens(0);

        assertEq(tokenType, 1);
        assertEq(tokenId, 0);
    }

    function test_use1PercentDiscount() public {
        feeManager.configureTokenFee(
            address(tokenA),
            100, // 100 basis points = 1%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );

        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), usdc.decimals());
        assertEq(userAmountA, 99000000000);
        assertEq(protocolFeeA, 1000000000);
    }

    function test_use2PercentDiscount() public {
        feeManager.configureTokenFee(
            address(tokenA),
            200, // 100 basis points = 1%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );

        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), usdc.decimals());
        assertEq(userAmountA, 98000000000);
        assertEq(protocolFeeA, 2000000000);
    }

    function test_use5PercentDiscount() public {
        feeManager.configureTokenFee(
            address(tokenA),
            500, // 100 basis points = 1%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );

        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), usdc.decimals());
        assertEq(userAmountA, 95000000000);
        assertEq(protocolFeeA, 5000000000);
    }

    // function test_customERC20CustomFees() public {
    //     (uint256 userAmountA, uint256 protocolFeeA) = feeManager.getFeeBreakdown(address(mUSDC), 100_000 * 10 ** 6, address(this));

    // assertEq(userAmountA, 98500000000);
    // assertEq(protocolFeeA, 1500000000);

    //     // uint256 balance = tokenA.balanceOf(address(this));

    // feeManager.addToken(
    //     address(tokenA),
    //     100 * 10 ** 18,
    //     100 * 10 ** 18,
    //     1,
    //     1
    // );

    //     (uint256 userAmountB, uint256 protocolFeeB) = feeManager.getFeeBreakdown(address(mUSDC), 100_000 * 10 ** 6, address(this));
    //     console.log("RES: ", userAmountB, protocolFeeB);
    //     assertEq(userAmountA, 99000000000);
    //     assertEq(protocolFeeA, 1000000000);

    // }
}
