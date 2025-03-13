// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../../contracts/mock/NebulaUSDC.sol";
import "./NativeStationFixture.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract Wrapper is ERC20Wrapper {
    constructor(string memory name, string memory symbol, IERC20 originalToken) ERC20Wrapper(originalToken) ERC20(name, symbol) {}
}

contract InterchainFixture is NativeStationFixture {
    
    NebulaUSDC public nebulaUSDC;
    Wrapper public usdcWrapper;
    /**
     * @notice Sets up the test environment
     * @dev Full LayerZero setup is handled in super.setUp() from NativeStationFixture
     */
    function setUp() public virtual override {
        super.setUp();

        nebulaUSDC = new NebulaUSDC("NebulaUSDC", "USDC.n");
        usdcWrapper = new Wrapper("wUSDC", "wUSDC", IERC20(address(aUSDC)));
        interchainRegistry.registerToken(keccak256("nebula"), address(aUSDC), address(usdcWrapper), "nebula");

        nebulaUSDC.grantRole(nebulaUSDC.MINTER_ROLE(), address(aTokenManagerERC20));

        aTokenManagerERC20.addSupportedToken(
            MockTokenManagerERC20.Token(
                address(usdcWrapper),
                address(nebulaUSDC),
                "nebula"
            )
        );
    }

    /*
     * @notice This functions bridges from some arbitrary chain to SKALE
     * @param tokenA The token on arbitrary chain
     * @param tokenB The token on SKALE Chain
     */
    function _bridgeToInterchain(uint256 amount, IERC20Metadata tokenA, IERC20Metadata tokenB, NativeStation station) internal {
        
        // 1 Approve
        tokenA.approve(address(station), amount);
        
        // 2 Trip Detail
        LibTypesV1.TripDetails memory details = LibTypesV1.TripDetails(address(tokenA), address(this), amount, keccak256("nebula"));
        
        // 3 Get Quote Fee
        MessagingFee memory fee = station.quote(details, options, false);
        
        // 4 Bridge to A
        station.bridge{value: fee.nativeFee}(details, options);
        
        // 5 Deliver
        verifyPackets(A_EID, addressToBytes32(address(aSkaleStation)));

        /*
         * @notice Use tokenB since fee is taken from chain b 
         */
        (uint256 userAmount,) = _getFee(amount, IERC20Metadata(tokenB).decimals());
        
        assertEq(tokenB.balanceOf(address(this)), userAmount);

    }
}