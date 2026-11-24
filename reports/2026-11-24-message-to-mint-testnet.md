Hi all,

We checked the testnet set you sent against our code and on-chain.

**What is in order**
- Every contract built from our code matches it exactly: TestABear, Activation, MysteryBox and BearDrop on Robinhood testnet, the PrizeVault on Robinhood testnet, Sepolia and Curtis, and the PrizeDraw on Arbitrum Sepolia. Each is owned by your testnet admin `0x2689…F5e7`, so no ownership transfer is needed.
- The wiring is right. The vaults' signer and the draw's worker are both `0x35C1…DD05`. The VRF subscription holds 0.02 ETH with the draw as its consumer. Cycle 1 has the same 10 prizes and the same prize-list hash on the box and on the draw.
- The admin wallet has gas on all four chains.

**Five things before testing**
1. **Open a new cycle.** Cycle 1 ran from 20 November 18:18 to 22 November 18:18 UTC and nobody opened a box, so nothing can be opened today.
   - Cycle 1's prizes are still reserved in the vaults. Before cycle 2 can use the same prizes, someone has to send `release(1)` to the vault `0x5514c86E08Dd67a7d325E73986cb9f0AB6d1e155` on each of the three chains. Anyone can send it, now that the claim window has closed.
   - The admin page has no button for this yet. Send it from the explorer, or with `cast send 0x5514c86E08Dd67a7d325E73986cb9f0AB6d1e155 "release(uint64)" 1`.
   - Then schedule cycle 2 from `/nft/admin` on both chains and register it on the vaults.
   - Worth adding a "Release cycle" step to the admin page before mainnet: every cycle needs it before its unclaimed prizes carry over.
2. **Hand out test bears.** All 4,444 TestABear are minted, and they all sit in the admin wallet, so the "Mint 3 test bears" panel will fail. Send each tester a few bears from the admin wallet.
3. **Start the box worker.** The worker wallet `0x35C1…DD05` has never sent a transaction, so check that the box-worker service is running against this set. It holds 0.01 ETH on Arbitrum Sepolia: enough for several hundred relays, though your guide suggests 0.03.
4. **Point staging at this set.** On testnet the addresses in `deployments.ts` are only defaults, and they still name our old rehearsal contracts. Set every `BEARS_*` address and deploy block on staging to the new set, or update the testnet defaults in `deployments.ts`.
5. **Activation on this set does not behave like mainnet.** TestABear is our MintABear, which has the transfer counter; the mainnet collection `0x96ba…4dD1` does not. Activation tests on this set therefore follow the counter and will not carry over to mainnet. A new Activation for the mainnet collection is being prepared, and we will deploy it on testnet with a collection like the mainnet one once it is ready.

**Our old rehearsal contracts are retired:** `0x8108…0A05`, `0x3895…ef2f`, `0xA15a…55a7` and `0xae51…383d` on Robinhood testnet, and `0x8108…0A05` on Arbitrum Sepolia. Don't point anything at them; nothing needs transferring.
