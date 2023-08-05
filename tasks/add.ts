import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import { createFheInstance } from "../utils/instance";

task("task:addCount")
  .addParam("amount", "Amount to add to the counter (plaintext number)")
  .addParam("account", "Specify which account [0, 9]")
  .setAction(async function (taskArguments: TaskArguments, hre) {
    const { ethers, deployments } = hre;

    const Counter = await deployments.get("Counter");

    const signers = await ethers.getSigners();

    const counter = await ethers.getContractAt("Counter", Counter.address);

    console.log(`contract at: ${Counter.address}, for signer: ${signers[taskArguments.account].address}`);

    const { instance } = await createFheInstance(hre, Counter.address);
    const eAmount = instance.encrypt32(Number(taskArguments.amount));

    await counter.connect(signers[Number(taskArguments.account)]).add(eAmount);

    console.log(`Added ${taskArguments.amount} to counter!`);
  });
