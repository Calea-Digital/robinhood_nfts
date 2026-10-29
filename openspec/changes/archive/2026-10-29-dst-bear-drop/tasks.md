# Tasks

This change carries the spec work only. The implementation pick order is in
`openspec/changes/tranche-3/tasks.md`.

## 1. Spec

- [x] 1.1 Write the deltas:
  - `specs/distribution` (DST-1 to DST-6 added, a new family);
  - `specs/operations` (OPS-2);
  - `specs/deliverables` (DEL-6 modified, DEL-13 added);
  - `decisions.md` (CQ-25 to CQ-28 opened).

  Verify: every block has its Kind and one Scenario.
- [ ] 1.2 Register the family: add `DST → specs/distribution` to `openspec/config.yaml`'s prefix rule.
  Verify: `openspec validate dst-bear-drop --strict` and `docs/tools/board.sh --dry` exit clean.
- [ ] 1.3 On the person's word:
  - `/opsx:archive`;
  - fold CQ-25 to CQ-28 into `openspec/decisions.md`;
  - add the "Holders' $MNTD (DST)" section to `docs/SPECIFICATION.md`, with its family marker, and the
    four open items to §10;
  - render the prose and run `build_client_doc.py --check`;
  - commit named paths;
  - `/mnt:board`.

  Verify: the board's read-back passes.
