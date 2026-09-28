"""Build docs/client/MintABear-Whitelist-Options.pages: the brief for MINT on the two whitelist options.

WL-3 (`WhitelistClaim`, holders claim with vouchers) and WL-7 (`WhitelistImport`, MINT's admin
imports a CSV). The text lives here; the layout reuses `build_client_doc.py`'s WordprocessingML
builder, and Pages saves the result as .pages via AppleScript, as for the specification.

    python3 docs/tools/build_whitelist_options.py
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "docs" / "tools"))
import build_client_doc as b  # noqa: E402

INTRO = """# MintABear — Whitelist: two options

Prepared by Calea for MINT · 28 September 2026

The whitelist has 1,000 spots. Each spot is the right to mint one bear in the whitelist stage,
and a wallet can hold at most two. Two versions of the whitelist contract are ready, and MINT
deploys one of them. Both end the same way: the final list is exported as a CSV, loaded into
OpenSea Studio's whitelist stage, and checked against the chain. Neither contract is upgradeable:
its rules are fixed at deployment, so choosing the other option later means deploying a new
contract.

## Option A — Holders claim their own spot (WhitelistClaim)

**How it works.**

1. A holder logs in on getminted.io and wagers.
2. When the holder reaches $50, and again at $100, MINT's backend checks the wager API and signs a
   short "voucher": a permission slip valid for a few minutes, for one wallet and one spot.
3. The holder's wallet sends the voucher to the contract and pays a small gas fee.
4. The contract checks the voucher and the limits, and records the spot. The counter "spots left —
   X / 1,000" updates at once.
5. When the campaign closes, the list is exported and loaded into Studio.

The contract enforces 1,000 spots in total, two per wallet and two per getminted.io account. It
also enforces the campaign dates and first come, first served. Once a spot is recorded, nobody can
remove it or give it to someone else, MINT included.
"""

EXAMPLE_A = """Alice wagers $60. The backend signs a voucher for her wallet A, spot 1. Alice clicks "Claim", her wallet pays the gas, and the counter goes from 1,000 to 999.

Later she reaches $100 and picks a second wallet, B. She gets a voucher for spot 2 and claims it. Her account now holds its two spots, so any further voucher for it is refused.

If she sends her first voucher again, even before it expires, it is refused: her account has already used spot 1.

At the close, the export contains two rows: wallet A with 1 and wallet B with 1."""

NEEDS_A = """**What MINT provides.**

- **A signing key on the backend** (the "eligibility signer"), and its address. The admin wallet can
  replace it at any time.
- **Voucher signing in the backend:** check the wager API, then sign. Calea supplies reference code
  for this, with its rules.
- **The account id to identify a holder**, for example the Privy user id, and a fixed secret key
  that hides it on-chain.
- **The campaign's open and close dates**, and the whitelist stage's start date, at least 48 hours
  after the close.
- **From holders:** a little ETH on Robinhood Chain for the claim, which they need for the mint
  anyway. Alternatively, MINT's backend could send the claims and pay the gas. That needs a small
  change to the contract, which is not built yet and would have to be decided before deployment.

## Option B — MINT imports the list (WhitelistImport)

**How it works.**

1. MINT decides off-chain who is eligible, by its own rules.
2. MINT prepares a CSV with one row per wallet, `wallet,allocations`: the address, and 1 or 2
   spots. A header row is optional, and a wallet may appear only once.
3. From the admin page, the admin wallet uploads the CSV to the contract in batches of about 200
   rows, so 1,000 rows take five transactions. A batch with a bad row is refused whole, so a
   failed upload leaves nothing half-written.
4. Until the close date, the admin can add or remove wallets, and move the close date earlier or
   later. Every change is visible on-chain.
5. After the close date the list is frozen for good. Nobody can change it any more, and anyone can
   check whether a wallet is eligible.
6. The list is exported and loaded into Studio, as in option A.

The contract enforces 1,000 spots in total and two per wallet, and freezes the list at the close.
Who is on the list is entirely MINT's decision.
"""

EXAMPLE_B = """MINT's CSV has three rows: wallet A with 2 spots, wallet B with 1, wallet C with 1. The admin uploads it, and the counter shows 996 spots left.

MINT notices that wallet C was a typo. The admin removes it, and the counter goes back to 997.

The close date passes. From then on the list reads A: 2, B: 1, and nothing can change it."""

NEEDS_B = """**What MINT provides.**

- **The CSV** of eligible wallets and their spots (1 or 2).
- **The admin wallet**, the contract's owner (MINT has named `0x1530…6141`), to sign the uploads
  and pay their gas.
- **The close date**, and the whitelist stage's start date, at least 48 hours after the close.
- **The eligibility rules themselves.** The wager thresholds and the limit of two per account are
  MINT's to apply before writing the CSV; the contract does not see accounts.
- **From holders:** nothing.

## Pros and cons

| | Option A — holders claim | Option B — MINT imports |
|---|---|---|
| Trust | Public and checkable: every spot was claimed by its own wallet, in order, with MINT's signature | The list is MINT's word; the chain shows what was written and when |
| First come, first served | The order of claims is recorded on-chain | Decided by MINT off-chain |
| Two per account | Enforced by the contract | MINT's to check before the upload |
| Changes after a spot is taken | None possible, by anyone | Possible until the close date, then frozen |
| Partners, corrections | A partner needs a voucher from MINT's signer; a spot claimed by mistake cannot be undone | Easy: add or remove before the close |
| Holder effort | One claim transaction and a little gas | None |
| MINT effort | A signing key and voucher signing in the backend | A CSV and a few admin transactions |
| Main risk | A leaked signing key, or an admin key that sets a new signer, could issue spots until the signer is replaced | A compromised admin key could rewrite the list, or keep it open, until the close |

**In common.** Neither contract is audited, at MINT's choice, so it can be delivered on
29 September. Both have Calea's unit tests at full coverage, and option A has also had Calea's
code review. The deploy script refuses a close date less than 48 hours before the whitelist
stage, so the export, the Studio upload and the checks have time; any later change of the date
has to keep that gap. Both use the same export and the same check against Studio.
"""


def main() -> int:
    body = (
        b.blocks_xml(b.parse_blocks(INTRO))
        + b.callout_xml("Example", b.parse_blocks(EXAMPLE_A), settled=True)
        + b.blocks_xml(b.parse_blocks(NEEDS_A))
        + b.callout_xml("Example", b.parse_blocks(EXAMPLE_B), settled=True)
        + b.blocks_xml(b.parse_blocks(NEEDS_B))
    )
    out = ROOT / "docs" / "client"
    docx = out / "MintABear-Whitelist-Options.docx"
    pages = out / "MintABear-Whitelist-Options.pages"
    b.write_docx(docx, body)
    if pages.exists():
        subprocess.run(["rm", "-rf", str(pages)], check=True)
    subprocess.run(["osascript", "-e", f'''
        tell application "Pages"
            set theDoc to open POSIX file "{docx}"
            save theDoc in POSIX file "{pages}"
            close theDoc saving no
        end tell'''], check=True)
    docx.unlink()
    print(f"wrote {pages}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
