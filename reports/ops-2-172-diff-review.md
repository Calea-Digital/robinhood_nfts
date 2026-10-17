# Differential review: OPS-2, Defect MNT-172 (`runPrizeVault`)

**Branch:** `mnt/OPS-2-172` in `~/trees/NFT-OPS-2-172`, against `feat/contracts` `c5f053b`.
**Scope:** `script/Deploy.s.sol` (`runPrizeVault`, `deployPrizeVault`, `loadVaultConfig`,
`_requirePrizeChain`), `script/config/{vault,vault-testnet,example-vault}.json`, the RUNBOOK's
"Prize vault" section, README, DESIGN, `test/Deploy.t.sol` and `test/Deploy.tree.md`. 9 files,
+491 / −9. No contract under `src/` changed, so the deployed bytecode is unchanged.

**Risk: medium.** The script sets the vault's owner and signer for good, and the vault holds every
prize.

## What the change guarantees

- **Creation.** `PrizeVault(owner, signer)` is created by the CREATE2 deployer `0x4e59…956C`.
  Under a broadcast, forge redirects `new{salt}` there, after checking that the deployer's
  bytecode is canonical. A test found that a stand-in at that address is refused by forge with
  "invalid CREATE2 deployer bytecode".
- **Address.** The address depends only on the salt, the initcode and `(owner, signer)`.
- **No address set after construction.** It is one transaction to the deployer, which makes the
  creation. The OPS-2 Scenario test asserts this from the state diff.
- **Refused before any transaction:**
  - a zero owner or signer;
  - a chain the config does not list;
  - a chain with no deployer;
  - a moved address once `expectedVault` is written.
- **Re-run.** Code at the predicted address can only come from this exact initcode and salt, so a
  re-run creates nothing and only reads the vault back. A third party who deploys the same initcode
  first creates exactly MINT's vault, so front-running gives an attacker nothing.
- **Read-back:**
  - the address equals the prediction (this guards forge's routing; without a broadcast the
    creation would come from the script);
  - `owner`, `signer`, not paused;
  - the EIP-712 domain: name, version, `block.chainid`, the vault's own address. The worker's
    tickets are signed in this domain.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | Medium (operational) | The address commits to the first `(owner, signer)`. A vault added on a later chain (Base) after `setSigner` or an ownership move (MNT-146's multisig) must be built with the retired key and the old owner. Until it is brought level, that old signer can sign valid tickets on it | **Fixed:** RUNBOOK rule (`setSigner` and the handover before any cycle is registered there; until then nothing is reserved, so no ticket can claim) and `vault.json`'s comment. Fully closing it would need a constructor that does not commit to the signer, which is a contract change outside this Defect |
| F2 | Info | Nothing refuses `signer == owner`. The RUNBOOK says the signer is never the admin, and `vault-testnet.json` deliberately sets both to the rehearsal wallet | Accepted. A guard would break the rehearsal config. The mainnet signer is entered by hand when the worker key exists, so review that value at the time |
| F3 | Info | `expectedVault` protects only once someone writes it after the first chain | It is a RUNBOOK step. The forge and solc pins keep the initcode stable meanwhile |
| F4 | Info | A re-run refuses `ReadBack("signer")`, `"owner"` or `"paused"` on a vault whose state legitimately changed since | Intended: it tells the operator the config no longer describes the chain. The test pins the rotated-signer case |
| F5 | Info | `verify.sh` does not yet know `PrizeVault`. A broadcast containing the vault exits 2 | 5.5 (OPS-3). The broadcast records `CREATE2` with `contractName: PrizeVault`, so `verify.sh` can read it |

## Evidence

- **Tests:** 7 new or extended in `DeployTest`, 313 in the suite. `Deploy.s.sol` coverage
  157/157 lines and 19/19 branches.
- **Planted breakages:** 15, of which 14 were caught:
  - the chain, deployer, expected-address and signer checks;
  - the salt dropped, the arguments swapped;
  - each read-back field;
  - always create, no broadcast.

  The `address` read-back alone survives under a working redirect, as described above.
- **Simulation on the real chains** (nothing broadcast): `vault-testnet.json` gives
  `0xAE51fA4E8f5089fE0D3017589fDa851475bF383d` on 46630, Sepolia, Curtis and Base Sepolia. On
  4663, `vault.json` is refused with `MissingAddress("signer")` and `vault-testnet.json` with
  `NotAPrizeChain(4663)`.
- **Not done:** the 46630 hand check (deploy, register, claim, release, withdraw). The person
  deferred it to review.
