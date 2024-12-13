import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const USE_TESTNET = true;

const europaTestnetContract: OmniPointHardhat = {
    eid: EndpointId.SKALE_V2_TESTNET,
    contractName: 'SKALEStation'
}

const amoyTestnetContract: OmniPointHardhat = {
    eid: EndpointId.AMOY_V2_TESTNET,
    contractName: 'Station'
}

const auroraTestnetContract: OmniPointHardhat = {
    eid: EndpointId.AURORA_V2_TESTNET,
    contractName: 'Station'
}

const testnetConfig: OAppOmniGraphHardhat = {
    contracts: [
        // {
            // contract: celoTestnetContract,
            /**
             * This config object is optional.
             * The callerBpsCap refers to the maximum fee (in basis points) that the contract can charge.
             */

            // config: {
            //     callerBpsCap: BigInt(300),
            // },
        // },
        {
            contract: europaTestnetContract,
        },
        {
            contract: amoyTestnetContract,
        },
        // {
        //     contract: auroraTestnetContract
        // }
    ],
    connections: [
        {
            from: amoyTestnetContract,
            to: europaTestnetContract,
            config: {
                sendConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: [
                            "0x55c175dd5b039331db251424538169d8495c18d1"
                        ]
                    }
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: [
                            "0x55c175dd5b039331db251424538169d8495c18d1"
                        ],
                    }
                }
            },
        },
        {
            from: europaTestnetContract,
            to: amoyTestnetContract,
            config: {
                sendConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: [
                            "0x955412c07d9bc1027eb4d481621ee063bfd9f4c6"
                        ]
                    }
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(1),
                        requiredDVNs: [
                            "0x955412c07d9bc1027eb4d481621ee063bfd9f4c6"
                        ]
                    }
                }
            },
        },
        // {
        //     from: auroraTestnetContract,
        //     to: europaTestnetContract,
        //     config: {
        //         sendConfig: {
        //             ulnConfig: {
        //                 confirmations: BigInt(1),
        //                 requiredDVNs: [
        //                     "0x988d898a9acf43f61fdbc72aad6eb3f0542e19e1"
        //                 ]
        //             }
        //         },
        //         receiveConfig: {
        //             ulnConfig: {
        //                 confirmations: BigInt(1),
        //                 requiredDVNs: [
        //                     "0x988d898a9acf43f61fdbc72aad6eb3f0542e19e1"
        //                 ]
        //             }
        //         }
        //     },
        // },
        // {
        //     from: europaTestnetContract,
        //     to: auroraTestnetContract,
        //     config: {
        //         sendConfig: {
        //             ulnConfig: {
        //                 confirmations: BigInt(1),
        //                 requiredDVNs: [
        //                     "0x955412c07d9bc1027eb4d481621ee063bfd9f4c6"
        //                 ]
        //             }
        //         },
        //         receiveConfig: {
        //             ulnConfig: {
        //                 confirmations: BigInt(1),
        //                 requiredDVNs: [
        //                     "0x955412c07d9bc1027eb4d481621ee063bfd9f4c6"
        //                 ]
        //             }
        //         }
        //     },
        // }
    ]
}

export default USE_TESTNET ? testnetConfig : null;
