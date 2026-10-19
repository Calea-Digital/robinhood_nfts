# Prompt 2: the mystery box admin page (cycles and prizes)

**For MINT's developers.** This is Prompt 1 specialised for the admin page MINT's admin uses to
set up each mystery-box cycle and its prizes. Paste **Prompt 1's text first**
(`MINT-prompt-1-contracts-client-general.md`, the section "The prompt"), then this prompt
below it, in your AI coding assistant at the root of `mintdotio/NFT`.

**What exists today and what comes next.** The library already covers scheduling a cycle on
both chains, the pauses, the worker and every read the page needs. The **prize vault**, which
holds each cycle's prizes and from which winners claim them (MINT's decision of 15 October), is
built: `packages/contracts/src/PrizeVault.sol`, with its operations in
`packages/contracts/docs/RUNBOOK.md`, "Prize vault". It reaches `release/1.1` with PR #25; read
both on that PR's branch until it merges. Its library calls arrive in the next release of
`@mint/contracts-client`, before the first cycle on 4 November. This prompt builds the whole page
now and leaves the vault steps as clearly marked placeholders, to be wired when the release
lands.

---

## The prompt

Build **the mystery box admin page**: the page MINT's admin uses to set up, watch and pause
mystery-box cycles. Follow Prompt 1's rules (above) for everything that touches the contracts.
Read `packages/contracts-client/examples/10-mystery-box.test.ts` and
`packages/contracts/docs/RUNBOOK.md` ("Mystery box" and "Prize vault") before designing
anything: the example shows the admin calls working, and the runbook gives the order of
operations the page must enforce.

### Where it lives and how it is built

- It is a page of `apps/webapp`, the only frontend: a feature folder `src/features/box-admin/`
  (`components/`, `shared.ts`, `server/config.ts`) and a route such as `app/admin/box/page.tsx`.
  Propose the path before writing it.
- It is an operator tool. Do not link it from `AppNav` or the public pages, keep it out of
  `PAGES` in `src/seo.ts` (which feeds the sitemap), give it metadata with
  `robots: { index: false, follow: false }`, and add its path to `app/robots.ts`'s `disallow`.
  Protect the route the way MINT protects internal tools, and keep it working without a server
  secret: every write is signed by the admin's wallet.
- **Wallet:** MINT's admin `0x1530…6141`, an externally owned account, connected in MetaMask or a
  similar wallet through the app's one login (`@mint/wallet`; MetaMask is a primary login
  method). Build the wallet clients as Prompt 1 says. The admin signs on Robinhood Chain and on
  Arbitrum, and later on each prize chain: make sure each of these chains, and their testnets,
  is in the app's wallet chain list.
- Read `owner()` from the box and the draw and compare it with the connected account.
  - If the connected account is not the owner, the page is read-only and says why.
  - The contracts refuse a non-owner anyway (`NOT_CONTRACT_OWNER`); the page should not offer the
    button.
- **Configuration**, read at runtime by `server/config.ts` (zod, as the claim's), with the public
  subset passed to the page:
  - the Robinhood Chain id (4663, or 46630 on testnet) and the Arbitrum chain id (42161, or
    421614);
  - an RPC URL for each chain, under Prompt 1's rule: public RPCs in the browser, private ones on
    the server only;
  - the addresses of `MintABear`, `MysteryBox` and `PrizeDraw`;
  - the deploy blocks of the box and the draw (log searches start there);
  - the prize vault's address and an RPC URL for each prize chain (Robinhood Chain, Ethereum 1,
    ApeChain 33139, later Base 8453). The vault is created through the CREATE2 deployer, so it has
    one address on every prize chain; on 46630 it is
    `0xAE51fA4E8f5089fE0D3017589fDa851475bF383d`. Configure the address per chain all the same:
    a vault redeployed after a lost admin key would differ on that chain.

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

