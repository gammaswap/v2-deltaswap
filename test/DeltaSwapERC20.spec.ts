import { ethers } from "hardhat";
import { expect } from 'chai'
import { BigNumber, Contract, utils, constants } from 'ethers'
import { ecsign } from 'ethereumjs-util'

import { expandTo18Decimals, getApprovalDigest } from './shared/utilities'

const TOTAL_SUPPLY = expandTo18Decimals(10000)
const TEST_AMOUNT = expandTo18Decimals(10)

describe('DeltaSwapERC20', () => {
    let ERC20: any;
    let wallet: any;
    let other: any;
    let token: Contract;

    beforeEach(async () => {
        [wallet, other] = await ethers.getSigners();
        ERC20 = await ethers.getContractFactory("ERC20");
        token = await ERC20.deploy(TOTAL_SUPPLY);
    })

    it('name, symbol, decimals, totalSupply, balanceOf, DOMAIN_SEPARATOR, PERMIT_TYPEHASH', async () => {
        const name = await token.name()
        expect(name).to.eq('DeltaSwap V1')
        expect(await token.symbol()).to.eq('DS-V1')
        expect(await token.decimals()).to.eq(18)
        expect(await token.totalSupply()).to.eq(TOTAL_SUPPLY)
        expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY)
        expect(await token.DOMAIN_SEPARATOR()).to.eq(
            utils.keccak256(
                utils.defaultAbiCoder.encode(
                    ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
                    [
                        utils.keccak256(
                            utils.toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                        ),
                        utils.keccak256(utils.toUtf8Bytes(name)),
                        utils.keccak256(utils.toUtf8Bytes('1')),
                        31337,// chainId
                        token.address
                    ]
                )
            )
        )
        expect(await token.PERMIT_TYPEHASH()).to.eq(
            utils.keccak256(utils.toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'))
        )
    })

    it('approve', async () => {
        await expect(token.approve(other.address, TEST_AMOUNT))
            .to.emit(token, 'Approval')
            .withArgs(wallet.address, other.address, TEST_AMOUNT)
        expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT)
    })

    it('transfer', async () => {
        await expect(token.transfer(other.address, TEST_AMOUNT))
            .to.emit(token, 'Transfer')
            .withArgs(wallet.address, other.address, TEST_AMOUNT)
        expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT))
        expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
    })

    it('transfer:fail', async () => {
        await expect(token.transfer(other.address, TOTAL_SUPPLY.add(1))).to.be.reverted // ds-math-sub-underflow
        await expect(token.connect(other).transfer(wallet.address, 1)).to.be.reverted // ds-math-sub-underflow
    })

    it('transferFrom', async () => {
        await token.approve(other.address, TEST_AMOUNT)
        await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
            .to.emit(token, 'Transfer')
            .withArgs(wallet.address, other.address, TEST_AMOUNT)
        expect(await token.allowance(wallet.address, other.address)).to.eq(0)
        expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT))
        expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
    })

    it('transferFrom:max', async () => {
        await token.approve(other.address, constants.MaxUint256)
        await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
            .to.emit(token, 'Transfer')
            .withArgs(wallet.address, other.address, TEST_AMOUNT)
        expect(await token.allowance(wallet.address, other.address)).to.eq(constants.MaxUint256)
        expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT))
        expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
    })

    it('permit', async () => {
        const path = "m/44'/60'/0'/0/0"; // Default path for the first account
        const _wallet = ethers.Wallet.fromMnemonic("test test test test test test test test test test test junk", path)
        expect(_wallet.address).to.equal(wallet.address);
        const nonce = await token.nonces(_wallet.address)
        const deadline = constants.MaxUint256
        const digest = await getApprovalDigest(
            token,
            { owner: _wallet.address, spender: other.address, value: TEST_AMOUNT },
            nonce,
            deadline
        )

        const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(_wallet.privateKey.slice(2), 'hex'))

        await expect(token.permit(_wallet.address, other.address, TEST_AMOUNT, deadline, v, utils.hexlify(r), utils.hexlify(s)))
            .to.emit(token, 'Approval')
            .withArgs(_wallet.address, other.address, TEST_AMOUNT)
        expect(await token.allowance(_wallet.address, other.address)).to.eq(TEST_AMOUNT)
        expect(await token.nonces(_wallet.address)).to.eq(BigNumber.from(1))
    })
})