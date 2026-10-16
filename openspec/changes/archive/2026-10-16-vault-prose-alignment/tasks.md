# Tasks

## 1. Spec and register

- [x] 1.1 Lint the change (`lint_spec.py` over both delta files): every MODIFIED block carries its `**Kind:**` line and one Scenario. Verify: `openspec validate vault-prose-alignment` passes; `--strict` adds only the SHALL/MUST warnings the house prose style always draws.
- [x] 1.2 Archive (`/opsx:archive`). Verify: RAF-27, OPS-1, OPS-3, OPS-4 and OPS-5 in `openspec/specs/` read as the deltas, with Kind lines intact.
- [x] 1.3 Fold `decisions.md` into `openspec/decisions.md` by hand: the CQ-8, CQ-11 and CQ-20 fields and the three "Superseded (MINT, 15 October 2026, CQ-22)" paragraphs. Verify: `grep -c 'Superseded (MINT, 15 October 2026, CQ-22)' openspec/decisions.md` reads 3, and nothing else in the entries changed.
- [x] 1.4 Correct `openspec/config.yaml`'s `context`, which says the prizes are "paid from MINT's wallet on each prize chain" and names no `PrizeVault`. Verify: `openspec instructions proposal --json` shows the corrected text.
- [x] 1.5 Re-render the generated blocks (`render_calea_prose.py`) and run `build_client_doc.py --check`. Verify: the generated-prose check and the spec lint pass, as CI runs them.

## 2. Board

- [x] 2.1 Commit the named paths (spec, register, config, rendered docs, the archived change), then run `/mnt:board`. Verify: the preview refreshes RAF-27, OPS-1, OPS-3, OPS-4, OPS-5, CQ-8, CQ-11 and CQ-20 only, creates nothing, and the validator's read-back is OK.

## 3. Hand-offs

- [x] 3.1 In `openspec/changes/tranche-2/tasks.md`, add RAF-32 and RAF-33 to the "with it" lists of 5.1 to 5.3, and RAF-16's share to 5.2 and 5.3 (IC-8). Verify: every vault clause named in IC-8 sits on a 5.x line, and `check_scenario_quotes.py` still reads 41/0.
- [x] 3.2 Update the HANDOVER for #17 merged, PR #20 open with MNT-171, this change archived, IC-6 and IC-7 closed, and OPS-3 on Sourcify. Verify: its "Next" list starts from 5.1.
