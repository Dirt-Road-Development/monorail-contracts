// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the ERC20Wrapper contract, an extension of ERC-20 to support token wrapping.
 */
interface IERC20Wrapper is IERC20 {
    /**
     * @dev The underlying token couldn't be wrapped.
     */
    error ERC20InvalidUnderlying(address token);

    /**
     * @dev Returns the address of the underlying ERC-20 token that is being wrapped.
     */
    function underlying() external view returns (IERC20);

    /**
     * @dev Allow a user to deposit underlying tokens and mint the corresponding number of wrapped tokens.
     * @param account The address to receive the minted wrapped tokens.
     * @param value The amount of underlying tokens to deposit and wrapped tokens to mint.
     * @return A boolean indicating success.
     */
    function depositFor(address account, uint256 value) external returns (bool);

    /**
     * @dev Allow a user to burn a number of wrapped tokens and withdraw the corresponding number of underlying tokens.
     * @param account The address to receive the withdrawn underlying tokens.
     * @param value The amount of wrapped tokens to burn and underlying tokens to withdraw.
     * @return A boolean indicating success.
     */
    function withdrawTo(address account, uint256 value) external returns (bool);
}