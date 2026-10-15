# Tasks

One line per requirement id, in pick order. `/mnt:next` takes the first unticked line whose Task
is Open and not hard-gated; `/mnt:done` ticks it. CQ-22 is resolved (MINT, 15 October: winners claim from a prize vault, change
`raf-prize-vault-claims`), so the vault comes before RAF-18's payout step; RAF-14 is free since CQ-23 was resolved (MINT runs the worker, 12 October). RAF-33's payout record is built ahead of CQ-22 (change
`raf-33-record-ungated`), so RAF-17, RAF-19 and RAF-14 can quote it.

## 1. MysteryBox (Robinhood Chain)

- [x] 1.1 RAF-32 — cycles: `scheduleCycle(start, end, prizeCount, manifestHash)`, replaceable until `start`, `CycleInProgress`, `InvalidWindow`, `InvalidPrizeCount`, `CycleNotOpen`; owner in the constructor, two-step handover, `renounceOwnership` refused
- [x] 1.2 RAF-27 — playable ids: `excludeRange(from, to)`, `IdsExcluded`, `ExclusionFrozen`, `PLAYABLE` fixed at the first `scheduleCycle`
- [x] 1.3 RAF-28 — `open(tokenId)`: the RAF-28 Scenario test (`opened(cycleId, tokenId)` reads true; the buyer refused, then free next cycle); no per-wallet read on the hub (`ContractPaused` comes with RAF-34)

## 2. PrizeDraw (Arbitrum One)

- [x] 2.1 RAF-8 — one VRF v2.5 request and one word per open, `PrizeDraw` the subscription's consumer
- [x] 2.2 RAF-29 — `resolve(openIndex, cycleId, tokenId, opener)`: `OutOfOrder`, `UnknownCycle`, `InvalidTokenId`, `AlreadyResolved`, `CycleExhausted`, `DrawRequested`; outcomes applied in `openIndex` order; the draw's `scheduleCycle(cycleId, prizeCount, manifestHash)`
- [x] 2.3 RAF-30 — the win rule: `(w mod idsLeft) < prizesLeft`, both counters, `OutcomeRecorded`
- [x] 2.4 RAF-29 — (Defect MNT-157) `applyOutcomes` refuses with `InsufficientGas` when it stops for gas with fewer than `maxCount` applied and the next opening's word stored, so a wallet's gas estimate applies every ready outcome up to `maxCount`; a missing word or `maxCount` 0 returns 0; the callback and `resolve` still stop quietly (INV-28); INV-29 records the bound and the trade (a fixed gas limit with too large a `maxCount` makes no progress)

