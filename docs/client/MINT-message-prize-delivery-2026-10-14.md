Hi Iñigo,

Following Monday's call, one decision is still open on the mystery box: how a winner gets their prize. You said MINT prefers a claim, where the winner pulls the prize through a smart contract, over MINT sending it. Before we build anything, here is what each way involves, so you can confirm the one you want.

**How it works today.** Each opening is decided on Arbitrum by Chainlink's random number, and the win is recorded there publicly. The prizes sit in MINT's prize wallet 0xf6c0…83e3 on Robinhood Chain, Ethereum and ApeChain (and Base in later cycles). Every payout is recorded against the winning opening, so anyone can see a win that was never paid.

**A. MINT sends (simplest; no new contracts).** The worker sees a win and alerts MINT's operator with the winner, the prize and the chain. The operator sends the prize from the prize wallet with a normal wallet app, and the worker records the payment. Winners do nothing and need no gas. The drawback: the winner sees the win at once but receives the prize only when MINT's operator acts.

**B. The winner claims from a contract (MINT's preference; the most work, the safest).** On each prize chain we deploy a prize vault, and MINT moves the cycle's prizes into it. Because the win is decided on Arbitrum, the vault learns about it from a signature: after Chainlink decides a win, the worker signs a claim ticket for that winner and prize. The winner claims on the prize's chain, paying gas there, until the end of the cycle; the contract releases each prize only once, and unclaimed prizes go back to MINT. What this adds:
- a new contract, deployed and verified on Robinhood Chain, Ethereum and ApeChain (Base when a cycle first uses it), and added to the audit;
- about 3–4 days of building and testing, plus deployment and audit time, all finished by 31 October for a first cycle on 4 November;
- the worker holds a signing key that releases prizes, so that key must be protected like the prize wallet's;
- winners need gas on the prize's chain to claim;
- MINT funds each chain's vault before each cycle.

**C. Automatic sending from a payout wallet (the middle ground; no new contracts).** Before each cycle, MINT moves that cycle's prizes from the main prize wallet into a separate payout wallet on each prize chain, with a little gas. The worker holds the payout wallet's key. As soon as Chainlink decides a win, the worker sends the prize and records the payment. Winners receive the prize seconds after they see the result, with nothing to click and no gas to pay. What this involves:
- the payout wallet's key lives on MINT's server, so the cycle's prizes in it are exposed if that server is compromised (the main prize wallet stays offline);
- the worker, not a contract, makes sure each win is paid exactly once;
- MINT keeps a little gas in the payout wallet on each prize chain.

| | Prize arrives | Winner pays gas | New contracts and audit | Key on a server |
|---|---|---|---|---|
| A. MINT sends | when MINT acts | no | no | no |
| B. Claim from a vault | on the winner's click | yes | yes, on 3 chains | a signing key that releases vault prizes |
| C. Automatic payout wallet | seconds after the win | no | no | the payout wallet's key, holding the cycle's prizes |

**Our recommendation.** C if what matters is that the winner gets the prize straight away: it adds nothing to deploy or audit. B if MINT specifically wants winners to claim from a contract that holds the prizes and releases each one only once; we can build it, with the timing above.

**What we already have from you:** a claim, if chosen, stays open until the end of the cycle; prizes can be NFTs (ERC-721, ERC-1155), tokens (ERC-20) or native ETH and APE; a cycle has about 5 prizes, at most 10. Every option handles all of these. With C, the worker checks before each cycle that every prize is in the payout wallet and can be sent, and it pays a winner whose wallet is a smart contract only after MINT checks it by hand, since that address may not work on the other chains.

**To decide this we need:**
1. A, B or C.
2. For C: who creates the payout wallet's key (we suggest Lorenzo, as for the worker's key)?

With the first cycle on 4 November, option B needs your answer by Friday 17 October. After that, the first cycle runs with A or C, and B can start from the second cycle.

One check on your note from the call: in our design each win is one prize on one chain, so a winner never has several chains to claim from. If you meant a single win to be a bundle of prizes on several chains, please tell us, as that changes the design.

Thanks,
Bojan
