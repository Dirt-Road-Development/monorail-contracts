import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber, Contract, ContractFactory } from 'ethers'
import { parseUnits } from 'ethers/lib/utils'
import { deployments, ethers } from 'hardhat'

describe("FeeManager Test", () => {

    let factory: ContractFactory;
    let feeManager: Contract;
    let signer: SignerWithAddress;

    before(async() => {
        factory = await ethers.getContractFactory("FeeManager");
        [ signer ] = await ethers.getSigners();
    });

    beforeEach(async() => {
        feeManager = await factory.deploy();
    })

    xit("should have correct roles", async () => {
        expect(await feeManager.DEFAULT_ADMIN_ROLE() === ethers.constants.HashZero).to.be.true;
        expect(await feeManager.FEE_MANAGER_ROLE() === ethers.utils.id("FEE_MANAGER_ROLE")).to.be.true;
    })

    xit("should have correct ownership", async () => {
        expect(await feeManager.hasRole(ethers.constants.HashZero, signer.address)).to.be.true;
        expect(await feeManager.hasRole(ethers.utils.id("FEE_MANAGER_ROLE"), signer.address)).to.be.true;
    })

    xit("should have valid initial fee thresholds", async() => {
        const feeThresholds = await feeManager.getThresholds();
        expect(feeThresholds.length).to.be.equal(5);
        expect(feeThresholds[0].toString()).to.be.equal("1000");
        expect(feeThresholds[1].toString()).to.be.equal("10000");
        expect(feeThresholds[2].toString()).to.be.equal("100000");
        expect(feeThresholds[3].toString()).to.be.equal("1000000");
        expect(feeThresholds[4].toString()).to.be.equal("115792089237316195423570985008687907853269984665640564039457584007913129639935");
    })

    it("Estimate 1% Fee on 1 USDC", async() => {
        const amount = parseUnits("1", 6);
        const fees = await feeManager.calculateFees(amount, 6);
        console.log("Fees: ", fees);
        const onePercent = amount.div(BigNumber.from(100));
        expect(fees[0].toString()).to.be.equal(amount.sub(onePercent).toString());
        expect(fees[1].toString()).to.be.equal(amount.div(125).toString());
        expect(fees[2].toString()).to.be.equal(amount.div(500).toString());
    })
})