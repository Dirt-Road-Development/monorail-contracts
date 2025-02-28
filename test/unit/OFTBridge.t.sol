// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {FeeManager} from "../../contracts/fees/FeeManager.sol";
import {IFeeManager} from "../../contracts/interfaces/IFeeManager.sol";
import {OFTBridge} from "../../contracts/oft/OFTBridge.sol";

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract OFTBridgeUnitTest is Test {
    FeeManager private feeManager;
    OFTBridge private bridge;

    address private userA = address(0x1);
    address public feeCollector = address(0x2);

    function setUp() public virtual {
        vm.deal(userA, 1000 ether);
        vm.deal(feeCollector, 1000 ether);

        feeManager = new FeeManager();
        feeManager.grantRole(feeManager.MANAGER_ROLE(), address(this));

        bridge = new OFTBridge(feeCollector, IFeeManager(address(feeManager)));
    }

    function test_constructor() public {
        assertEq(feeManager.hasRole(bytes32(0), address(this)), true);
        assertEq(bridge.feeCollector(), feeCollector);
        assertEq(address(bridge.feeManager()), address(feeManager));
        assertEq(address(bridge).balance, 0);
    }
}
