import * as dotenv from "dotenv";
import {ethers, upgrades, run} from "hardhat";
import {Contract, ContractFactory} from "ethers";
import {DeployProxyOptions} from "@openzeppelin/hardhat-upgrades/dist/utils";

dotenv.config();

const deployAndVerify = async (
    name: string,
    params: any[],
    canVerify: boolean = true,
    path?: string | undefined,
    proxyOptions?: DeployProxyOptions | undefined,
): Promise<Contract> => {
    const Factory: ContractFactory = await ethers.getContractFactory(name);
    const instance: Contract = proxyOptions
        ? await upgrades.deployProxy(Factory, params, proxyOptions)
        : await Factory.deploy(...params);
    await instance.deployed();

    if (canVerify)
        await run(`verify:verify`, {
            contract: path,
            address: instance.address,
            constructorArguments: proxyOptions ? [] : params,
        });

    console.log(`${name} deployed at: ${instance.address}`);

    return instance;
};

async function main() {
    // const pmt = await deployAndVerify(
    //     "USDC",
    //     [],
    //     true,
    //     "contracts/USDC.sol:USDC",
    // );

    const subscriptionManager = await deployAndVerify(
        "SubscriptionManager",
        [
            "0xa6Eb9c9ba8F77c6D8534203f620953c71dA36407",
            50000000,
            "0xB644e9B2b38DA1752dA7AE3767E829bcAbBf688f",
        ],
        true,
        "contracts/SubscriptionManager.sol:SubscriptionManager",
        {
            kind: "uups",
            initializer: "initialize",
            unsafeAllow: ["delegatecall"],
        }
    );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
