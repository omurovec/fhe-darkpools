import { HardhatRuntimeEnvironment } from "hardhat/types";

export function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function waitForBlock(hre: HardhatRuntimeEnvironment, current?: number) {
  const targetBlock = current || (await hre.ethers.provider.getBlockNumber());
  while ((await hre.ethers.provider.getBlockNumber()) <= targetBlock) {
    await delay(50);
  }
}
