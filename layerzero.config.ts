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

const europaTestnetBasicOFT: OmniPointHardhat = {
    eid: EndpointId.SKALE_V2_TESTNET,
    contractName: "MonorailOFT"
}

const amoyTestnetBasicOFT: OmniPointHardhat = {
    eid: EndpointId.AMOY_V2_TESTNET,
    contractName: "BasicOFT"
}

const testnetConfig: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: europaTestnetNativeStation
        },
        {
            contract: amoyTestnetNativeStation
        },
        {
            contract: europaTestnetBasicOFT
        },
        {
            contract: amoyTestnetBasicOFT
        }
    ],
    connections: [
        // Native Stations
        {
            from: amoyTestnetNativeStation,
            to: europaTestnetNativeStation,
            config: {
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: '0x4Cf1B3Fa61465c2c907f82fC488B43223BA0CF93'
                    },
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
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: '0x86d08462EaA1559345d7F41f937B2C804209DB8A',
                    },
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
        },
        {
            from: amoyTestnetBasicOFT,
            to: europaTestnetBasicOFT,
            config: {
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: '0x4Cf1B3Fa61465c2c907f82fC488B43223BA0CF93',
                    },
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
            from: europaTestnetBasicOFT,
            to: amoyTestnetBasicOFT,
            config: {
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: '0x86d08462EaA1559345d7F41f937B2C804209DB8A',
                    },
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
