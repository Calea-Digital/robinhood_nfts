# Next session: deploy MintABear and Activation to Robinhood Chain mainnet (4663)

Start in `~/trees/robinhood_nfts` with `~/trees/NFT` added (`/add-dir`). Read `docs/HANDOVER.md`
first, at "Mainnet deploy: MintABear and Activation (prepared 19 October)". Then `docs/RUNBOOK.md`
in NFT (`packages/contracts/docs/RUNBOOK.md`): "Ownership handover", "Transfer enforcement",
"Royalties" and "Activation".

**Start only when MINT has given the mainnet $MNTD address (CQ-2).** Without it, `Activation`
cannot be deployed: $MNTD is fixed in its constructor, and a wrong address means a new
`Activation`. `MintABear` alone can go first if the person says so. The order is the collection,
then Activation, then the box, but the box and the draw are not part of this job.

## Part 1: ETH on Robinhood Chain for the deployer

The deployer is `0x0e1533E96e1328bdB8C0fc03858a484e4DE26ff2`. On 19 October it held 0 ETH on 4663
(nonce 0), 0.2004 ETH on Ethereum (nonce 45) and dust on Arbitrum One. The person tried to bridge
0.15 ETH and saw nothing arrive.

1. **Find the bridge transaction.** Search the address on Etherscan and on Arbiscan and look for the
   attempt.
   - **If it went through Robinhood Chain's native bridge** (an Arbitrum Orbit deposit through the
     Inbox), the L2 credit lands about 10–15 minutes after the L1 transaction is final. A
     retryable ticket that failed to auto-redeem can be redeemed by hand on the bridge's page or
     with `cast send … redeem`.
   - **If no transaction exists**, it was never sent: the Ethereum balance is unchanged.
   - **If it went through a third-party bridge**, check that bridge's status page with the
     transaction hash.
2. **The amount needed is small.** At 0.02 gwei, `MintABear` (about 5M gas, plus `setMaxSupply`,
   `setTransferValidator` and `transferOwnership`) and `Activation` (about 3M gas) together cost
   well under 0.001 ETH. Bridge 0.005 ETH: it leaves room for verification retries and gas spikes.
3. **Routes, in order of preference:**
   1. Robinhood Chain's official bridge from Ethereum (the person has 0.2 ETH there).
   2. Relay (MINT's swap app uses it; check that it supports chain 4663), from Ethereum or Arbitrum.
   3. MINT's admin (`0x1530…6141`, 0.0018 ETH on 4663 on 19 October) sends 0.002 ETH to the
      deployer. This is MINT's call and needs their wallet.
4. Read it back: `cast balance 0x0e1533E96e1328bdB8C0fc03858a484e4DE26ff2 --rpc-url https://rpc.mainnet.chain.robinhood.com --ether`.

The deployer needs a Foundry keystore: `cast wallet import mainnet-deployer --interactive`, run
by the person, with its address checked against `0x0e15…6ff2`. Claude never handles the key.

## Part 2: the deploy (OPS-2, OPS-3)

1. **Config:** in `packages/contracts/script/config/4663.json`, set `mntd` to MINT's address. Read
   its `decimals` on 4663 (18 expected; `Activation` scales thresholds by it) and check that it is
   MINT's token (name, symbol, supply). Commit on a Task branch off `feat/contracts`; the config is
   OPS-2's.
2. **Dry run first, nothing broadcast:**
   ```
   forge script script/Deploy.s.sol --rpc-url https://rpc.mainnet.chain.robinhood.com --sig "runCollection(string)" script/config/4663.json --account mainnet-deployer
   ```
3. **Broadcast `runCollection`**, with `--broadcast --verify --verifier sourcify`. Read back:
   - `maxSupply` is 4444;
   - the transfer validator is V3 `0x721C…cd1B`;
   - `owner` is still the deployer, with the pending owner MINT's admin `0x1530…6141`.
4. **MINT's admin calls `acceptOwnership`** (their wallet), then resets the allowed SeaDrop list and
   reads SeaDrop's state (RUNBOOK, "Ownership handover").
5. **Broadcast `runActivation(4663.json, $BEARS)`.** Read back the printed `DECIMALS`,
   `thresholdFor(1..5)`, `weightFor(0..5)`, owner `0x1530…6141` and paused.
6. **Verify:** `script/verify.sh 4663 --check` shows both `exact_match`. Keep the broadcast files in
   NFT's `broadcast/` (untracked); the HANDOVER records the addresses.
7. **Studio:** Iñigo sets provenance, metadata and royalties (5% to the pot, COL-6). MNT-164 covers
   the mainnet checks before the drop page goes live: Studio's takeover, `compare` against Studio's
   root, and one team bear sold.

## Part 3: record

Record the addresses and deploy blocks in the HANDOVER's "Verified on-chain facts", and tell MINT
(the client's `getDeployment(4663)` needs them). Update `vault.json` and the worker's README only if
asked. The box, the draw, the vault and the worker are separate jobs.
