import { ethers } from "hardhat";
import hre from "hardhat";

import { waitForBlock } from "../../utils/block";
import { createFheInstance } from "../../utils/instance";
import type { Signers } from "../types";
import { shouldBehaveLikeCounter } from "./Counter.behavior";
import { deployCounterFixture, getTokensFromFaucet } from "./Counter.fixture";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    // get tokens from faucet if we're on localfhenix and don't have a balance
    await getTokensFromFaucet();

    // deploy test contract
    const { counter, address } = await deployCounterFixture();
    this.counter = counter;

    // initiate fhevmjs
    this.instance = await createFheInstance(hre, address);

    // set admin account/signer
    const signers = await ethers.getSigners();
    this.signers.admin = signers[0];

    // wait for deployment block to finish
    await waitForBlock(hre);
  });

  describe("Counter", function () {
    shouldBehaveLikeCounter();
  });
});
