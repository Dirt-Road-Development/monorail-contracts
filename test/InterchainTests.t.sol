// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./fixtures/InterchainFixture.t.sol";

/**
 * @title InterchainTest
 * @dev Test contract for testing Native Bridge functionality across multiple chains
 * @notice Contains tests for cross-chain stablecoin transfers through SKALE Station
 * @author TheGreatAxios
 */
contract InterchainTest is InterchainFixture {
    /**
     * @notice Sets up the test environment
     * @dev Full LayerZero setup is handled in super.setUp() from NativeStationFixture
     */
    function setUp() public virtual override {
        super.setUp();
    }

    function test_toNebula() public {
        (uint256 userAmount,) = _getFee(HUNDRED_USDC, aUSDC.decimals());
        _bridgeToInterchain(HUNDRED_USDC, bUSDC, IERC20Metadata(address(nebulaUSDC)), bStation);
        assertEq(userAmount, 98.5e6);
        assertEq(nebulaUSDC.balanceOf(address(this)), userAmount);
    }
}
