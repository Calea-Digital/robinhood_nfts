# Differential review: DEL-6, Defect MNT-174 (the client's prize-vault calls)

**Branch:** `mnt/DEL-6-174` in `~/trees/NFT-DEL-6-174`, against `feat/contracts` `dbd2c66`.

**Scope:**
- `packages/contracts-client/src/prizeVault.ts` (new);
- `src/errors.ts`, `src/client.ts`, `src/index.ts`, `src/prizeDraw.ts` (comment);
- `src/abi/prizeVault.ts` (generated);
- `test/prizeVault.test.ts` (new), `test/surface.test.ts`, `test/ContractsClient.tree.md`, README;
- in contracts: `test/mocks/MockPrizeTokens.sol` (three mocks), `PrizeDraw.sol` (NatSpec only:
  the metadata hash changes, the behaviour does not) and the RAF-27 quote in `MysteryBox.t.sol`.

**Risk: medium.** The library builds the transfers that fund the vaults, the claim that pays a
winner, and the owner's withdrawal. Nothing in the contracts' behaviour changed.

## Value paths reviewed

| Path | What could go wrong | Finding |
|---|---|---|
| `manifestHash` | A fingerprint different from the contract's would make every registration fail, or let the box, the draw and the vaults disagree | Encodes `(uint256,uint8,address,uint256,uint256)[]` as `abi.encode(prizes)`. Proven by registration on anvil; a field-order breakage is caught |
| `planFunding` / `fund` | Over- or under-funding a vault; sending from the wrong wallet | Sends `reserved + listAmount − held` per asset, from the prize wallet passed in, on that wallet's chain (`checkWalletChain` before each native send). Over-funding by a concurrent transfer is harmless: it stays withdrawable. Replacing a registered list asks for the old list's reservations too (documented) |
| `buildPrizeList` | Admitting a token the vault cannot keep reserved | ERC-165 for 721/1155, DN404 base/mirror, ERC-404, caller's `twinTokens`, one token as two kinds. A double-entry-point ERC-20 is caught only if named in `twinTokens` (it cannot be detected). A 721 without ERC-165 is refused (conservative) |
| `planClaim` / `claim` | A holder told a valid claim is invalid, or the reverse | Follows the vault's order. The facade sends from the connected wallet, so `msg.sender` is the winner the ticket names |
| `planWithdraw` / `withdraw` | Withdrawing reserved prizes | `available = held − reserved`, mirroring the vault. The chain refuses anything else anyway (`Reserved`) |
| `signTicket` | Signing for the wrong vault or chain | Domain = `("MintABear PrizeVault", "1", chainId, vault)`, so a ticket is valid on that vault only. A wrong domain version is caught by the tests |

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | Medium (availability) | `planClaim` checked tickets only through `publicClient.verifyTypedData`, which runs a deployless `eth_call`. An RPC that refuses it would turn every valid claim into `INVALID_TICKET` in the page | **Fixed:** a signer with no code is recovered locally (`recoverTypedDataAddress`); a contract signer goes through `verifyTypedData` (ERC-1271). A planted "always valid" recovery is caught |
| F2 | Low | The ERC-1271 path (a contract signer) is not exercised by the tests. The worker is an EOA (CQ-23) | Accepted; noted for the reviewer |
| F3 | Info | The vault's events are not in `readSystemEvents` or the reference indexer | Out of scope here. The worker's payout step (RAF-18) reads `PrizeClaimed` |
| F4 | Info | `planRegisterCycle` checks funding for a first registration only; a replacement's is left to the simulation, since only the chain lifts the old reservations first | Documented in the function |

## Evidence

- `test/prizeVault.test.ts`: 8 tests on anvil, 142 client tests in total.
- `surface.test.ts` places every `PrizeVault` function.
- Planted breakages: 16, all caught (four after targeted tests were added).
- Gates: fmt, build, 313 forge tests, coverage 100/100, Slither 47, verify 15/15, quotes 44/0,
  trees 26/0.
