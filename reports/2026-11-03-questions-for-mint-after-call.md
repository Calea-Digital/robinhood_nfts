# Questions for MINT after the call of 3 November 2026

The call settled the worker key (a fresh hot wallet, one key for both roles, address sent encrypted)
and set the launch tentatively for 10 November (MINT decides by about 5 November whether to move it
to 12, 13 or 15 November). These were left open. Item 12 is a board item phrased for MINT; drop the
id before sending.

1. **Launch date:** does 10 November mean the whitelist stage on OpenSea, or the public stage? At
   what hour (UTC)? And what is the public stage's date?
2. **Whitelist close:** does the campaign still close on 7 November at 12:00 UTC, with the CSV to
   Iñigo and Calea by 14:00?
3. **Ownership:** has MINT's admin called `acceptOwnership()` on the MintABear contract? Iñigo can't
   configure Studio (metadata, royalties, stages) until it has.
4. **Old key:** is `0x18D2…1Eff` the key that was in Railway, and is it stored anywhere else?
5. **Railway:** have all secrets been rotated, is 2FA on for every member, and has the audit log for
   the incident window been checked?
6. **New key backup:** who keeps the backup of the new hot wallet's key, and where?
7. **Mainnet deploy:** which contract PR is meant by "the latest contract PR" for mainnet, and who
   deploys it, Calea or Lorenzo? Mainnet BearDrop is planned for 13–14 November.
8. **First mystery-box cycle:** what start date and length? It can only open after holders have
   bears, so after the mint.
9. **Activation:** when does the switch-on happen (unpausing burns), and does the first royalty split
   stay on 5 November?
10. **BearDrop round 1:** will MINT confirm the list (4,444 bears × 500 $MNTD = 2,222,000) once Calea
    sends its checksum? Is MINT's admin a plain key wallet or a Safe for that round?
11. **PR #43** (BearDrop and two webapp fixes) is waiting to merge into `release/1.1`. Who merges it,
    and when?
12. **Smart-wallet winners (MNT-187):** a winner's claim ticket names the address that opened the
    box on Robinhood Chain. If that address is a smart wallet, the winner may not control the same
    address on Ethereum or ApeChain, and couldn't claim there. Should such winners be paid on
    Robinhood Chain only, should the page warn them, or does MINT accept the risk? Needed before the
    first cycle opens.
