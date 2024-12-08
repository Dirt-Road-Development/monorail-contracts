import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const USE_TESTNET = true;

const celoTestnetContract: OmniPointHardhat = {
    eid: EndpointId.CELO_V2_TESTNET,
    contractName: 'Station',
}

const europaTestnetContract: OmniPointHardhat = {
    eid: EndpointId.SKALE_V2_TESTNET,
    contractName: 'SKALEStation',
}

const testnetConfig: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: celoTestnetContract,
            /**
             * This config object is optional.
             * The callerBpsCap refers to the maximum fee (in basis points) that the contract can charge.
             */

            // config: {
            //     callerBpsCap: BigInt(300),
            // },
        },
        {
            contract: europaTestnetContract,
        }
    ],
    connections: [
        // {
        //     from: fujiContract,
        //     to: sepoliaContract,
        //     config: {
        //         sendConfig: {
        //             executorConfig: {
        //                 maxMessageSize: 99,
        //                 executor: '0x71d7a02cDD38BEa35E42b53fF4a42a37638a0066',
        //             },
        //             ulnConfig: {
        //                 confirmations: BigInt(42),
        //                 requiredDVNs: [],
        //                 optionalDVNs: [
        //                     '0xe9dCF5771a48f8DC70337303AbB84032F8F5bE3E',
        //                     '0x0AD50201807B615a71a39c775089C9261A667780',
        //                 ],
        //                 optionalDVNThreshold: 2,
        //             },
        //         },
        //         receiveConfig: {
        //             ulnConfig: {
        //                 confirmations: BigInt(42),
        //                 requiredDVNs: [],
        //                 optionalDVNs: [
        //                     '0x3Eb0093E079EF3F3FC58C41e13FF46c55dcb5D0a',
        //                     '0x0AD50201807B615a71a39c775089C9261A667780',
        //                 ],
        //                 optionalDVNThreshold: 2,
        //             },
        //         },
        //     },
        // },
        {
            from: celoTestnetContract,
            to: europaTestnetContract,
        },
        {
            from: europaTestnetContract,
            to: celoTestnetContract,
        }
    ]
}

export default USE_TESTNET ? testnetConfig : null;