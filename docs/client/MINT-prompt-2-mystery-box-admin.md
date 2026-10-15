# Prompt 2: the mystery box admin page (cycles and prizes)

**For MINT's developers.** This is Prompt 1 specialised for the admin page MINT's admin uses to
set up each mystery-box cycle and its prizes. Paste **Prompt 1's text first**
(`MINT-prompt-1-contracts-client-general.md`, the section "The prompt"), then this prompt
below it, in your AI coding assistant at the root of `mintdotio/NFT`.

**What exists today and what comes next.** The library already covers scheduling a cycle on
both chains, the pauses, the worker and every read the page needs. The **prize vault**, which
holds each cycle's prizes and from which winners claim them (MINT's decision of 15 October), is
being built by Calea. Its contract and its library calls arrive in a later release of
`@mint/contracts-client`, before the first cycle on 4 November. This prompt builds the whole page
now and leaves the vault steps as clearly marked placeholders, to be wired when the release
lands.

---

## The prompt

Build **the mystery box admin page**: the page MINT's admin uses to set up, watch and pause
mystery-box cycles. Follow Prompt 1's rules (above) for everything that touches the contracts.
Read `packages/contracts-client/examples/10-mystery-box.test.ts` and
`packages/contracts/docs/RUNBOOK.md` ("Mystery box") before designing anything: the example shows
the admin calls working, and the runbook gives the order of operations the page must enforce.

### Where it lives and how it is built

- There is no admin area in the repository yet. Create a new app, `apps/box-admin`, modelled on
  `apps/claim`, so it shares a stack MINT already runs:
  - Next.js App Router, React 19, MUI and Emotion;
  - wagmi with RainbowKit for the wallet, which is MINT's admin `0x1530…6141`, an externally
    owned account in MetaMask or a similar wallet;
  - config read at runtime from environment variables;
  - the same security headers and `/health` and `/ready` routes;
  - pnpm only, one root lockfile, the same dependency versions as `apps/claim`.
- It is an operator tool. Do not link it from the public site. Deploy it the way MINT protects
  internal tools, and keep it working without a server secret: every write is signed by the
  admin's wallet.
- Read `owner()` from the box and the draw and compare it with the connected account.
  - If the connected account is not the owner, the page is read-only and says why.
  - The contracts refuse a non-owner anyway (`NOT_CONTRACT_OWNER`); the page should not offer the
    button.
- Configuration:
  - the Robinhood Chain id (4663, or 46630 on testnet) and the Arbitrum chain id (42161, or
    421614);
  - an RPC URL for each chain;
  - the addresses of `MintABear`, `MysteryBox` and `PrizeDraw`;
  - the deploy blocks of the box and the draw (log searches start there);
  - the prize vault's address (one address on every prize chain, once deployed) and an RPC URL
    for each prize chain (Robinhood Chain, Ethereum 1, ApeChain 33139, later Base 8453).

### Two chains, one wallet

The box is on Robinhood Chain and the draw on Arbitrum. Every cycle is scheduled on both, with
the same start, prize count and prize-list fingerprint (`manifestHash`).

`mysteryBoxAdmin.scheduleCycle` needs two wallet clients, each already on its own chain. With a
single injected wallet, run the steps yourself instead:
1. `const plan = await client.mysteryBoxAdmin.planScheduleCycle(terms)`. If `!plan.ok`, show
   `plan.userMessage` and stop.
2. Simulate the draw half first, so a draw that would refuse never leaves the box half alone:
   `simulate(drawPublicClient, account, drawScheduleCycleCall(drawAddress, plan.cycleId, terms))`.
3. Send the box half on Robinhood Chain: `execute(publicClient, walletClient, plan.call)`.
4. Switch the wallet to Arbitrum, rebuild the client with the draw's wallet client, and call
   `client.mysteryBoxAdmin.scheduleOnDraw(plan.cycleId, terms)`. It refuses with
   `CYCLE_TERMS_MISMATCH` if the terms differ from the box's.

If step 4 fails or the user stops, the page must show that the box half is done and the draw half
is not, and offer `scheduleOnDraw` again. The draw must be scheduled **before the cycle's start**.
Read the exact helpers' signatures in `src/calls.ts` (`simulate`, `execute`) and
`src/prizeDraw.ts` (`drawScheduleCycleCall`).

`pauseBox` sends on Robinhood Chain. `pauseDraw` and `setWorker` send on Arbitrum, and the
library checks that the draw's wallet is on Arbitrum.

### What the page does

