import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { activationAbi, mintABearAbi, whitelistClaimAbi, MAX_BEARS } from "../src/index.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import { deployFixture, type Fixture } from "./setup/fixture.js";

describe("fixture", () => {
  let anvil: Anvil;
  let f: Fixture;

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
  });
  afterAll(() => anvil.stop());

  it("deploys the tranche-1 system from out/ and the generated ABIs read it", async () => {
    /* Scenario:
       Given the Foundry artifacts deployed on anvil
       When the generated ABIs read each contract
       Then the collection caps at 4,444, the registry has 1,000 spots and Activation reads its collection */
    const read = f.publicClient.readContract;
    expect(await read({ address: f.bears, abi: mintABearAbi, functionName: "MAX_BEARS" })).toBe(BigInt(MAX_BEARS));
    expect(await read({ address: f.bears, abi: mintABearAbi, functionName: "maxSupply" })).toBe(4444n);
    expect(await read({ address: f.registry, abi: whitelistClaimAbi, functionName: "spotsLeft" })).toBe(1000n);
    expect(await read({ address: f.activation, abi: activationAbi, functionName: "BEARS" })).toBe(f.bears);
  });
});
