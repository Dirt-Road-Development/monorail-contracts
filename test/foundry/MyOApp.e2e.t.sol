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
}