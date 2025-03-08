// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;
import "./fixtures/NativeStationFixture.t.sol";

/**
 * @title NativeBridgeTest
 * @dev Test contract for testing Native Bridge functionality across multiple chains
 * @notice Contains tests for cross-chain stablecoin transfers through SKALE Station
 * @author TheGreatAxios
 */
contract NativeBridgeTest is NativeStationFixture {
    /**
     * @notice Sets up the test environment
     * @dev Full LayerZero setup is handled in super.setUp() from NativeStationFixture
     */
    function setUp() public virtual override {
        super.setUp();
    }

    /**
     * @notice Tests the constructor and verifies default state
     * @dev Checks that all station contracts have the correct owner set
     */
    function test_constructor() public {
        assertEq(aSkaleStation.owner(), address(this));
        assertEq(bStation.owner(), address(this));
        assertEq(cStation.owner(), address(this));
        assertEq(dStation.owner(), address(this));
        assertEq(eStation.owner(), address(this));
        assertEq(fStation.owner(), address(this));
    }

    /**
     * @notice Tests bridging 100 USDC across multiple chains
     * @dev Bridges 100 units of 6-decimal USDC from all source chains to aSkaleStation
     */
    function test_multichain100() public {
        bridgeAllStableToASkaleStation(HUNDRED*USDC);
    }
    
    /**
     * @notice Tests bridging 1,000 USDC across multiple chains
     * @dev Bridges 1,000 units of 6-decimal USDC from all source chains to aSkaleStation
     */
    function test_multichain1000() public {
        bridgeAllStableToASkaleStation(THOUSAND*USDC);
    }

    /**
     * @notice Tests bridging 1,000,000 USDC across multiple chains
     * @dev Bridges 1,000,000 units of 6-decimal USDC from all source chains to aSkaleStation
     */
    function test_multichain1000000() public {
        bridgeAllStableToASkaleStation(MILLION*USDC);
    }

    /**
     * @notice Tests bridging 10,000,000 USDC across multiple chains
     * @dev Bridges 10,000,000 units of 6-decimal USDC from all source chains to aSkaleStation
     */
    function test_multichain10000000() public {
        bridgeAllStableToASkaleStation(TEN*MILLION_USDC);
    }

    /**
     * @notice Tests two-way bridge functionality with 100 USDC
     * @dev Tests bridging 100 USDC to SKALE Station and then bridging the user amount (after fees) back
     */
    function test_twoWay100() public {
        (uint256 userAmount,) = getFee(HUNDRED*USDC, aUSDC.decimals());
        bridgeToSkaleStation(HUNDRED*USDC, bUSDC, aUSDC, bStation);
        bridgeFromSkaleStation(userAmount, aUSDC, bUSDC, bStation, B_EID);
    }

    /**
     * @notice Fuzz test for depositing various amounts across multiple chains
     * @dev Tests parallel deposits from all chains with randomly generated amounts
     * @param amount The fuzzed amount to bridge (between 100 and 100,000,000 * 1e6)
     */
    function testFuzz_multichainDeposit6Dec(uint256 amount) public {
        vm.assume(amount <= 100_000_000 * 1e6); // 100,000,000 * 1e6 === Amount Created to Deployer of USDC Mocks
        vm.assume(amount >= 100); // At least 0.0001 USDC
        _bridgeAllStableToASkaleStation(amount);
    }
    
    /**
     * @notice Tests custom fee configuration for ERC20 tokens with 100 USDC
     * @dev Verifies fee calculations before and after setting custom token fees
     */
    function test_customFeeERC20100() public {
        // Get fee breakdown before custom configuration
        (uint256 amountBefore, uint256 feeBefore) =
            feeManager.getFeeBreakdown(HUNDRED_USDC, address(this), aUSDC.decimals());
        assertEq(amountBefore, 98500000);
        assertEq(feeBefore, 1500000);
        
        // Configure custom token fee
        feeManager.configureTokenFee(
            address(aToken),
            100, // 100 basis points = 1%
            100 * 10 ** 18, // minimum holding requirement
            0,
            1 // ERC20
        );
        
        // Get fee breakdown after custom configuration
        (uint256 amountAfter, uint256 feeAfter) =
            feeManager.getFeeBreakdown(HUNDRED_USDC, address(this), aUSDC.decimals());
        assertEq(amountAfter, 99000000);
        assertEq(feeAfter, 1000000);
    }
}