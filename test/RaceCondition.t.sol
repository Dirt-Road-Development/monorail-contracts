// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./fixtures/NativeStationFixture.t.sol";

contract RaceConditionTest is NativeStationFixture {

    function setUp() public virtual override {
        super.setUp();
    }

    /**
     * @notice Test to ensure sufficient liquidity is available for a native exit
     * @dev This utilizes a supply check on the primary chain -- e.g SKALE Europa
     * @dev Temporarily commented out since functionality is not catching correctly in 
     */
    function test_RevertWhen_TokenSupplyInsufficientForChainPartialBalance() public {
        _bridgeToSkaleStation(HUNDRED_USDC, bUSDC, aUSDC, bStation);
        
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(aUSDC), address(this), 25e6);
        MessagingFee memory fee = aSkaleStation.quote(D_EID, details, options, false);
        skl.approve(address(aSkaleStation), fee.nativeFee);
        aUSDC.approve(address(aSkaleStation), 25e6);
        
        (uint256 userAmount, ) = _getFee(25e6, aUSDC.decimals());
        vm.expectRevert(abi.encodeWithSelector(
            TokenSupplyInsufficentForChain.selector,
            userAmount,
            0,
            D_EID
        ));
        aSkaleStation.bridge(D_EID, details, fee, options);
    }

    function test_RevertWhen_TokenSupplyInsufficientForChainFullBalance() public {
        _bridgeToSkaleStation(HUNDRED_USDC, bUSDC, aUSDC, bStation);
        
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(aUSDC), address(this), 98.5e6);
        MessagingFee memory fee = aSkaleStation.quote(D_EID, details, options, false);
        skl.approve(address(aSkaleStation), fee.nativeFee);
        aUSDC.approve(address(aSkaleStation), 98.5e6);
        
        (uint256 userAmount, ) = _getFee(98.5e6, aUSDC.decimals());
        vm.expectRevert(abi.encodeWithSelector(
            TokenSupplyInsufficentForChain.selector,
            userAmount,
            0,
            D_EID
        ));
        aSkaleStation.bridge(D_EID, details, fee, options);
    }

    function testFuzz_RevertWhen_TokenSupplyInsufficientForChainFullBalance(uint256 tokensToSend) public {
        vm.assume(tokensToSend > 100 && tokensToSend <= 98.5e6); // At least 0.0001 USDC
        _bridgeToSkaleStation(HUNDRED_USDC, bUSDC, aUSDC, bStation);
        
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(aUSDC), address(this), tokensToSend);
        MessagingFee memory fee = aSkaleStation.quote(D_EID, details, options, false);
        skl.approve(address(aSkaleStation), fee.nativeFee);
        aUSDC.approve(address(aSkaleStation), tokensToSend);
        
        (uint256 userAmount, ) = _getFee(tokensToSend, aUSDC.decimals());
        vm.expectRevert(abi.encodeWithSelector(
            TokenSupplyInsufficentForChain.selector,
            userAmount,
            0,
            D_EID
        ));
        aSkaleStation.bridge(D_EID, details, fee, options);
    }
}