// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// MyOApp imports
import { MyOApp } from "../../contracts/mock/MyOApp.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract MyOAppTest is TestHelperOz5 {

    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    MyOApp private aOApp;
    MyOApp private bOApp;

    address private userA = address(0x1);
    address private userB = address(0x2);
    uint256 private initialBalance = 100 ether;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        aOApp = MyOApp(_deployOApp(type(MyOApp).creationCode, abi.encode(address(endpoints[aEid]), address(this))));

        bOApp = MyOApp(_deployOApp(type(MyOApp).creationCode, abi.encode(address(endpoints[bEid]), address(this))));

        address[] memory oapps = new address[](2);
        oapps[0] = address(aOApp);
        oapps[1] = address(bOApp);
        this.wireOApps(oapps);
    }

    // function test_constructor() public {
    //     assertEq(aOApp.owner(), address(this));
    //     assertEq(bOApp.owner(), address(this));

    //     assertEq(address(aOApp.endpoint()), address(endpoints[aEid]));
    //     assertEq(address(bOApp.endpoint()), address(endpoints[bEid]));
    // }

    // function test_bridge() public {
    //     (address beforeTokenA, address beforeToA, uint256 beforeAmountA) = aOApp.data();
    //     (address beforeTokenB, address beforeToB, uint256 beforeAmountB) = bOApp.data();
    
    //     // Generate Details
    //     MyOApp.TripDetails memory details = MyOApp.TripDetails(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0x49b30E1e0CaecF2D573d40AEFbb7f42Af2786b4a, 15 * 10 ** 6);
        
    //     // // Generate Options
    //     bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(500000, 0);
        
    //     // // Get Quote Fee
    //     MessagingFee memory fee = aOApp.quote(bEid, details, options, false);

    //     // // Send
    //     MessagingReceipt memory receipt = aOApp.send{ value: fee.nativeFee }(bEid, details, options);
    //     // console.logAdress(dataBefore.token);
    //     // Asserting that the receiving OApps have NOT had data manipulated.
    //     assertEq(keccak256(abi.encode(beforeTokenA, beforeToA, beforeAmountA)), keccak256(abi.encode(beforeTokenB, beforeToB, beforeAmountB)), "shouldn't be changed until lzReceive packet is verified");

    //     // STEP 2 & 3: Deliver packet to bMyOApp manually.
    //     verifyPackets(bEid, addressToBytes32(address(bOApp)));

    //     (address afterTokenB, address afterToB, uint256 afterAmountB) = bOApp.data();
    //     console.logAddress(afterTokenB);
    //     console.logAddress(afterToB);
    //     console.logUint(afterAmountB);

    //     // Asserting that the data variable has updated in the receiving OApp.
    //     assertEq(keccak256(abi.encode(afterTokenB, afterToB, afterAmountB)), keccak256(abi.encode(details.token, details.to, details.amount)), "lzReceive data assertion failure");
    // }
}