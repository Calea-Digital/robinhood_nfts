# Prompt 1: building UI on `@mint/contracts-client` (general)

**For MINT's developers.** Paste the prompt below into your AI coding assistant (Claude Code,
Cursor or similar) at the root of the `mintdotio/NFT` repository, then replace the last line
with the feature you want. It gives the assistant the rules for using the client library
correctly. Prompts 2 and 3 are this prompt specialised for the mystery box admin and the
level-up page.

**Where things stand.** The client library is in the pnpm workspace on `release/1.1`
(`packages/contracts-client`, merged on 17 October), with its dependencies in the root lockfile.
No app imports it yet: the first feature built on it adds it to `apps/webapp`, as the prompt
describes.

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
   `src/prizeDraw.ts`, `src/mint.ts`, `src/events.ts`, `src/calls.ts`) when you need its exact
   types.
4. `packages/contracts-client/src/errors.ts`: the `ErrorCode` union and the `MESSAGES` map.

If something you need is not in the library, stop and say so; do not work around it. Calea
adds missing calls to the library.

### 2. Where the code goes

- **`apps/webapp` is the only frontend** (Next.js 16, App Router, Node 24). Read its `README.md`
  before adding anything. A new page is a new feature folder, `src/features/<name>/`, with
  `components/` (client components), `shared.ts` (types both sides use) and `server/`
  (route-handler logic and configuration, each file starting with `import 'server-only'`); a route
  under `app/`; a nav link in `src/components/AppNav.tsx`; and an entry in `src/seo.ts`
  (`pageMetadata(PAGES.<name>)`, plus an `opengraph-image.tsx`). Model it on
  `src/features/claim/` and `src/features/nft/`.
- **Add the library to the webapp.** Its package name is `@mint/contracts-client`. Add
  `"@mint/contracts-client": "workspace:*"` to `apps/webapp/package.json`'s dependencies, then run
  `pnpm install` at the repository root and keep the lockfile change. Its only peer dependency is
  `viem`, which the webapp already has.
  - The package exports its built `dist/`. Run `pnpm --filter @mint/contracts-client build` before
    the webapp's `check` or `build`.
  - `apps/webapp/Dockerfile` copies and installs only the packages the webapp uses today. Add the
    library's `package.json` to the install stage, copy the package, and build it before the
    webapp's build. Prove it with a local `docker build -f apps/webapp/Dockerfile .`. Add
    `packages/contracts-client/**` to the webapp service's Railway watch paths.
- **Server routes.** If a feature reads on the server, its route handlers follow `AGENTS.md`:
  validate with zod, bound the query and body (`readQuery`, `readJson`), rate-limit
  (`RateLimiter` and `clientKey`), answer with `privateJson`, and never let an upstream error's
  text reach a response. `app/api/claim/*` shows the pattern.
- **UI.** Use `@mint/ui`'s `Panel`, `PanelHeader`, `EmptyState`, `DetailRow` and `ActionError`,
  and its `.button` class; do not restyle a panel per page. Every page works at 375px with no
  horizontal overflow. Labelled controls, `aria-live` for async status, `role="alert"` for
  refusals, visible focus.

### 3. The facts the code depends on

- **Chains.** The collection, `Activation` and the mystery box are on Robinhood Chain (mainnet
  4663, testnet 46630). Use the chain objects the app already has, from `@mint/wallet/chains`
  (`robinhoodChain`, `robinhoodChainTestnet`); the library's own exports of the same names are
  equivalent. The prize draw is on Arbitrum One (42161, testnet Arbitrum Sepolia 421614); use
  viem's `arbitrum` / `arbitrumSepolia`. Make the chain and every address configuration, never
  constants in components: environment variables read at runtime by a validated config module
  in the feature's `server/config.ts` (zod; errors name variables, never values), with the public
  subset passed to the page, as `src/features/claim/server/config.ts` does.
