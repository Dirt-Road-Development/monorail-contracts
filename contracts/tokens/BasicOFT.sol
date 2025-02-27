// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

contract BasicOFT is OFT {
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    ) OFT(_name, _symbol, _lzEndpoint, _msgSender()) Ownable(_msgSender()) {
        _mint(_msgSender(), 1000000 * 10 ** 18);
    }

    function mint(uint256 amount, address to) external {
        _mint(to, amount); 
    }

    function batchMint(uint256 amount, address[] memory tos) external {
        
        uint256 len = tos.length;
        
        if (len > 100) revert("Too many tos");

        for (uint256 i = 0; i < len; i++) {
            _mint(tos[i], amount);
        }
    }
}