`pauseBox` sends on Robinhood Chain. `pauseDraw` and `setWorker` send on Arbitrum. The library
checks the wallet's chain before each of them (`WRONG_CHAIN`).

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
   opener, relayed or not, outcome (won, with the prize number, or lost), and the claim. A winner
   claims the prize from the vault on its chain; the worker then records the claim's transaction
   on the draw (`PrizePaid`, the opening's `payout`), and the row links it.
   - Highlight an opening not relayed after five minutes, and a win not yet claimed, with the
     time left until the claim deadline (the cycle's end plus one hour).
   - Robinhood Chain's RPC refuses a log query over 10,000,000 blocks; the library pages for
     you, so keep `deployBlock` and `logBlockRange` set.

### Prizes and the prize vault (placeholders until the library release)

The vault on each prize chain holds that chain's prizes for each cycle. It is owned by MINT's
admin. Its signer is the worker's key, which signs each winner's ticket; the signer is never the
admin. Only the winner claims, with that ticket, on the prize's chain, paying the gas there.

The order MINT follows for each cycle, all before the cycle's start, which the page should walk
the admin through as a checklist:
1. **Publish the cycle's prize list.** Each prize is a chain, a kind (native coin, ERC-20,
   ERC-721 or ERC-1155), a token address, a token id and an amount. Prize *n* in the list is the
   *n*-th prize won in the cycle.
2. **Schedule the cycle** on the box and the draw with the list's fingerprint (the steps above).
   The box gives the cycle its id.
3. **Fund the vaults:** send each prize from MINT's prize wallet `0xf6c0…83e3` to the vault on
   the prize's chain: a native prize as a plain transfer, an ERC-20 with `transfer`, an NFT with
   `safeTransferFrom`. This step is signed by the **prize wallet**, not the admin, so the page asks
   the operator to connect it for this step.
4. **Register the list** on the vault on every prize chain (signed by the admin), with the box's
   cycle id, start, end and fingerprint. The vault refuses a list that does not match the
   fingerprint, one whose prizes on that chain it does not hold yet, a window that ends before it
   starts or lasts over 90 days, and a list that is empty or too long. A cycle's list can be registered again until
   its start, and never after.
5. **Compare the terms on every chain:** the box, the draw and each vault must show the same
   start, end (box and vaults), prize count and fingerprint for the cycle. Flag a difference in
   red.

Build now:
- the prize-list editor, with validation (MINT plans at most 10 prizes a cycle, and the vault
  accepts 1 to 32; chain, kind, address, id and amount per kind: every amount above zero, a
  native prize names no token or id, an ERC-20 no id, an ERC-721 an amount of 1) and a JSON export of the list to publish;
- a warning, beside the editor, against tokens the vault cannot hold safely: a fee-on-transfer or
  rebasing token, a token with two addresses (a double-entry-point ERC-20, a DN404 / ERC-404
  pair), or an NFT listed under a standard it does not implement;
- the checklist UI;
- a per-chain view of what each vault must hold.

Mark steps 3 and 4, step 5's vault columns and the fingerprint as **"waiting for the vault
release"**. **Do not compute `manifestHash` yourself and do not hand-write vault calls**: the
library will export the fingerprint helper and the vault's calls and reads, and the box, the draw
and every vault must agree on the fingerprint byte for byte. Until then, on the testnet only, the
schedule form may take a `manifestHash` typed in by hand.

The vault's other operations also arrive with the release, and the page should leave a marked
place for each:
- **The claim window** runs from the cycle's start until one hour after its end. After that,
  anyone may release the cycle, once, and its unclaimed prizes stay in the vault for a later
  cycle's list. The page shows the deadline and offers the release after it.
- **Withdraw** takes only what no cycle reserves; the vault refuses more.
- **Rotate the signer** takes effect at once: every ticket signed by the old key stops working,
  and the worker must sign the unclaimed wins' tickets again. On a suspected leak of the worker's
  key, pause the vaults first, then rotate. Ask for confirmation.
- **Pause a vault** stops claims only and moves no window. Never pause a vault after a cycle's
  end: the grace hour keeps running, so a winner who could not claim loses the prize to the next
  cycle. The page says so beside the button.

### Test it

- **Against the testnet contracts** listed in Prompt 1, read-only, with any wallet: the status
  view and the activity table must show two past cycles, six openings, three wins and three
  recorded payouts.
- **Against a local fork of both chains,** impersonating the owner `0x7672…04Aa` (Prompt 1,
  "Testing and local development"). Schedule a cycle, try every refusal above, pause and
  unpause, change the worker. One fork per chain on two ports, with the wallet configured for
  both.
- **Unit-test the page's own logic** (the form's validation, the prize list's validation, the
  checklist's state, the two-chain step machine and its recovery) with `node:test` in
  `apps/webapp/tests/`.
- Check the page in a browser, at 375px as well.
- Finish with `pnpm --filter @mint/webapp check` and `pnpm --filter @mint/webapp build`.
