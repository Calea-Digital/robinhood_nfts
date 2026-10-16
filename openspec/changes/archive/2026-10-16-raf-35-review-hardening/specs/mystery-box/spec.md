## MODIFIED Requirements

### Requirement: RAF-35 — Prize vault and the cycle's prize list
**Kind:** work-item
Each cycle's prizes are held by a prize vault on the prize's chain: Robinhood Chain, Ethereum
and ApeChain, and Base when a cycle first uses it (MINT, 15 October 2026, CQ-22). The vault has
the same address on every chain and is owned by MINT's admin. It holds every kind of prize:
native coins (ETH, APE), tokens (ERC-20) and NFTs (ERC-721, ERC-1155). During cycle setup, MINT's
admin page sends the cycle's prizes from the prize wallet to the vault on each chain, then MINT's
admin registers the cycle's full prize list on every vault. The vault accepts the list only if
it is the list the cycle's fingerprint names and if it already holds every prize on its own
chain, so a published prize is provably there from the start. It also refuses a list that could
make a reservation disagree with what it can pay: a cycle longer than the box allows, an entry
that names nothing or says more than it reserves, and a token listed as two kinds of prize at
once. The list can be replaced until the cycle starts. From registration until the claim window
closes (RAF-36), the cycle's prizes on that chain are reserved for their winners.

*Technical note.* `PrizeVault(owner, signer)` in `packages/contracts`, deployed through the
CREATE2 deployer `0x4e59…956C` with the same arguments on every chain, so its address is the
same. A prize is `(chainId, kind, token, id, amount)` with kind native, ERC-20, ERC-721 or
ERC-1155; the list's fingerprint is `keccak256(abi.encode(prizes))` over the full ordered list,
the cycle's `manifestHash` on `MysteryBox` and `PrizeDraw` (RAF-32). Prize n of the list is the
draw's `prizeIndex` n (RAF-27, RAF-30). The owner's `registerCycle(cycleId, start, end, prizes,
manifestHash)` is refused when the list hashes to another value (`ManifestMismatch`), is empty
or longer than `MAX_PRIZES` (`InvalidPrizeCount`), has `end` before `start` or lasts longer than
90 days, the box's `MAX_CYCLE_LENGTH` (`InvalidWindow`), has an entry with an amount of 0, a
native entry naming a token or an id, an ERC-20 entry naming an id, or an ERC-721 entry whose
amount is not 1 (`InvalidPrize`), has an own-chain entry for a token the vault's reservations
already hold under another kind (`KindMismatch`), or the vault holds less of an entry for its
own chain than what is already reserved plus the entry (`Unfunded`), and once `start` has passed
(`CycleStarted`). It reserves each own-chain entry. A token's kind is held while any of its
entries is reserved, so it can be listed as another kind once its reservations are lifted. The
vault receives native coins, ERC-20 transfers and safe ERC-721 and ERC-1155 transfers.

#### Scenario: A cycle is registered only when funded and matching
- **GIVEN** a vault on chain 1 holding prize 2 of a cycle's list, an ERC-721, and not prize 4, an ERC-20 amount on chain 1
- **WHEN** the owner registers the list, then sends prize 4 and registers it again, and once more with an entry changed
- **THEN** the first registration reverts with `Unfunded`, the second succeeds and reserves prizes 2 and 4, and the changed list reverts with `ManifestMismatch`
