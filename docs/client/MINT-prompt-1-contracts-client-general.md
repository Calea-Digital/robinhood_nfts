# Prompt 1: building UI on `@mint/contracts-client` (general)

**For MINT's developers.** Paste the prompt below into your AI coding assistant (Claude Code,
Cursor or similar) at the root of the `mintdotio/NFT` repository, then replace the last line
with the feature you want. It gives the assistant the rules for using the client library
correctly. Prompts 2 and 3 are this prompt specialised for the mystery box admin and the
level-up page.

**Before you start, check two things:**
- The client library on `release/1.1` is the current one. PR #17 brings the current library;
  until it merges, `packages/contracts-client` still carries removed whitelist modules.
- `packages/contracts-client` is part of the pnpm workspace. Calea's PR B adds it, with its
  dependencies, to the root lockfile; until then no app can depend on it. Do not wire it in by
  hand.

---

## The prompt

You are working in MINT's monorepo (`mintdotio/NFT`). Read `AGENTS.md` first and follow it: pnpm
only, one root lockfile, write "MINT" in uppercase, never write to production APIs or databases
without explicit approval, never commit or push unless asked.

The task is to build UI that talks to the MintABear smart contracts. **All contract access goes
through the TypeScript client library `@mint/contracts-client` in `packages/contracts-client`.**
Do not copy ABIs into the app, do not call `writeContract` on these contracts directly, and do
not re-implement checks the library already makes. The library is typed against the deployed
contracts' ABIs, simulates every write before sending it, and turns every revert into an error
with a message ready to show a holder.

### 1. Learn the library from its own documentation before writing code

Read these, in this order, and base your code on what they show rather than on assumptions:
1. `packages/contracts-client/README.md`: Quick start, The client, Wallets (Privy), Errors,
   The mystery box, Events and indexing.
2. `packages/contracts-client/examples/*.test.ts`: one flow per file, each a runnable usage
   example. `01-getting-started`, `02-mint-progress`, `04-burn`, `05-transfer`, `06-errors`,
   `07-indexing-and-split` and `10-mystery-box`. `examples/setup.ts` shows how a client is
   built for each role.
3. `packages/contracts-client/src/client.ts`: the facade `createMintABearClient` and the TSDoc on
   every method. Open the module behind a method (`src/activation.ts`, `src/mysteryBox.ts`,
   `src/prizeDraw.ts`, `src/mint.ts`, `src/events.ts`) when you need its exact types.
4. `packages/contracts-client/src/errors.ts`: the `ErrorCode` union and the `MESSAGES` map.

If something you need is not in the library, stop and say so; do not work around it. Calea
adds missing calls to the library.

### 2. The facts the code depends on

- **Chains.** The collection, `Activation` and the mystery box are on Robinhood Chain (mainnet
  4663, testnet 46630); the library exports `robinhoodChain` and `robinhoodChainTestnet`, use
  them as viem chains. The prize draw is on Arbitrum One (42161, testnet Arbitrum Sepolia
  421614); use viem's `arbitrum` / `arbitrumSepolia`. Make the chain and every address
  configuration (environment variables, read at runtime the way the app already reads its
  config), never constants in components.
- **One client per page:**
  ```ts
  import { createMintABearClient, robinhoodChainTestnet } from "@mint/contracts-client";
  const client = createMintABearClient({
    publicClient,               // viem PublicClient on Robinhood Chain, with a real RPC transport
    walletClient,               // viem WalletClient with an account; omit until the user connects
    addresses: { bears, activation, mntd, mysteryBox },
    draw: { publicClient: drawPublicClient, walletClient: drawWalletClient, address: prizeDraw }, // only where the draw is used
    deployBlock,                // the collection's deploy block: log searches start here
  });
  ```
  Build it once for reads, and again when the wallet connects or changes. Reads never need a
  wallet.
- **The public client needs a real RPC.** The library reads, simulates and waits for receipts
  through `publicClient`. If the app's wagmi config uses a browser transport that throws, as
  `apps/claim` does, create the library's `publicClient` with `http(rpcUrl)` from the app's
  config, or keep reads on the server and pass the results to the page.
- **Wallets.** Any viem `WalletClient` with an account works. The library has no wagmi or Privy
  dependency.
  - With wagmi, `getWalletClient(config, { chainId })` gives one.
  - With Privy, use `createWalletClient({ account, chain, transport: custom(await wallet.getEthereumProvider()) })`
    and add the chain to Privy's `supportedChains`.
  - **The library checks the chain only for the draw's wallet.** The app must make sure the
    wallet is on Robinhood Chain before any collection, `Activation` or box write: use the
    network guard the app already has, or `switchChain`.
