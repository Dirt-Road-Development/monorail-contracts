// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import 'solidity-coverage'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    defaultNetwork: 'europa-testnet',
    paths: {
        cache: 'cache/hardhat',
    },
    mocha: {
        timeout: 100_000,
    },
    solidity: {
        compilers: [
            {
                version: '0.8.24',
                settings: {
                    evmVersion: 'shanghai',
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        'sepolia-testnet': {
            eid: EndpointId.SEPOLIA_V2_TESTNET,
            url: 'https://rpc.sepolia.org/',
            accounts,
        },
        'avalanche-testnet': {
            eid: EndpointId.AVALANCHE_V2_TESTNET,
            url: 'https://rpc.ankr.com/avalanche_fuji',
            accounts,
        },
        'amoy-testnet': {
            eid: EndpointId.AMOY_V2_TESTNET,
            url: 'https://polygon-amoy-bor-rpc.publicnode.com',
            accounts,
            companionNetworks: {
                europa: 'europa-testnet',
            },
        },
        'europa-testnet': {
            eid: EndpointId.SKALE_V2_TESTNET,
            url: 'https://testnet.skalenodes.com/v1/juicy-low-small-testnet',
            accounts,
            companionNetworks: {
                aurora: 'aurora-testnet',
                amoy: 'amoy-testnet',
            },
        },
        'sonic-testnet': {
            eid: EndpointId.SONIC_V2_TESTNET,
            url: 'https://rpc.testnet.soniclabs.com',
            accounts,
        },
        'celo-testnet': {
            eid: EndpointId.CELO_V2_TESTNET,
            url: 'https://alfajores-forno.celo-testnet.org',
            accounts,
        },
        'aurora-testnet': {
            eid: EndpointId.AURORA_V2_TESTNET,
            url: 'https://testnet.aurora.dev',
            accounts,
            companionNetworks: {
                europa: 'europa-testnet',
            },
        },
        hardhat: {
            // Need this for testing because TestHelperOz5.sol is exceeding the compiled contract size limit
            allowUnlimitedContractSize: true,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
}

export default config
