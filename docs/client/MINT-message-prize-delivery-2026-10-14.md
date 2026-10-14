Hi Iñigo,

Following Monday's call, one decision is still open on the mystery box: how a winner gets their prize. You said MINT prefers a claim, where the winner pulls the prize through a smart contract, over MINT sending it. Before we build anything, here is what each way involves, so you can confirm the one you want.

**How it works today.** Each opening is decided on Arbitrum by Chainlink's random number, and the win is recorded there publicly. The prizes sit in MINT's prize wallet 0xf6c0…83e3 on Robinhood Chain, Ethereum and ApeChain (and Base in later cycles). Every payout is recorded against the winning opening, so anyone can see a win that was never paid.

**A. MINT sends (no new contracts; ready).** The worker sees a win and alerts MINT's operator with the winner, the prize and the chain. The operator sends the prize from the prize wallet with a normal wallet app, and the worker records the payment. Winners do nothing and need no gas. The cost is one manual send per win.

**B. The winner claims from a contract (MINT's preference).** On each prize chain we deploy a prize vault, and MINT moves the cycle's prizes into it. Because the win is decided on Arbitrum, the vault learns about it from a signature: after Chainlink decides a win, the worker signs a claim ticket for that winner and prize. The winner opens the page, claims on the prize's chain (paying gas there) and receives the prize. Unclaimed prizes go back to MINT after the claim window. What this adds:
- a new contract, deployed and verified on Robinhood Chain, Ethereum and ApeChain (Base when a cycle first uses it), and added to the audit;
- about 3–4 days of building and testing, plus deployment and audit time, so the first cycle would start mid-November at the earliest;
- the worker holds a signing key that releases prizes, so that key must be protected like the prize wallet's;
- winners need gas on the prize's chain to claim;
- MINT funds each chain's vault before each cycle.

**C. The winner requests, MINT sends (no new contracts).** The page shows "Claim" on a win. The winner signs a free request within the claim window, and MINT sends the prize as in A. Winners click to claim, need no gas, and nothing new is deployed or audited.

**D. Automatic sending from a payout wallet (no new contracts).** Before each cycle, MINT moves that cycle's prizes from the main prize wallet into a separate payout wallet on each prize chain, with a little gas. The worker holds the payout wallet's key. As soon as Chainlink decides a win, the worker sends the prize and records the payment. Winners receive the prize seconds after they see the result, with nothing to click and no gas to pay. What this involves:
- the payout wallet's key lives on MINT's server, so the cycle's prizes in it are exposed if that server is compromised (the main prize wallet stays offline);
- the worker, not a contract, makes sure each win is paid exactly once, by checking the payment record before every send;
- MINT keeps a little gas in the payout wallet on each prize chain.

**In short.** With A and C, the winner sees the win at once but receives the prize only when MINT's operator acts. B and D both deliver within seconds.

| | Prize arrives | Winner pays gas | New contracts and audit |
|---|---|---|---|
| A. MINT sends | when MINT acts | no | no |
| B. Claim from a vault | on the winner's click | yes | yes, on 3 chains |
| C. Request, MINT sends | when MINT acts | no | no |
| D. Automatic payout wallet | seconds after the win | no | no |

**Our recommendation.** D if what matters is that the winner gets the prize straight away: it is the quickest to build and adds nothing to deploy or audit. B if MINT specifically wants winners to claim from a contract that holds the prizes and releases each one only once; we can build it, with the timing above.

**To decide this we need:**
1. A, B, C or D.
2. The claim window: until the end of the cycle, or a fixed time after the win (for example 30 days)?
3. What the prizes are: NFTs (ERC-721 or ERC-1155), tokens (ERC-20), or native ETH or APE?
4. Roughly how many prizes per cycle?
5. For D: who creates the payout wallet's key (we suggest Lorenzo, as for the worker's key)?

If you can confirm by Tuesday 21 October, option B can still be ready before a first cycle in mid-November.

Thanks,
Bojan
