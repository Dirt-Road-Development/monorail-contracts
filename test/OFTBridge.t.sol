// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;
import "./fixtures/OFTBridgeFixture.t.sol";

/**
 * @title OFTBridgeTest
 * @dev Test contract for OFT (Omnichain Fungible Token) Bridge functionality
 * @notice Contains tests for verifying cross-chain token transfers using OFT bridges
 * @author TheGreatAxios
 */
contract OFTBridgeTest is OFTBridgeFixture {
    
    /**
     * @notice Sets up the test environment
     * @dev Inherits setup from OFTBridgeFixture
     */
    function setUp() public virtual override {
        super.setUp();
    }

    /**
     * @notice Tests the constructor and verifies initial contract states
     * @dev Checks roles, fee collectors, fee managers, and initial balances
     */
    function test_constructor() public {
        // Verify default admin role for this contract on all fee managers
        assertEq(aFeeManager.hasRole(bytes32(0), address(this)), true);
        assertEq(bFeeManager.hasRole(bytes32(0), address(this)), true);
        assertEq(cFeeManager.hasRole(bytes32(0), address(this)), true);
        
        // Verify fee collectors are correctly set
        assertEq(aOFTBridge.feeCollector(), aFeeCollector);
        assertEq(bOFTBridge.feeCollector(), bFeeCollector);
        assertEq(cOFTBridge.feeCollector(), cFeeCollector);
        
        // Verify fee managers are correctly linked
        assertEq(address(aOFTBridge.feeManager()), address(aFeeManager));
        assertEq(address(bOFTBridge.feeManager()), address(bFeeManager));
        assertEq(address(cOFTBridge.feeManager()), address(cFeeManager));
        
        // Verify bridge contracts start with zero ETH balance
        assertEq(address(aOFTBridge).balance, 0);
        assertEq(address(bOFTBridge).balance, 0);
        assertEq(address(cOFTBridge).balance, 0);
    }

    /**
     * @notice Tests the initial token balances across different chains
     * @dev Verifies that only aUser has initial balance on chain A, and others have zero
     */
    function test_initialBalances() public {
        // Verify aUser has initial balance on chain A
        assertEq(IERC20(address(aOFT)).balanceOf(aUser), TEN_MILLION);
        
        // Verify all other users have zero balances across all chains
        assertEq(IERC20(address(aOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(aOFT)).balanceOf(cUser), 0);
        assertEq(IERC20(address(bOFT)).balanceOf(aUser), 0);
        assertEq(IERC20(address(bOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(bOFT)).balanceOf(cUser), 0);
        assertEq(IERC20(address(cOFT)).balanceOf(aUser), 0);
        assertEq(IERC20(address(cOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(cOFT)).balanceOf(cUser), 0);
    }

    /**
     * @notice Fuzz test for bridging tokens with various amounts
     * @dev Tests a one-way bridge from chain A to chain B with randomly generated amounts
     * @param tokensToSend The fuzzed amount to bridge (between 0.001 ether and 100 ether)
     */
    function testFuzz_oneWayBridge(uint256 tokensToSend) public {
        vm.assume(tokensToSend > 0.001 ether && tokensToSend < 100 ether);
        _bridgeOFT(tokensToSend, aUser, A_EID, B_EID);
    }

    /**
     * @notice Tests bridging 100 tokens from chain A to chain B
     * @dev Verifies a one-way bridge with a fixed amount of 100 tokens
     */
    function test_oneWayBridge100() public {
        _bridgeOFT(HUNDRED, aUser, A_EID, B_EID);
    }

    /**
     * @notice Tests bridging 1,000 tokens from chain A to chain B
     * @dev Verifies a one-way bridge with a fixed amount of 1,000 tokens
     */
    function test_oneWayBridge1000() public {
        _bridgeOFT(THOUSAND, aUser, A_EID, B_EID);
    }

    /**
     * @notice Tests bridging 1,000,000 tokens from chain A to chain B
     * @dev Verifies a one-way bridge with a fixed amount of 1,000,000 tokens
     */
    function test_oneWayBridge1000000() public {
        _bridgeOFT(MILLION, aUser, A_EID, B_EID);
    }

    /**
     * @notice Tests bridging 10,000,000 tokens from chain A to chain B
     * @dev Verifies a one-way bridge with a fixed amount of 10,000,000 tokens
     */
    function test_oneWayBridge10000000() public {
        _bridgeOFT(TEN_MILLION, aUser, A_EID, B_EID);
    }
}