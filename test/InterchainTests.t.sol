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

    function test_toNebula100USDC() public {
        (uint256 userAmount,) = _getFee(HUNDRED_USDC, aUSDC.decimals());
        _bridgeToInterchain(HUNDRED_USDC, bUSDC, IERC20Metadata(address(nebulaUSDC)), bStation);
        assertEq(userAmount, 98.5e6);
        assertEq(nebulaUSDC.balanceOf(address(this)), userAmount);
    }

    function test_toNebula1000USDC() public {
        (uint256 userAmount,) = _getFee(THOUSAND_USDC, aUSDC.decimals());
        _bridgeToInterchain(THOUSAND_USDC, bUSDC, IERC20Metadata(address(nebulaUSDC)), bStation);
        assertEq(userAmount, 985e6);
        assertEq(nebulaUSDC.balanceOf(address(this)), userAmount);
    }

    function test_toNebula1000000USDC() public {
        (uint256 userAmount,) = _getFee(MILLION_USDC, aUSDC.decimals());
        _bridgeToInterchain(MILLION_USDC, bUSDC, IERC20Metadata(address(nebulaUSDC)), bStation);
        assertEq(userAmount, 985_000e6);
        assertEq(nebulaUSDC.balanceOf(address(this)), userAmount);
    }

    function test_toNebula10000000USDC() public {
        (uint256 userAmount,) = _getFee(TEN_MILLION_USDC, aUSDC.decimals());
        _bridgeToInterchain(TEN_MILLION_USDC, bUSDC, IERC20Metadata(address(nebulaUSDC)), bStation);
        assertEq(userAmount, 9_850_000e6);
        assertEq(nebulaUSDC.balanceOf(address(this)), userAmount);
    }
}