- **Big numbers are `bigint`.** Token ids, amounts, timestamps and cycle ids are `bigint`; levels
  and prize counts are `number`. Use `client.units.formatMntd` / `parseMntd` for $MNTD (18
  decimals, read from the token). Never use JavaScript numbers for amounts.
- **A wallet's bears.** The collection cannot list a wallet's tokens (ERC721A). Take a wallet's
  token ids from MINT's indexer or OpenSea's API, or from the library's
  `client.events.index()` (a reference indexer over `Transfer` events from `deployBlock`).

### 3. The patterns to follow

- **Plan, show, send.** Writes come as a pair: `planX(...)` checks everything on-chain and
  returns either `{ ok: true, calls, warnings, ... }` or `{ ok: false, code, userMessage, details }`
  without sending anything. Then `executeX(plan)` sends.
  - Render a refusal's `userMessage` and disable the button instead of letting the user sign a
    transaction that would revert.
  - Show every `warnings[].message` before the user confirms.
  - The one-call shortcuts (`burnTo`, `open`, `scheduleCycle`) are for scripts, not for UI.
- **Errors.** Wrap every send in `try/catch` and use `explainError(error, functionName)`, which
  returns `{ code, userMessage, details }` for anything thrown, including the wallet's own
  errors.
  - `USER_REJECTED` is not an error to show in red: the user cancelled.
  - `INSUFFICIENT_GAS_FUNDS` should tell the user to add ETH on the chain in question.
  - A `MintABearError` with `completed` set means a multi-step plan stopped halfway: show what
    went through, with the transaction hashes, and offer to continue.
  - Never show raw viem errors or revert data.
- **Transaction state.** Show the hash as soon as it exists, with a link to the chain's
  explorer, then the confirmed state from the returned receipt. Follow the app's existing UI
  conventions: in `apps/claim`, the phase state machine in `lib/client/claim-flow.ts` and inline
  MUI `Alert`s; in `apps/mintabear`, inline `role="alert"` elements.
- **Smart wallets.** If the connected wallet can batch, a plan's calls can go in one batch:
  `smartWallet.sendTransaction({ calls: plan.calls.map(toTransaction) })`.
- **Reads.** Poll reads (they are free) or refresh them after each confirmed write. Do not cache
  a bear's level across a transfer: any transfer resets it to 0.

### 4. Testing and local development

- **Contracts already on the testnets** (Robinhood Chain testnet 46630 and Arbitrum Sepolia
  421614), deployed by Calea and verified on Sourcify; use them for reads and screens:
  - `MintABear`: `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` (46630)
  - `Activation`: `0x389578ECe1E63DBEe48c9b22504D1Af29E2aef2f` (46630; paused)
  - `MysteryBox`: `0xA15a5B96849435B0030F1F6D6E3f886c8C0d55a7` (46630)
  - `PrizeDraw`: `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` (421614; the same address as the
    collection, on another chain)
  - test $MNTD: `0x63573eD184850Df903C908314Bc6aA3fD6d0128B` (46630)
  - deploy blocks: on 46630, the collection `135822444`, `Activation` `135823655` and the box
    `135825279`; on 421614, the draw `319417133`.

  They are owned by Calea's rehearsal wallet: ask Calea for owner actions (unpausing, a cycle,
  ownership of a test copy), bears or test $MNTD for your wallet.
- **For writes without waiting on anyone,** run a local fork and impersonate the owner. For
  example:
  ```sh
  anvil --fork-url https://rpc.testnet.chain.robinhood.com --port 8545
  cast rpc anvil_impersonateAccount 0x7672D1F3C832796D378827019a9f9Bf4D80404Aa --rpc-url http://127.0.0.1:8545
  cast send <contract> "<function>" <args> --unlocked --from 0x7672D1F3C832796D378827019a9f9Bf4D80404Aa --rpc-url http://127.0.0.1:8545
  ```
  Point the app's RPC at `http://127.0.0.1:8545` with chain id 46630, and fund your test wallet
  with `cast rpc anvil_setBalance <wallet> 0x56BC75E2D63100000`.
- **Tests.** Test the app's own logic with the app's test runner (`node --test` with tsx in
  MINT's apps). For a flow against a real chain, copy the pattern of the library's examples:
  start anvil, deploy, drive the flow, assert on reads. Run the app's `pnpm check` and
  `pnpm build` before finishing.

### 5. Done means

- every contract call goes through `@mint/contracts-client`;
- every refusal and error a user can meet shows its `userMessage`;
- chains and addresses come from configuration;
- the flow works on the testnet or a local fork, including at least one refusal;
- `pnpm check` and `pnpm build` pass for the app.

When you finish, list the library functions you used and anything you needed from the library
that it does not have.

**The feature to build:** <describe the screen or flow here>
