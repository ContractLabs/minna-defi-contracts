import { Contract, ContractFactory } from "ethers";
import { ethers, run, upgrades } from "hardhat";

async function main(): Promise<void> {
  const Factory: ContractFactory = await ethers.getContractFactory("SubscriptionManager");
  const contract: Contract = await upgrades.upgradeProxy("0xa10f0AD113FA2D95D7f34B76B21932FFA52b65B0", Factory, { kind: "uups", unsafeAllow: ["delegatecall"] });
  await contract.deployed();
  console.log("Factory upgraded to : ", await upgrades.erc1967.getImplementationAddress(contract.address));

  await run(`verify:verify`, {
    address: contract.address,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
