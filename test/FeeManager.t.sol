// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;
import {NativeStation} from "../contracts/native/NativeStation.sol";
import {NativeSkaleStation} from "../contracts/native/NativeSkaleStation.sol";
import {FeeManager} from "../contracts/fees/FeeManager.sol";
import {IFeeManager} from "../contracts/interfaces/IFeeManager.sol";
import {USDC} from "../contracts/mock/USDC.sol";
import {USDCs} from "../contracts/mock/USDCs.sol";
import {SKALEToken} from "../contracts/mock/SKALEToken.sol";
import {IMonorailNativeToken} from "../contracts/interfaces/IMonorailNativeToken.sol";
// OZ imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// Forge imports
import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title FeeManagerUnitTest
 * @dev Unit tests for the FeeManager contract focusing on fee calculations and token discount configurations
 * @notice Verifies fee calculations, discounts, and token configurations in the FeeManager contract
 * @author TheGreatAxios
 */
contract FeeManagerTest is Test {
    /// @dev The FeeManager contract instance being tested
    FeeManager private feeManager;
    
    /// @dev Test user address
    address private userA = address(0x1);
    
    /// @dev Fee collector address
    address private feeCollector = address(0x02);
    
    /// @dev USDC token instance
    USDC private usdc;
    
    /// @dev SKALE token instance
    SKALEToken public skl;
    
    /// @dev Token A instance for discount testing
    SKALEToken public tokenA;
    
    /// @dev Token B instance for discount testing
    SKALEToken public tokenB;
    
    /// @dev Token C instance for discount testing
    SKALEToken public tokenC;
    
    /// @dev Constant for 100 USDC (with 6 decimals)
    uint256 private oneHundredUSDC = 100 * 10 ** 6;

    /**
     * @notice Sets up the test environment with necessary contracts and configurations
     * @dev Initializes tokens, FeeManager, and grants appropriate roles
     */
    function setUp() public virtual {
        // Fund test accounts
        vm.deal(userA, 1000 ether);
        vm.deal(feeCollector, 1000 ether);
        
        // Deploy token contracts
        skl = new SKALEToken("SKALE", "SKL");
        tokenA = new SKALEToken("TokenA", "TKA");
        tokenB = new SKALEToken("TokenB", "TKB");
        tokenC = new SKALEToken("TokenB", "TKC"); // Note: Symbol duplication with TokenB
        usdc = new USDC("USDC", "USDC");
        
        // Deploy and configure FeeManager
        feeManager = new FeeManager();
        feeManager.grantRole(feeManager.MANAGER_ROLE(), address(this));
    }

    /**
     * @notice Tests the constructor initialization
     * @dev Verifies that the deployer has the default admin role
     */
    function test_constructor() public {
        assertEq(feeManager.hasRole(bytes32(0), address(this)), true);
    }

    /**
     * @notice Tests fee calculation with no discounts applied
     * @dev Verifies the default fee rate (1.5%) is correctly applied
     */
    function test_noDiscount() public {
        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), usdc.decimals());
        
        // With default 1.5% fee, user should receive 98.5% of amount
        assertEq(userAmountA, 98500000000);
        assertEq(protocolFeeA, 1500000000);
    }

    /**
     * @notice Tests adding a token-based discount configuration
     * @dev Verifies that token discount is properly registered in the FeeManager
     */
    function test_addDiscount() public {
        feeManager.configureTokenFee(
            address(tokenA),
            100, // 100 basis points = 1%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );
        
        // Verify token was added with correct parameters
        (,,, uint8 tokenType, uint256 tokenId) = feeManager.feeTokens(0);
        assertEq(tokenType, 1);
        assertEq(tokenId, 0);
    }

    /**
     * @notice Tests fee calculation with a 1% fee rate
     * @dev Configures TokenA for a 1% fee and verifies correct fee calculation
     */
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
        
        // With 1% fee, user should receive 99% of amount
        assertEq(userAmountA, 99000000000);
        assertEq(protocolFeeA, 1000000000);
    }

    /**
     * @notice Tests fee calculation with a 2% fee rate
     * @dev Configures TokenA for a 2% fee and verifies correct fee calculation
     */
    function test_use2PercentDiscount() public {
        feeManager.configureTokenFee(
            address(tokenA),
            200, // 200 basis points = 2%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );
        
        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), usdc.decimals());
        
        // With 2% fee, user should receive 98% of amount
        assertEq(userAmountA, 98000000000);
        assertEq(protocolFeeA, 2000000000);
    }

    /**
     * @notice Tests fee calculation with a 5% fee rate
     * @dev Configures TokenA for a 5% fee and verifies correct fee calculation
     */
    function test_use5PercentDiscount() public {
        feeManager.configureTokenFee(
            address(tokenA),
            500, // 500 basis points = 5%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );
        
        (uint256 userAmountA, uint256 protocolFeeA) =
            feeManager.getFeeBreakdown(100_000 * 10 ** 6, address(this), usdc.decimals());
        
        // With 5% fee, user should receive 95% of amount
        assertEq(userAmountA, 95000000000);
        assertEq(protocolFeeA, 5000000000);
    }
}