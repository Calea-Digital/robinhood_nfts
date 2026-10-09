# Decisions Delta

## Folded by hand into `openspec/decisions.md`

- **CQ-22.** `- **Blocks:** RAF-18`, which was RAF-33. How a prize is delivered gates the worker
  sequence, where step 6 pays each win, and not the payout record. The record is the same
  whether MINT pushes a win or the winner requests it.
- **CQ-22, "Recorded as".** Append: "The record is built ahead of the answer (change
  `raf-33-record-ungated`, 9 October). The answer shapes RAF-18's step 6 and the page's prize
  screen, not `PrizeDraw`."
- The State stays `open`, and Needed by stays 2026-10-12, because `PrizeDraw` is still not
  deployed without the answer.