1. **Status (the landing view), refreshed every 15 seconds:**
   - From `mysteryBox.state()`: the current cycle (id, start, end, prize count, `manifestHash`),
     open or closed, paused, openings so far, `PLAYABLE` (4,444).
   - For the same cycle, from `prizeDraw.state()`, `prizeDraw.cycle(cycleId)` and
     `prizeDraw.odds(cycleId)`: prizes left and bears left, how far the worker has relayed and
     applied, the worker address, paused.
   - Flag in red any difference between the box's and the draw's terms for the same cycle, and a
     cycle that is scheduled on the box but not on the draw.
   - Show times in UTC and the admin's local time; the contracts store Unix seconds as `bigint`.
2. **Schedule a cycle.** A form for start, end and prize count (and, once the vault ships, the
   prize list; see below).
   - Run `planScheduleCycle` as the admin types, and show its refusal live:
     - `CYCLE_IN_PROGRESS`: a cycle is open;
     - `CYCLE_INVALID_WINDOW`: the start is in the past or before the previous cycle's end, the
       end is before the start, or the window is longer than 90 days (`MAX_CYCLE_LENGTH`);
     - `INVALID_PRIZE_COUNT`: zero, or above 4,444.
   - Say whether it **replaces** a cycle that has not started (`plan.replaces`). A cycle's terms
     can be replaced until its start, and never after.
   - Then the four steps above, with each transaction's hash and an explorer link (Robinhood
     Chain's explorer, Arbiscan).
3. **Pauses.** Pause and unpause the box and the draw separately, with the rule from the runbook
   shown next to the buttons: *pause the box before the draw; lift the draw's pause before the
   box's.* Pausing never moves a cycle's end.
4. **Worker.** Show the draw's `worker()` and its ETH balance on Arbitrum. `setWorker(address)`
   sets it. The zero address stops relays and payout records until a worker is set again; ask for
   confirmation.
5. **Activity.** A table of openings for the selected cycle, built from `client.events.read()`
   (paged from the deploy blocks) and `prizeDraw.events()`. One row per opening: index, bear,
   opener, relayed or not, outcome (won, with the prize number, or lost), and the payout or claim
   transaction.
   - Highlight an opening not relayed after five minutes, and a win with no payout record.
   - Robinhood Chain's RPC refuses a log query over 10,000,000 blocks; the library pages for
     you, so keep `deployBlock` and `logBlockRange` set.

### Prizes and the prize vault (placeholders until the library release)

The order MINT follows for each cycle, which the page should walk the admin through as a
checklist:
1. Publish the cycle's prize list. Each prize is a chain, a kind (native coin, ERC-20, ERC-721 or
   ERC-1155), a token address, a token id and an amount. Prize *n* in the list is the *n*-th prize
   won in the cycle.
2. **Fund the vaults:** send each prize from MINT's prize wallet `0xf6c0…83e3` to the prize vault
   on the prize's chain. This step is signed by the **prize wallet**, not the admin, so the page
   asks the operator to connect it for this step.
3. **Register the list** on the vault on every prize chain (signed by the admin). The vault refuses
   a list that is not the cycle's published list, or one whose prizes on that chain it does not
   hold yet.
4. **Schedule the cycle** on the box and the draw with the same fingerprint, before the start.

Build now:
- the prize-list editor, with validation (at most 10 prizes; chain, kind, address, id and amount
  per kind) and a JSON export of the list to publish;
- the checklist UI;
- a per-chain view of what each vault must hold.

Mark steps 2 and 3, and the fingerprint, as **"waiting for the vault release"**. **Do not compute
`manifestHash` yourself and do not hand-write vault calls**: the library will export the
fingerprint helper and the vault calls (funding transfers per prize kind, `registerCycle`, the
vault's reads, `release`, `withdraw`, `setSigner`, the vault's pause), and the box, the draw and
every vault must agree on the fingerprint byte for byte. Until then, on the testnet only, the
schedule form may take a `manifestHash` typed in by hand.

After each cycle's end, the vault's claim window stays open for one hour. After that the page
offers `release` for the cycle (anyone may send it), and the unclaimed prizes stay in the vault
for a later cycle. These also arrive with the vault release.

### Test it

- **Against the testnet contracts** listed in Prompt 1, read-only, with any wallet: the status
  view and the activity table must show two past cycles, six openings, three wins and three
  payouts.
- **Against a local fork of both chains,** impersonating the owner `0x7672…04Aa` (Prompt 1,
  "Testing and local development"). Schedule a cycle, try every refusal above, pause and
  unpause, change the worker. One fork per chain on two ports, with the wallet configured for
  both.
- **Unit-test the page's own logic** (the form's validation, the checklist's state, the
  two-chain step machine and its recovery) with `node --test`.
- Finish with `pnpm check` and `pnpm build` for the new app.
