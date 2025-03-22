// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/**
 * @dev Interface of the InterchainRegistry contract for managing supported token routes across chains.
 */
interface IInterchainRegistry {
    /**
     * @dev Struct representing a supported token route.
     * @param supported Indicates if the token is supported on the chain.
     * @param hasWrapper Indicates if the token has a wrapper contract.
     * @param wrapper The address of the wrapper contract (if applicable).
     */
    struct SupportedToken {
        bool supported;
        bool hasWrapper;
        address wrapper;
        string schainName;
    }

    /**
     * @dev Retrieves the supported token details for a given chain and token.
     * @param chainHash The hash identifying the chain.
     * @param token The address of the token.
     * @return A SupportedToken struct containing the token's support details.
     */
    function getTokenByRoute(bytes32 chainHash, address token) external view returns (SupportedToken memory);

    /**
     * @dev Registers a token for a specific chain, callable only by the REGISTRY_ROLE.
     * @param chainHash The hash identifying the chain.
     * @param token The address of the token to register.
     * @param wrapper The address of the wrapper contract (zero address if none).
     */
    function registerToken(bytes32 chainHash, address token, address wrapper, string memory schainName) external;
}
