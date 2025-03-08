// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../NativeStationFixture.t.sol";

contract RaceConditionTest is NativeStationFixture {

    function setUp() public virtual override {
        super.setUp();
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

    function test_multichainAndBack100() public {
        (uint256 userAmount, uint256 protocolFee) = _getFee(HUNDRED_USDC, aUSDC.decimals());
        
        _bridgeToSkaleStation(HUNDRED_USDC, bUSDC, aUSDC, bStation);
        _bridgeFromSkaleStation(userAmount, aUSDC, bUSDC, bStation, B_EID);
    }
}