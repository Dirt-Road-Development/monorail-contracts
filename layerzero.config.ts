import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const USE_TESTNET = true

const europaTestnetNativeStation: OmniPointHardhat = {
    eid: EndpointId.SKALE_V2_TESTNET,
    contractName: 'NativeSkaleStation',
}

const amoyTestnetNativeStation: OmniPointHardhat = {
    eid: EndpointId.AMOY_V2_TESTNET,
    contractName: 'NativeStation',
}

const testnetConfig: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: europaTestnetNativeStation
        },
        {
            contract: amoyTestnetNativeStation
        }
    ],
    connections: [
        // Native Stations
        {
            from: amoyTestnetNativeStation,
            to: europaTestnetNativeStation,
            config: {
                sendConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: ['0x55c175dd5b039331db251424538169d8495c18d1'],
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: ['0x55c175dd5b039331db251424538169d8495c18d1'],
                    },
                },
            },
        },
        {
            from: europaTestnetNativeStation,
            to: amoyTestnetNativeStation,
            config: {
                sendConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: ['0x955412c07d9bc1027eb4d481621ee063bfd9f4c6'],
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: ['0x955412c07d9bc1027eb4d481621ee063bfd9f4c6'],
                    },
                },
            },
        }
    ],
}

export default USE_TESTNET ? testnetConfig : null
