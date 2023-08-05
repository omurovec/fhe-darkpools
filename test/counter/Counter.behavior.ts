import { expect } from "chai";
import hre from "hardhat";

import { waitForBlock } from "../../utils/block";

export function shouldBehaveLikeCounter(): void {
  it("should add amount to the counter and verify the result", async function () {
    const amountToCount = 10;

    const eAmountCount = this.instance.instance.encrypt32(amountToCount);
    await this.counter.connect(this.signers.admin).add(eAmountCount);

    await waitForBlock(hre);

    const eAmount = await this.counter.connect(this.signers.admin).getCounter(this.instance.publicKey);
    const amount = this.instance.instance.decrypt(await this.counter.getAddress(), eAmount);

    expect(amount === amountToCount);
  });
}
