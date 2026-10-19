# Tasks

## 1. Register

- [x] 1.1 Archive (`openspec archive cq-10-vault-resolution --skip-specs`). Verify: no spec file changes.
- [x] 1.2 Fold `decisions.md` into `openspec/decisions.md` by hand: CQ-10's Status note, Resolution and Blocks lines and the "Superseded (MINT, 15 October 2026, CQ-22)" paragraph. Verify: `grep -c 'Superseded (MINT, 15 October 2026, CQ-22)' openspec/decisions.md` reads 4.
- [x] 1.3 Re-render (`render_calea_prose.py`) and run `build_client_doc.py --check`. Verify: both pass.

## 2. Board

- [x] 2.1 Commit the named paths, then `/mnt:board`. Verify: the preview refreshes CQ-10 only and creates nothing.
