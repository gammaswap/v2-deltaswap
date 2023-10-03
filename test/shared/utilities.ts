import { Contract, BigNumber, utils } from 'ethers'

export const MINIMUM_LIQUIDITY = BigNumber.from(10).pow(3)

const PERMIT_TYPEHASH = utils.keccak256(
    utils.toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
)

export function expandTo18Decimals(n: number): BigNumber {
    return BigNumber.from(n).mul(BigNumber.from(10).pow(18))
}

function getDomainSeparator(name: string, tokenAddress: string) {
    return utils.keccak256(
        utils.defaultAbiCoder.encode(
            ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
            [
                utils.keccak256(utils.toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
                utils.keccak256(utils.toUtf8Bytes(name)),
                utils.keccak256(utils.toUtf8Bytes('1')),
                31337,// chainId
                tokenAddress
            ]
        )
    )
}

export function getCreate2Address(
    factoryAddress: string,
    [tokenA, tokenB]: [string, string],
    bytecode: string
): string {
    const [token0, token1] = tokenA < tokenB ? [tokenA, tokenB] : [tokenB, tokenA]
    const create2Inputs = [
        '0xff',
        factoryAddress,
        utils.keccak256(utils.solidityPack(['address', 'address'], [token0, token1])),
        utils.keccak256(bytecode)
    ]
    const sanitizedInputs = `0x${create2Inputs.map(i => i.slice(2)).join('')}`
    return utils.getAddress(`0x${utils.keccak256(sanitizedInputs).slice(-40)}`)
}

export async function getApprovalDigest(
    token: Contract,
    approve: {
        owner: string
        spender: string
        value: BigNumber
    },
    nonce: BigNumber,
    deadline: BigNumber
): Promise<string> {
    const name = await token.name()
    const DOMAIN_SEPARATOR = getDomainSeparator(name, token.address)
    return utils.keccak256(
        utils.solidityPack(
            ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
            [
                '0x19',
                '0x01',
                DOMAIN_SEPARATOR,
                utils.keccak256(
                    utils.defaultAbiCoder.encode(
                        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
                        [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
                    )
                )
            ]
        )
    )
}

export async function mineBlock(provider: any, timestamp: number): Promise<void> {
    await provider.send("evm_setNextBlockTimestamp", [timestamp]);
    await provider.send("evm_mine");
}

export function encodePrice(reserve0: BigNumber, reserve1: BigNumber) {
    return [reserve1.mul(BigNumber.from(2).pow(112)).div(reserve0), reserve0.mul(BigNumber.from(2).pow(112)).div(reserve1)]
}

export const sqrt = (y: BigNumber): BigNumber => {
    let z = BigNumber.from(0);
    if (y.gt(3)) {
        z = y;
        let x = y.div(2).add(1);
        while (x.lt(z)) {
            z = x;
            x = y.div(x).add(x).div(2);
        }
    } else if (!y.isZero()) {
        z = BigNumber.from(1);
    }
    return z;
};

export const calcTradeLiquidity = (amount0: BigNumber, amount1: BigNumber, reserve0: BigNumber, reserve1: BigNumber) : BigNumber => {
    if(amount0.gt(0)) {
        return sqrt((amount0.mul(reserve1).div(reserve0)).mul(amount0))
    } else if(amount1.gt(0)) {
        return sqrt((amount1.mul(reserve0).div(reserve1)).mul(amount1))
    }
    return BigNumber.from(0);
}