- **One client per page:**
  ```ts
  import { createMintABearClient } from "@mint/contracts-client";
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
  through `publicClient`. In the browser, build it with
  `createPublicClient({ chain, transport: http() })` over the chain's public RPC, as the app's
  wagmi reads do. A private RPC URL is a server-only value: use it only in route handlers, and
  pass their results to the page.
- **Wallets.** Wallet and login hooks come only from `@mint/wallet` (`useEvmWallet`,
  `useWallets`, `useConnectWallet`). The library takes any viem `WalletClient` with an account;
  it has no wagmi or Privy dependency.
  - For the wallet wagmi signs with, `getWalletClient(config, { chainId })` from `wagmi/actions`,
    with `useConfig()`, the way the claim and staking panels call `writeContract`.
  - For a particular Privy wallet (the NFT wallet, for example), use
    `createWalletClient({ account, chain, transport: custom(await wallet.getEthereumProvider()) })`,
    as `src/features/nft/useWhitelistHost.tsx` does.
  - The wallet can only switch to a chain in the app's wallet chain list (`AppProviders`, built by
    `buildChains` in `src/features/swap/chains.ts`). Robinhood Chain is first and is the default.
    Add any other chain a feature signs on that is not there yet.
  - **The library checks the wallet's chain before every write it sends**, the draw's included. A
    wallet on another network is refused with `WRONG_CHAIN` before anything is signed. Show its
    `userMessage`, or switch (`switchChain` from `wagmi/actions`, or the Privy wallet's
    `switchChain`) and retry. The nav's `WalletButton` already asks a new wallet to switch to
    Robinhood Chain.
- **Big numbers are `bigint`.** Token ids, amounts, timestamps and cycle ids are `bigint`; levels
  and prize counts are `number`. Use `client.units.formatMntd` / `parseMntd` for $MNTD (18
  decimals, read from the chain). Never use JavaScript numbers for amounts.
- **A wallet's bears.** The collection cannot list a wallet's tokens (ERC721A). Take a wallet's
  token ids from MINT's indexer or OpenSea's API, or from the library's
  `client.events.index()` (a reference indexer over `Transfer` events from `deployBlock`).

### 4. The patterns to follow

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
  explorer, then the confirmed state from the returned receipt. Follow the claim's pattern: a
  phase state machine in plain TypeScript (`src/features/claim/client/claim-flow.ts`, tested in
  `tests/claim-flow.test.ts`), MUI `Alert`s inside a `role="status"` `aria-live` region, and
  `ActionError` from `@mint/ui` for refusals.
- **Smart wallets.** If the connected wallet can batch, a plan's calls can go in one batch. That
  send is the page's, not the library's, so check the chain first:
  `await checkWalletChain(publicClient, smartWallet)`, then
  `smartWallet.sendTransaction({ calls: plan.calls.map(toTransaction) })`.
- **Reads.** Poll reads (they are free) or refresh them after each confirmed write. Do not cache
  a bear's level across a transfer: any transfer resets it to 0.

### 5. Testing and local development

- **Contracts already on the testnets** (Robinhood Chain testnet 46630 and Arbitrum Sepolia
  421614), deployed by Calea and verified on Sourcify; use them for reads and screens:
  - `MintABear`: `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` (46630)
  - `Activation`: `0x389578ECe1E63DBEe48c9b22504D1Af29E2aef2f` (46630; paused)
  - `MysteryBox`: `0xA15a5B96849435B0030F1F6D6E3f886c8C0d55a7` (46630)
  - `PrizeDraw`: `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` (421614; the same address as the
    collection, on another chain)
  - `PrizeVault`: `0xAE51fA4E8f5089fE0D3017589fDa851475bF383d` (46630; its calls arrive in the
    library's next release)
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
  Point the feature's RPC at `http://127.0.0.1:8545` with chain id 46630, and fund your test
  wallet with `cast rpc anvil_setBalance <wallet> 0x56BC75E2D63100000`. The CSP in `proxy.ts`
  allows browser connections over https and wss only: for browser reads against the fork, allow
  `http://127.0.0.1:8545` in development only, with a comment saying why, or read through the
  server.
- **Tests.** Test the feature's own logic (state machines, adapters, parsers, formatting) with
  `node:test` in `apps/webapp/tests/<name>.test.ts`; `pnpm --filter @mint/webapp check` runs them
  with the typecheck. For a flow against a real chain, copy the pattern of the library's
  examples: start anvil, deploy, drive the flow, assert on reads. Check the UI in a running
  browser (`pnpm dev:webapp`), at 375px as well. Run `pnpm --filter @mint/webapp check` and
  `pnpm --filter @mint/webapp build` before finishing.

### 6. Done means

- every contract call goes through `@mint/contracts-client`;
- every refusal and error a user can meet shows its `userMessage`;
- chains and addresses come from validated runtime configuration;
- the page follows `AGENTS.md`: a feature folder, `@mint/ui` panels, `@mint/wallet` hooks only,
  SEO metadata, accessible and responsive to 375px;
- the flow works in a browser on the testnet or a local fork, including at least one refusal;
- `pnpm --filter @mint/webapp check` and `pnpm --filter @mint/webapp build` pass, and the
  webapp's Docker image builds.

When you finish, list the library functions you used and anything you needed from the library
that it does not have.

**The feature to build:** <describe the screen or flow here>
