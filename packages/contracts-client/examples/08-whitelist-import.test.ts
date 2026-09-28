/**
 * Example 8 — MINT's admin page, with the owner-imported whitelist (`WhitelistImport`, WL-7).
 *
 * When MINT deploys `WhitelistImport` instead of `WhitelistClaim`, nobody claims: MINT's admin
 * uploads a CSV of eligible wallets and the page writes it to the chain. The page does three things:
 *
 * 1. parse and show the file (`whitelistImport.parseCsv`, or `plan` straight from the text);
 * 2. plan the calls that make the chain equal to the file, and show the summary;
 * 3. send the plan from the admin's wallet.
 *
 * Until `closeAt` the admin can upload a corrected file and plan again. After it the list is final,
 * and it is exported to Studio exactly as a claimed whitelist is.
 */
import { afterAll, beforeAll, expect, it } from "vitest";

import { createMintABearClient, explainError } from "@mintabear/contracts-client";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
beforeAll(async () => {
  chain = await localChain();
});
afterAll(() => chain.stop());

it("imports the CSV MINT uploads, then a corrected one, then freezes", async () => {
  /* Scenario:
     Given MINT's admin connected to the admin page and a CSV of three wallets
     When the page plans and sends it, then plans a corrected file and sends that, then the close passes
     Then the list is the file each time, a holder's page reads its allocations, and a later upload is refused as LIST_FROZEN */
  const admin = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.adminWallet, addresses: chain.importAddresses });
  const [alice, bob, carol] = [chain.address("alice"), chain.address("bob"), chain.address("carol")];

  // 1–2. The admin uploads the file; the page plans it and shows what will change.
  const file = `wallet,allocations\n${alice},2\n${bob},1\n${carol},1\n`;
  const plan = await admin.whitelistImport.plan(file);
  if (!plan.ok) throw new Error(plan.userMessage);
  expect({ add: plan.add.length, remove: plan.remove.length, total: plan.total }).toEqual({ add: 3, remove: 0, total: 4 });

  // 3. The admin confirms; the page sends the plan (one batch here).
  await admin.whitelistImport.execute(plan);
  expect((await admin.whitelistImport.state()).spotsLeft).toBe(996n);

  // A holder's page reads the same registry for "you can mint N in the whitelist stage".
  const holder = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet("alice"), addresses: chain.importAddresses });
  expect(await holder.whitelist.claimsOf()).toBe(2);

  // A corrected file: bob goes up to 2, carol comes out. Planning again closes only the difference.
  const corrected = `wallet,allocations\n${alice},2\n${bob},2\n`;
  const fix = await admin.whitelistImport.plan(corrected, { removeUnlisted: true });
  if (!fix.ok) throw new Error(fix.userMessage);
  expect({ add: fix.add, remove: fix.remove, unchanged: fix.unchanged }).toEqual({ add: [{ wallet: bob, allocations: 1 }], remove: [carol], unchanged: 1 });
  await admin.whitelistImport.execute(fix);
  expect(await admin.whitelistImport.matches(admin.whitelistImport.parseCsv(corrected))).toBe(true);

  // A bad file is refused before anything is sent, with the line to fix.
  try {
    admin.whitelistImport.parseCsv(`wallet,allocations\n${alice},3\n`);
  } catch (error) {
    expect(explainError(error).userMessage).toBe('Line 2 of the whitelist file is invalid: allocations must be 1 or 2, found "3".');
  }

  // After closeAt the list is final: the page's next upload is refused with a message to show.
  const { closeAt } = await admin.whitelistImport.state();
  await chain.advance(closeAt - (await chain.now()) + 1n);
  const late = await admin.whitelistImport.plan(file);
  expect(late.ok).toBe(false);
  if (!late.ok) expect(late.code).toBe("LIST_FROZEN");
  expect((await admin.whitelistImport.state()).frozen).toBe(true);
});
