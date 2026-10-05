# MintABear - Security Audit Findings


## Executive Summary

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 3 |
| Informational | 3 |
| **Total findings** | **6** |

## Findings Index

| ID | Severity | Title |
|---|---|---|
| [L-01] | Low | A single-step ownership transfer can leave `Activation` paused permanently |
| [L-02] | Low | Off-chain: `buildAllowList` accepts a wallet listed twice, and the larger row's proof works |
| [L-03] | Low | Off-chain: the split's events mode checks that every bear is present, not that every transfer was seen |
| [I-01] | Informational | `WhitelistClaim` and `WhitelistImport` are unused, and the live whitelist has no root check |
| [I-02] | Informational | `IBurnableMNTD` is declared inside `Activation.sol` |
| [I-03] | Informational | Source comments mix process notes, project references and narrative into the NatSpec |

---

## Low Severity Findings

## [L-01] A single-step ownership transfer can leave `Activation` paused permanently

### Summary

`runActivation` pauses `Activation` and then hands ownership to MINT's admin in one step. If the admin address is wrong, nobody can ever unpause, and `Activation` has to be redeployed.

### Description

`Activation` inherits Solady `Ownable`. Its `transferOwnership(newOwner)` takes effect immediately, and the new owner never has to confirm. The deploy script calls `setPaused(true)` and then `transferOwnership(cfg.admin)`. Only the owner can call `setPaused`, and `renounceOwnership` reverts, so the pause can only be lifted by `cfg.admin`. If `cfg.admin` is an address nobody controls (a typo, the wrong network's Safe, an address copied from the wrong field), the contract stays paused permanently.

`MintABear` does not have this problem, because SeaDrop's `TwoStepOwnable` makes the admin call `acceptOwnership`.

### Relevant code

**Pause, then single-step handover - [`script/Deploy.s.sol:155-157`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/script/Deploy.s.sol#L155-L157)**

```solidity
        activation = new Activation(bears, cfg.mntd, cfg.thresholdsWhole, cfg.weights);
        activation.setPaused(true);
        activation.transferOwnership(cfg.admin);
```

**`setPaused` is owner-only - [`src/Activation.sol:278-282`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/Activation.sol#L278-L282)**

```solidity
    /// @notice Suspends or resumes `burn`. Reads and transfers are never affected.
    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedSet(paused_);
    }
```

**`renounceOwnership` always reverts - [`src/Activation.sol:284-288`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/Activation.sol#L284-L288)**

```solidity
    /// @notice Refused for every caller, the owner included, so the pause can always be set and
    ///         lifted.
    function renounceOwnership() public payable override {
        revert RenounceDisabled();
    }
```

**Solady: immediate `transferOwnership` - [`solady/src/auth/Ownable.sol:173-183`](https://github.com/vectorized/solady/blob/acd959aa4bd04720d640bf4e6a5c71037510cc4b/src/auth/Ownable.sol#L173-L183)**

```solidity
    /// @dev Allows the owner to transfer the ownership to `newOwner`.
    function transferOwnership(address newOwner) public payable virtual onlyOwner {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(shl(96, newOwner)) {
                mstore(0x00, 0x7448fbae) // `NewOwnerIsZeroAddress()`.
                revert(0x1c, 0x04)
            }
        }
        _setOwner(newOwner);
    }
```

**Solady: the unused two-step handover (48-hour expiry) - [`solady/src/auth/Ownable.sol:220-238`](https://github.com/vectorized/solady/blob/acd959aa4bd04720d640bf4e6a5c71037510cc4b/src/auth/Ownable.sol#L220-L238)**

```solidity
    /// @dev Allows the owner to complete the two-step ownership handover to `pendingOwner`.
    /// Reverts if there is no existing ownership handover requested by `pendingOwner`.
    function completeOwnershipHandover(address pendingOwner) public payable virtual onlyOwner {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            let handoverSlot := keccak256(0x0c, 0x20)
            // If the handover does not exist, or has expired.
            if gt(timestamp(), sload(handoverSlot)) {
                mstore(0x00, 0x6f5e8818) // `NoHandoverRequest()`.
                revert(0x1c, 0x04)
            }
            // Set the handover slot to 0.
            sstore(handoverSlot, 0)
        }
        _setOwner(pendingOwner);
    }
```

**The only ownership move the runbook documents is the collection's - [`docs/RUNBOOK.md:40-43`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/docs/RUNBOOK.md#L40-L43)**

```markdown
**Ownership is never renounced.** `renounceOwnership` reverts with `RenounceDisabled` for every
caller: the collection always has an owner, because every setting in this runbook is an owner
call. Ownership moves only by `transferOwnership` (the offer) and `acceptOwnership` (from the new
owner); `cancelOwnershipTransfer` withdraws an offer.
```

### Root cause

`Activation` uses Solady's single-step `transferOwnership` instead of its two-step handover, and the runbook documents no rotation procedure for it.

### Exploitation path

This is an operator error, not an attack. The admin, or the deploy config, transfers ownership to a mistyped address while `Activation` is paused.

### Impact

At deployment, the runbook's control check (`docs/RUNBOOK.md:170-172`) catches it and the cost is a redeploy. After switch-on, the only remedy is a new `Activation`, so **every holder loses the levels they paid for**, while the burned $MNTD stays destroyed.

### Preconditions / assumptions

- A non-zero address nobody controls is passed to `transferOwnership` while paused.
- **Severity rationale:** needs an admin error during a pause, but nothing detects it after switch-on and the cost falls on holders.

### Recommendation

Use Solady's two-step handover in `runActivation` and in any later rotation. The new owner calls `requestOwnershipHandover()`, then the current owner calls `completeOwnershipHandover(newOwner)`. Document the procedure in the runbook.

### PoC / Validation evidence

**PoC:** `test/audit/HolisticAudit.t.sol` - `test_activationRotationWhilePaused_toWrongAddress_losesEveryLevelOnRedeploy` (not included in the delivery)

```bash
forge test --match-path test/audit/HolisticAudit.t.sol --match-test test_activationRotationWhilePaused_toWrongAddress_losesEveryLevelOnRedeploy -vvv
```

```solidity
        activation.transferOwnership(wrong);
        assertEq(activation.owner(), wrong);

        vm.expectRevert(Ownable.Unauthorized.selector);
        activation.setPaused(false);
        vm.prank(intendedAdmin);
        vm.expectRevert(Ownable.Unauthorized.selector);
        activation.setPaused(false);

        Activation fresh = new Activation(address(bears), address(mntd), _thresholds(), _weights());
        assertEq(fresh.levelOf(1), 0);
        assertEq(fresh.levelOf(2), 0);
```

**Result:** PASS.

### Fix validation

The same test shows that with the two-step handover `completeOwnershipHandover(wrong)` reverts `NoHandoverRequest` and the owner can still unpause.

## [L-02] Off-chain: `buildAllowList` accepts a wallet listed twice, and the larger row's proof works

### Summary

The client's `buildAllowList` puts every CSV row into the Merkle tree, including a wallet that appears twice. Both leaves are in the root, so the wallet can mint under whichever row allows more, and `compare` cannot catch it when Studio built its root from the same CSV.

### Description

SeaDrop checks a minter's leaf, and the leaf's `maxTotalMintableByWallet` is that row's allocation. With two rows (1 and 2), the wallet holds two valid leaves and can present the allocation-2 proof. `entry(wallet)` in the client returns the first matching row, so the page can show 1 while 2 is mintable. The registry export refuses duplicates (`DuplicateWallet`), but the CSV path, which the live whitelist uses (WL-8), goes through `buildAllowList`, and `compare`'s CSV mode is not built yet.

### Relevant code

**Every row becomes a leaf, and `entry` returns the first match - [`packages/contracts-client/src/allowlist.ts:174-187`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/packages/contracts-client/src/allowlist.ts#L174-L187)**

```typescript
export function buildAllowList(rows: readonly AllowListRow[], stage: StageParams): AllowList {
  const leaves = rows.map((row) => allowListLeaf(row.wallet, rowMintParams(stage, row.allocations)));
  const root = allowListRoot(leaves);
  return {
    root,
    leaves,
    entry(wallet) {
      const i = rows.findIndex((row) => row.wallet.toLowerCase() === wallet.toLowerCase());
      if (i < 0) return undefined;
      const row = rows[i]!;
      return { mintParams: rowMintParams(stage, row.allocations), proof: allowListProof(leaves, leaves[i]!) };
    },
  };
}
```

**The registry path refuses a duplicate wallet - [`script/WhitelistExport.s.sol:157-160`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/script/WhitelistExport.s.sol#L157-L160)**

```solidity
        LibSort.sort(wallets);
        for (uint256 i = 1; i < wallets.length; ++i) {
            if (wallets[i] == wallets[i - 1]) revert DuplicateWallet(wallets[i]);
        }
```

**The runbook's one-row-per-wallet rule - [`docs/RUNBOOK.md:55-57`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/docs/RUNBOOK.md#L55-L57)**

```markdown
**2. Export the final CSV** from MINT's backend. The format is `wallet,allocations`, with one row
per wallet and its total, merged across every source: wagering, collaborations and giveaways. A
wallet that appears twice in Studio's allowlist can mint only under one of its rows. The
```

### Root cause

The CSV path has no duplicate-wallet check, unlike the registry path.

### Exploitation path

The final CSV lists a wallet twice, for example with 1 and 2 allocations. Studio builds its root from it, and the wallet mints with the larger row's proof.

### Impact

The wallet can mint more than its page shows, up to its largest row. If the stage sells out, those bears come out of other listed wallets' spots.

### Preconditions / assumptions

- The CSV breaks the runbook's one-row-per-wallet rule, and Studio keeps both rows (not verified).
- **Severity rationale:** needs an operator error, but nothing on the live path catches it.

### Recommendation

Make `buildAllowList` (and the planned CSV mode of `compare`) refuse a repeated wallet.

### PoC / Validation evidence

**PoC:** `test/audit/client/allowlistDuplicate.test.ts` (vitest, not included in the delivery)

```typescript
    const reversed = buildAllowList([rows[2], rows[1], rows[0]], STAGE);
    expect(reversed.root).toBe(list.root);
    const second = reversed.entry(DUP)!;
    expect(second.mintParams.maxTotalMintableByWallet).toBe(2n);
    expect(fold(leaf2, second.proof)).toBe(list.root);
```

**Result:** PASS.

### Fix validation

Not done.

## [L-03] Off-chain: the split's events mode checks that every bear is present, not that every transfer was seen

### Summary

`rowsFromEvents` rebuilds owners from `Transfer` logs and refuses with `SPLIT_MISSING_BEARS` only when the number of distinct ids differs from `totalSupply`. If the RPC omits a later transfer of a bear already seen, the check passes and that bear's share is paid to its previous owner, with no error.

### Description

The guard was written against silent log truncation, but it counts ids, not transfers. A dropped mint is caught, but a dropped resale is not, because the bear is still present under its earlier owner. The split's snapshot mode reads `ownerOf` at the closing block and is not affected. The two modes are not cross-checked by default.

### Relevant code

**Owners from the last `Transfer` seen per id - [`packages/contracts-client/src/split/inputs.ts:55-70`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/packages/contracts-client/src/split/inputs.ts#L55-L70)**

```typescript
  const owners = new Map<bigint, Address>();
  const range = a.blockRange ?? 10_000n;
  for (let from = a.fromBlock; from <= a.closingBlock; from += range) {
    const to = from + range - 1n < a.closingBlock ? from + range - 1n : a.closingBlock;
    const logs = await client.getLogs({ address: bears, events: [transferEvent, consecutiveTransferEvent], fromBlock: from, toBlock: to, strict: true });
    logs.sort((x, y) => (x.blockNumber === y.blockNumber ? x.logIndex - y.logIndex : x.blockNumber < y.blockNumber ? -1 : 1));
    for (const log of logs) {
      if (log.eventName === "Transfer") {
        owners.set(log.args.tokenId, log.args.to);
      } else {
        for (let id = log.args.fromTokenId; id <= log.args.toTokenId; id++) owners.set(id, log.args.to);
      }
    }
  }
  for (const [id, owner] of owners) if (owner === zeroAddress) owners.delete(id);
  return owners;
```

**The completeness check: distinct ids vs `totalSupply` - [`packages/contracts-client/src/split/inputs.ts:86-99`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/packages/contracts-client/src/split/inputs.ts#L86-L99)**

```typescript
export async function rowsFromEvents(
  client: Client,
  c: { bears: Address; activation: Address },
  a: EventsModeArgs,
): Promise<BearRow[]> {
  const [owners, totalSupply] = await Promise.all([
    ownersFromTransferLogs(client, c.bears, a),
    client.readContract({ address: c.bears, abi: mintABearAbi, functionName: "totalSupply", blockNumber: a.closingBlock }),
  ]);
  // A fromBlock after the first mint, or an RPC that silently truncates getLogs, would drop bears
  // and underpay their owners; no bear can be burned, so every minted id has an owner.
  if (BigInt(owners.size) !== totalSupply) {
    throw new ClientRefusal("SPLIT_MISSING_BEARS", { owned: owners.size, totalSupply, closingBlock: a.closingBlock });
  }
```

### Root cause

Completeness is checked on the set of ids, not on each id's current owner.

### Exploitation path

An RPC silently drops the `Transfer` of a resale, and the split pays the bear's share to the seller.

### Impact

The previous holder is paid instead of the current one, and no error is raised.

### Preconditions / assumptions

- The split runs in events mode against an RPC that drops logs silently (mainstream RPCs return an error instead).
- **Severity rationale:** unlikely, but the money goes to the wrong person without any signal.

### Recommendation

After `rowsFromEvents`, read `ownerOf(id)` at the closing block for each row and refuse any mismatch.

### PoC / Validation evidence

**PoC:** `test/audit/client/splitEventsTruncation.test.ts` (vitest with a custom transport, not included in the delivery)

```typescript
    const rows = await rowsFromEvents(clientReturning([MINT_1, MINT_2], seen), addresses, args);
    expect(rows).toEqual([
      { tokenId: 1n, owner: A, weight: 100 },
      { tokenId: 2n, owner: C, weight: 100 },
    ]);
```

Bear 1 was sold from A to B. With that log dropped, no error is raised and bear 1 is paid to A.

**Result:** PASS.

### Fix validation

Not done.

---

## Informational Findings

## [I-01] `WhitelistClaim` and `WhitelistImport` are unused, and the live whitelist has no root check

### Summary

Neither whitelist contract is deployed, because MINT keeps the whitelist off-chain. Both are still in `src/` and wired into the scripts, and `compare` can only check Studio's root against them, not against the CSV actually used.

### Description

On 28 September MINT moved the whitelist to its backend. The registries remain in the repository as an undocumented fallback. No tool performs the check WL-4 requires (Studio's root equals MINT's final CSV), because `compare`'s CSV mode is not built.

### Relevant code

**Decision: no whitelist contract is deployed - [`openspec/decisions.md:787`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/openspec/decisions.md#L787)**

```markdown
- **Resolution:** option **(B)** — an off-chain register in MINT's backend. No whitelist contract is deployed; the final CSV is loaded into Studio and Calea checks Studio's root against it.
```

**`compare` reads only a registry - [`docs/RUNBOOK.md:66-71`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/docs/RUNBOOK.md#L66-L71)**

```markdown
**4. Check the root against the CSV.** Calea runs `script/WhitelistExport.s.sol`'s `compare` over
the CSV file and the stage's parameters. It fails unless the root on SeaDrop is the root of the
CSV's rows, and names the difference; it also fails when the CSV totals more than 4,222. The CSV
mode is `tasks.md` 2.6 and is not built yet; until then, `compare` reads only a deployed
registry. If the check fails, fix the CSV or the Studio
upload and run it again, before the stage opens.
```

### Root cause

The design changed after the registries and their tooling were built.

### Exploitation path

None.

### Impact

Dead code to maintain, and no automated check of the live allowlist root.

### Preconditions / assumptions

None.

### Recommendation

1. Build `compare`'s CSV mode before the whitelist stage (29 October).
2. Confirm with MINT whether on-chain whitelisting can come back. If not, remove both registries and the code that depends on them. If so, mark them as an undeployed fallback.

### PoC / Validation evidence

Structural (quoted above).

### Fix validation

Not done.

## [I-02] `IBurnableMNTD` is declared inside `Activation.sol`

### Summary

`IBurnableMNTD` matches the reference $MNTD, but it is declared in `Activation.sol` instead of `src/interfaces/`, where `IMintABear` already is.

### Description

The interface declares the only two functions `Activation` calls on $MNTD. Both match the verified reference token on Base Sepolia ([`0xa21273093af1b3b880b73afd54514bb3d6269968`](https://sepolia.basescan.org/address/0xa21273093af1b3b880b73afd54514bb3d6269968#code), OpenZeppelin `ERC20` + `ERC20Burnable` + `ERC20Permit`). `decimals()` returns `uint8` and `burnFrom(address,uint256)` returns nothing, so nothing is missing.

### Relevant code

**The interface - [`src/Activation.sol:9-14`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/Activation.sol#L9-L14)**

```solidity
/// @dev The two functions of $MNTD `Activation` calls: `decimals` once, in the constructor, and
///      OpenZeppelin `ERC20Burnable.burnFrom` in `burn`.
interface IBurnableMNTD {
    function decimals() external view returns (uint8);
    function burnFrom(address account, uint256 amount) external;
}
```

**The reference token's ABI for those two functions (verified source)**

```json
{"name": "burnFrom", "inputs": [{"type": "address"}, {"type": "uint256"}], "outputs": [], "stateMutability": "nonpayable"}
{"name": "decimals", "inputs": [], "outputs": [{"type": "uint8"}], "stateMutability": "view"}
```

### Root cause

Code organisation.

### Exploitation path

None.

### Impact

None.

### Preconditions / assumptions

The $MNTD deployed on Robinhood Chain is the same contract as the reference.

### Recommendation

Move `IBurnableMNTD` to `src/interfaces/IBurnableMNTD.sol` and import it from `Activation.sol`.

### PoC / Validation evidence

The selectors `decimals()` (`0x313ce567`) and `burnFrom(address,uint256)` (`0x79cc6790`) are both in the reference token's deployed bytecode.

### Fix validation

Not done.

## [I-03] Source comments mix process notes, project references and narrative into the NatSpec

### Summary

The contracts' comments go well beyond describing behaviour. They quote tool output ("Slither reports `locked-ether`"), refer to specification IDs, people, products and off-chain services, describe a removed feature, and justify design choices at length. In `MintABear.sol`, 83 of 138 lines are comments.

### Description

NatSpec is published with the verified source and read as the contract's specification. It should state what each element does, neutrally and briefly. Here it also carries tool output (the same Slither paragraph in three contracts), project references (`WL-7`, "MINT's admin", "the portal", "OpenSea Studio", "getminted.io", "Status links") and long design narrative ("per OpenSea's integration guidance", "a guarantee rather than a configuration choice").

### Relevant code

**Tool output, repeated in three contracts - [`src/Activation.sol:38-41`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/Activation.sol#L38-L41)** (also [`src/WhitelistClaim.sol:32-35`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/WhitelistClaim.sol#L32-L35), [`src/WhitelistImport.sol:22-25`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/WhitelistImport.sol#L22-L25))

```solidity
 *         Slither reports `locked-ether` because Solady's ownership functions are `payable`
 *         (a gas saving). Anyone can call `requestOwnershipHandover` and
 *         `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value to
 *         them; nothing here withdraws it, and nothing else accepts ETH.
```

**Off-chain consumer in a function comment - [`src/Activation.sol:244-248`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/Activation.sol#L244-L248)**

```solidity
    /**
     * @notice How much more $MNTD a bear needs to reach a level.
     * @dev    The portal sizes each burn with this, and `burn` refuses any amount above
     *         `costToReach(tokenId, 5)`.
     * @return The remaining base units, or zero if the level is already reached.
```

**A removed feature still described - [`src/interfaces/IMintABear.sol:18-23`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/interfaces/IMintABear.sol#L18-L23)**

```solidity
    /**
     * @notice Counts how many times a bear has changed hands.
     * @dev    Incremented on every transfer and never on mint. State keyed to a stale value
     *         of this counter is void, which is how activation and Status links reset.
     */
    function transferNonce(uint256 tokenId) external view returns (uint64);
```

**Specification IDs and deployment intentions - [`src/WhitelistImport.sol:8-12`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/WhitelistImport.sol#L8-L12)**

```solidity
 * @notice The owner-imported register of MintABear's whitelist: up to 1,000 allocations that MINT's
 *         admin writes from a CSV, frozen for good once `closeAt` has passed. It is the variant of
 *         `WhitelistClaim` for a whitelist MINT decides alone (WL-7); MINT deploys one of the two.
 *         The whitelist stage's allowlist in OpenSea Studio is exported from `claimants`, exactly
 *         as from `WhitelistClaim`, so anyone can recompute it from the chain and check it.
```

**Design narrative on a constant - [`src/MintABear.sol:45-50`](https://github.com/Calea-Digital/robinhood_nfts/blob/audit/security-review/src/MintABear.sol#L45-L50)**

```solidity
    /// @notice The collection's permanent supply ceiling.
    /// @dev    `maxSupply` on the SeaDrop base is an owner setting: it starts at zero, and the
    ///         owner (or OpenSea Studio, through `multiConfigure`) can raise it at any time.
    ///         This cannot be changed by anyone, so the stated 4,444 is a property of the
    ///         code rather than of how the contract happens to be configured.
    uint256 public constant MAX_BEARS = 4444;
```

### Root cause

The NatSpec doubles as design notes and project log.

### Exploitation path

None.

### Impact

Verbose, non-neutral and partly outdated public documentation.

### Preconditions / assumptions

None.

### Recommendation

Keep NatSpec to what each element does, its parameters and its errors. Remove tool output, specification IDs, names of people, products and services, and design history (move what is useful to `docs/`). For example:

```solidity
    /// @notice Maximum number of bears that can ever be minted. Checked on every mint,
    ///         independently of `maxSupply`.
    uint256 public constant MAX_BEARS = 4444;
```

### PoC / Validation evidence

Structural (quoted above).

### Fix validation

Not done.
