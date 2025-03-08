// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./fixtures/OFTBridgeFixture.t.sol";

contract OFTBridgeTest is OFTBridgeFixture {
    
    function setUp() public virtual override {
        super.setUp();
    }

    function test_constructor() public {
        assertEq(aFeeManager.hasRole(bytes32(0), address(this)), true);
        assertEq(bFeeManager.hasRole(bytes32(0), address(this)), true);
        assertEq(cFeeManager.hasRole(bytes32(0), address(this)), true);

        assertEq(aOFTBridge.feeCollector(), aFeeCollector);
        assertEq(bOFTBridge.feeCollector(), bFeeCollector);
        assertEq(cOFTBridge.feeCollector(), cFeeCollector);
        
        assertEq(address(aOFTBridge.feeManager()), address(aFeeManager));
        assertEq(address(bOFTBridge.feeManager()), address(bFeeManager));
        assertEq(address(cOFTBridge.feeManager()), address(cFeeManager));

        assertEq(address(aOFTBridge).balance, 0);
        assertEq(address(bOFTBridge).balance, 0);
        assertEq(address(cOFTBridge).balance, 0);
    }

    function test_initialBalances() public {
        assertEq(IERC20(address(aOFT)).balanceOf(aUser), TEN_MILLION);
        assertEq(IERC20(address(aOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(aOFT)).balanceOf(cUser), 0);

        assertEq(IERC20(address(bOFT)).balanceOf(aUser), 0);
        assertEq(IERC20(address(bOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(bOFT)).balanceOf(cUser), 0);

        assertEq(IERC20(address(cOFT)).balanceOf(aUser), 0);
        assertEq(IERC20(address(cOFT)).balanceOf(bUser), 0);
        assertEq(IERC20(address(cOFT)).balanceOf(cUser), 0);
    }

    function testFuzz_oneWayBridge(uint256 tokensToSend) public {
        vm.assume(tokensToSend > 0.001 ether && tokensToSend < 100 ether);
        _bridgeOFT(tokensToSend, aUser, A_EID, B_EID);
    }

    function test_oneWayBridge100() public {
        _bridgeOFT(HUNDRED, aUser, A_EID, B_EID);
    }

    function test_oneWayBridge1000() public {
        _bridgeOFT(THOUSAND, aUser, A_EID, B_EID);
    }

    function test_oneWayBridge1000000() public {
        _bridgeOFT(MILLION, aUser, A_EID, B_EID);
    }

    function test_oneWayBridge10000000() public {
        _bridgeOFT(TEN_MILLION, aUser, A_EID, B_EID);
    }
}