- [x] 2.5 RAF-33 — `recordPayout(openIndex, chainId, txHash)`: `NotAWin`, `AlreadyPaid`, `PrizePaid`, and the `payoutOf(openIndex)` read; assert `recordPayout` still works while the draw is paused (RAF-34's Scenario clause)

## 3. Both

- [x] 3.1 RAF-34 — pause on both: the hub's `setPaused` blocks `open`, the draw's blocks `resolve` while words already requested are still applied; `PausedSet`; payout records and reads unaffected; `end` unmoved
- [x] 3.2 RAF-16 — events carry the documented arguments
- [x] 3.3 RAF-17 — every read answers; `odds(cycleId)`
- [x] 3.4 RAF-19 — every acceptance case has a deterministic test
- [x] 3.5 DEL-6 — (Defect MNT-158) the client's mystery-box calls: `open`, the reads, and a wallet's shots left counted from `ownerOf`, `isExcluded` and `opened` per bear in one Multicall3 call

## 4. The worker (RAF-18 gated by CQ-22)

- [x] 0.1 Remove the undeployed whitelist registries (CQ-18, 12 October): `WhitelistClaim`, `WhitelistImport`, their tests, trees, mock and PoC; `runWhitelist` and `runWhitelistImport` in `Deploy.s.sol`; `export` and the registry `compare` overload in `WhitelistExport.s.sol`; the client's registry, voucher and import modules and ABIs, and its mint writes and proofs (CQ-19: holders mint on OpenSea's drop page; the mint reads stay); the docs that describe them
- [x] 0.2 Every bear plays (CQ-20, 12 October): remove the exclusion from `MysteryBox` (`excludeRange`, `isExcluded`, `excludedCount`, `EXPECTED_PLAYABLE`, `IdsExcluded`, `ExclusionFrozen`, `ExclusionsIncomplete`, `IdExcluded`; constructor `(owner, bears)`; `PLAYABLE` reads `MAX_BEARS`); `PrizeDraw` deployed with `playable` 4,444; the client's `excludeRange` and `isExcluded`; RAF-27's new Scenario and RAF-19's case; on top of line 0.1's branch
- [ ] 0.3 The client joins MINT's workspace (PR B, `feat/contracts-client-workspace`): rebuild it on `feat/contracts` once 0.1 and 0.2 are merged; list the transitive changes (`debug`, `@noble/curves`, the `zod` peer of viem and Privy); prove each Dockerfile's `pnpm install --frozen-lockfile --filter …`, the apps' tests, and one Privy login on staging; Lorenzo merges into `release/1.1` around 20–21 October, before the worker (RAF-18); `release/1.0` is not promoted before 29 October
- [x] 0.4 OPS-2 — (Defect MNT-163) deploy entry points for `MysteryBox(owner, bears)` and `PrizeDraw(owner, coordinator, keyHash, subscriptionId, callbackGasLimit, requestConfirmations, nativePayment, 4444, 1)` in `Deploy.s.sol`, from `script/config/<chain>.json`, with the read-back of every constructor value (`requestConfirmations` and `callbackGasLimit` against the coordinator's limits) and `PLAYABLE` on both chains; `playable` is `MAX_BEARS`, passed by the script and never read from config, and the script refuses to finish unless both `PLAYABLE` reads are 4,444 (MNT-161's review, R-1: a draw deployed with a stale 4,222 wedges the in-order relay with `CycleExhausted`), with DESIGN's odds sentence reworded to match; `OPS-2` is Done, so this is a Defect against it when picked; needed by 29 October
- [x] 0.5 OPS-4 — rehearsal preparation for 16 October: `script/config/46630.json` and `4663.json` (collection), and a script that sets SeaDrop's allowlist on 46630 from a CSV and prints each wallet's proof (`AllowListTree.proof`); work on OPS-4's Task (MNT-64); with it, (Defect MNT-162) `runActivation` fails in forge's London simulation against the test $MNTD (`NotActivated`), so the rehearsal's `Activation` step needs a simulation EVM that runs it, with the deployed bytecode and the Sourcify verification unchanged
- [x] 4.1 RAF-14 — roles: the worker (`setWorker`, `WorkerSet`), non-owner and non-worker refusals
## 5. The prize vault (CQ-22, option B; change `raf-prize-vault-claims`)

- [ ] 5.1 RAF-35 — `PrizeVault(owner, signer)`: receives native, ERC-20, ERC-721, ERC-1155; `registerCycle(cycleId, start, end, prizes, manifestHash)` with `ManifestMismatch`, `Unfunded`, `InvalidPrizeCount`, `InvalidWindow`, `CycleStarted`, own-chain reservations; Solady two-step ownership, renounce refused; with it the vault's share of RAF-14, RAF-16, RAF-17 (every public read pinned from the artifact, like the box and the draw) and RAF-34, whose Tasks are Done
- [ ] 5.2 RAF-36 — `claim(cycleId, openIndex, prizeIndex, signature)`: the EIP-712 ticket signed by `signer`, `msg.sender` the winner, `InvalidTicket`, `AlreadyClaimed`, `ClaimClosed` at `end + CLAIM_GRACE` (1 hour), `WrongChain`, `UnknownCycle`, `ContractPaused`, safe transfers per kind, non-reentrant, `PrizeClaimed`
- [ ] 5.3 RAF-37 — `release(cycleId)` after the window and the owner's `withdraw(kind, token, id, amount, to)` refused below the reserved amount (`Reserved`); carry-over into a later cycle's list
- [ ] 5.4 OPS-2 — `runPrizeVault` in `Deploy.s.sol` through the CREATE2 deployer, the same address on every prize chain, every constructor value read back; `OPS-2` is Done, so this is a Defect against it when picked
- [ ] 5.5 OPS-3 — `verify.sh` knows `PrizeVault` and the prize chains and their testnets (1, 33139, 8453; 11155111, 33111, 84532); `OPS-3` is Done, so a Defect against it when picked
- [ ] 5.6 DEL-6 — the client's vault calls: funding transfers per prize kind from the prize wallet, `manifestHash` from the list, `registerCycle`, the ticket's typed data and `claim`, the reads, `release`, `withdraw`, `setSigner`, pauses; the worker's ticket signing; `DEL-6` is Done, so a Defect against it when picked

- [ ] 4.2 RAF-18 — the worker service (`apps/box-worker`, packaged like the whitelist API, run by MINT), its instructions, and the sequence end to end on the testnets through two cycles; its payout step signs and serves each win's ticket (`GET /tickets/:openIndex`), watches `PrizeClaimed` on every vault and records the claim with `recordPayout`; after section 5
