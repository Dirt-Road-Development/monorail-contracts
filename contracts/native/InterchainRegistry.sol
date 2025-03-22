// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IInterchainRegistry} from "../interfaces/IInterchainRegistry.sol";

contract InterchainRegistry is IInterchainRegistry, AccessControl {

    bytes32 public constant REGISTRY_ROLE = keccak256("REGISTRY_ROLE");

    string public registryLocation;

    mapping(bytes32 => mapping(address => SupportedToken)) public supportedTokenRoutes;

    event RegisterToken(bytes32 indexed chainHash, address indexed token, address indexed wrapper);

    constructor(string memory location) {
        registryLocation = location; // e.g elated-tan-skat
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(REGISTRY_ROLE, _msgSender());
    }

    function getTokenByRoute(bytes32 chainHash, address token) external view returns (SupportedToken memory) {
        return supportedTokenRoutes[chainHash][token];
    }

    function registerToken(bytes32 chainHash, address token, address wrapper, string memory schainName)
        external
        onlyRole(REGISTRY_ROLE)
    {
        supportedTokenRoutes[chainHash][token] = SupportedToken(true, wrapper != address(0), wrapper, schainName);

        emit RegisterToken(chainHash, token, wrapper);
    }
}
