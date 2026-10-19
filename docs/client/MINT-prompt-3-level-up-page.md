# Prompt 3: the level-up page (burning $MNTD for a bear)

**For MINT's developers.** This is Prompt 1 specialised for the first feature holders need on
getminted.io: raising a bear's level by burning $MNTD. Holders mint on OpenSea's drop page, so
nothing on getminted.io sends a mint. Burning opens on 29 October, the same day as the mint, and
the mystery box's play page follows for the first cycle on 4 November. Paste **Prompt 1's text
first** (`MINT-prompt-1-contracts-client-general.md`, the section "The prompt"), then this prompt
below it, in your AI coding assistant at the root of `mintdotio/NFT`.

---

## The prompt

Build **the level-up page**, where a holder sees their bears and raises a bear's level by burning
$MNTD. Follow Prompt 1's rules (above) for everything that touches the contracts. Before designing
anything, read:
- `packages/contracts-client/examples/04-burn.test.ts` (plan, warnings, send; the refusals; a
  smart wallet's batch);
- `examples/05-transfer.test.ts` (why a transfer resets a level);
- `examples/06-errors.test.ts` (the catch pattern, a declined prompt, no gas, a plan stopped
  halfway);
- `examples/01-getting-started.test.ts` (a client before and after login).

### How levels work (what the page must explain to holders)

- Each bear has a **level from 0 to 5**. Burning $MNTD for a bear raises it.
  - The totals burned for a bear reach levels 1–5 at **1,666 / 3,333 / 8,333 / 16,666 / 41,666
    $MNTD**.
  - The levels multiply the bear's share of royalties: **1.00 / 1.10 / 1.25 / 1.45 / 1.70 /
    2.00** for levels 0–5.
  - Read both from the contract (`bears.thresholds()`, `bears.weights()`, weights on a basis of
    100). Do not hard-code them.
- **Only the bear's current owner can burn for it**, from their own $MNTD. An approved operator
  cannot.
- **Any transfer or sale resets the bear to level 0.** The burned $MNTD stays burned and the new
  owner starts again. The page must say this plainly, before every burn and on every bear that has
  a level.
- A burn above what level 5 needs is refused, so nothing is burned for nothing.
- Burning is **paused until 29 October**. While `bears.paused()` is true the page shows the bears
  and their levels, with the burn closed and "Level-up opens on 29 October".

### Where it lives and how it is built

- It belongs to `apps/webapp`, the only frontend. Read its `README.md` and look at how the MINT a
  Bear page (`/nft`, `src/features/nft/`) and the claim (`/claim`, `src/features/claim/`) are
  built before adding anything, and propose where the page goes before writing it: a new feature
  folder and route (for example `src/features/bears/` at `/bears`, with a link from `/nft`), or a
  section of `/nft`.
  - A feature folder holds `components/` (client components), `shared.ts` and `server/` (each
    file `import 'server-only'`); a new route gets a link in `src/components/AppNav.tsx`, an entry
    in `src/seo.ts` and an `opengraph-image.tsx`.
  - Keep the page's logic in plain TypeScript that can be tested without a browser, the way
    `src/features/nft/controller.ts` holds the MINT a Bear page's state machine and
    `useMintABear.ts` wraps it in a hook.
  - Build the UI from `@mint/ui` (`Panel`, `PanelHeader`, `EmptyState`, `DetailRow`,
    `ActionError`, `.button`) and MUI, in the NFT page's look. Page-specific styles stay in the
    feature folder. Do not add a UI library without asking.
  - Refusals in `role="alert"`, transaction progress in an `aria-live` region, labelled controls,
    visible focus; responsive to 375px with no horizontal overflow.
- **Wallet:** the app's one Privy login, through `@mint/wallet` only. The bears are in the wallet
  that minted them: the "NFT wallet" holders connect on `/nft` (`useConnectWallet` with
  `NFT_WALLET_LIST`, in `src/features/nft/useWhitelistHost.tsx`), or a Privy embedded wallet.
  `useEvmWallet()` lists the login's EVM wallets.
  - Robinhood Chain is already the wallet's default chain (`AppProviders`); add nothing to
    Privy's configuration.
  - Build the wallet client for the wallet that holds the bears with
    `createWalletClient({ account, chain, transport: custom(await wallet.getEthereumProvider()) })`,
    as `useWhitelistHost.tsx` does.
  - The library checks the wallet's chain before every write and refuses `WRONG_CHAIN` before
    anything is signed. Make sure the wallet is on Robinhood Chain before a burn
    (`wallet.switchChain(chainId)`), and on `WRONG_CHAIN` switch and plan again.
- **Configuration:** a validated `server/config.ts` in the feature folder (zod, read at runtime,
  as `src/features/claim/server/config.ts`), with new variables for the chain id, the
  `MintABear`, `Activation` and $MNTD addresses and the collection's deploy block, listed in
  `apps/webapp/.env.example`. The page receives the public subset; the chain id should agree with
  the app's (`src/server/app-chain.ts`).
- **Reads** use a `publicClient` over the chain's public RPC, as Prompt 1 says; a private RPC URL
  stays on the server.
- **Which bears a wallet holds.** The collection cannot list them. Use MINT's own indexer or
  OpenSea's API if the app has one; otherwise `client.events.index()` (the library's reference
  indexer over `Transfer` events, paged from the collection's deploy block). Show only bears whose
  `owner` (from `bears.get`) is the connected wallet.

### What the page does

1. **My bears.** For each bear, from `client.bears.get(tokenId)`: image and id; level (0–5);
   weight as a multiplier; $MNTD burned for it under this owner (`cumulative`, formatted with
   `client.units.formatMntd`); and $MNTD still needed for level 5 (`costToMax`). Show the wallet's
   $MNTD balance and its ETH on Robinhood Chain, which pays the gas.
2. **Choose a target level.** For a bear, offer the levels above its current one. For each, show
   the cost from `client.bears.costToReach(tokenId, level)`, which is the remainder to that level,
   not the total.
3. **Plan.** `const plan = await client.bears.planBurn({ tokenId, targetLevel, countOpenListings })`.
   - If `!plan.ok`, show `plan.userMessage`, keep the button disabled, and handle each code:
     - `ACTIVATION_PAUSED`: "opens on 29 October";
     - `NOT_BEAR_OWNER`: the bear is in another wallet;
     - `INSUFFICIENT_MNTD_BALANCE`: show what is missing;
     - `ALREADY_MAX_LEVEL` and `TARGET_REACHED`;
     - `TOKEN_DOES_NOT_EXIST`.
   - If it is ok, show the amount that will be burned and the steps: `plan.calls` holds an
     `approve` (only when the allowance is short) then the `burn`. Also show every
     `plan.warnings[].message`.
   - Pass `countOpenListings` (a function that returns the bear's open OpenSea listings) if the
     app can query OpenSea. Its `OPEN_LISTINGS` warning tells the holder that a listing filled
     after the burn hands the buyer a level-0 bear and loses the burn. Offer to cancel the
     listings on OpenSea first.
4. **Confirm and send.** `const result = await client.bears.executeBurn(plan)`.
   - Show each transaction's hash as soon as it exists, with a link to Robinhood Chain's explorer.
   - On success, `result.activated` has `previousLevel`, `newLevel`, `amount` and `cumulative`:
     show the new level and refresh the bear.
   - A wallet that can batch (a smart wallet) can send both calls at once: check its chain with
     `checkWalletChain(publicClient, smartWallet)`, then
     `sendTransaction({ calls: plan.calls.map(toTransaction) })`.
5. **Errors.** `try/catch` around the send, with `explainError(error, "burn")`:
   - `USER_REJECTED` is a cancel, not a failure;
   - `INSUFFICIENT_GAS_FUNDS` means add ETH on Robinhood Chain;
   - `WRONG_CHAIN` means switch the wallet to Robinhood Chain and try again;
   - a `MintABearError` with `completed` means the approval went through and the burn did not:
     say so and offer "Burn now" with a fresh plan, which will skip the approval;
   - anything else, show its `userMessage`.

   Robinhood Chain can block an individual wallet's transactions, so a refusal the library cannot
   name must still end in a readable message, never a raw error.
6. **Transfers.** If the page offers sending a bear, use `client.bears.planTransfer` and show its
   `RESETS_LEVEL` warning before the user confirms.

**The wallet's $MNTD balance** is `client.units.balanceOf()`: base units, the connected wallet's by
default. Compare it with the cost before enabling the button, and show what is missing.

### Test it

- **Read-only, against the testnet** (Prompt 1's addresses: `MintABear`, `Activation` and test
  $MNTD on 46630). Bears 1–3 exist; `Activation` is paused there, so the page must show the
  "opens on 29 October" state.
- **The whole flow, on a local fork of 46630** (Prompt 1, "Testing and local development"),
  impersonating the owner `0x7672…04Aa`:
  1. `setPaused(false)` on `Activation`;
  2. transfer a bear to your test wallet, or impersonate the owner as the user;
  3. send your wallet test $MNTD from the owner.

  Then burn to level 2 and check `levelOf` and `weightOf` with `cast`. Try each refusal: burn
  above level 5, burn with too little $MNTD, burn from a wallet that does not own the bear,
  decline the wallet prompt, and transfer the bear and see its level drop to 0.
- **Unit-test the page's own logic** (choosing levels, formatting amounts, mapping codes to the
  UI's states) with `node:test` in `apps/webapp/tests/`.
- Check the page in a browser, at 375px as well.
- Finish with `pnpm --filter @mint/webapp check` and `pnpm --filter @mint/webapp build`.
