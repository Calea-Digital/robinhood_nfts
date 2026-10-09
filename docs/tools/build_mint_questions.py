"""Build docs/client/MintABear-Questions-2026-10-12.pages: the questions MINT answers on 12 October.

Every decision still open with MINT (the register's open and follow-up CQ-n), the hand checks only
MINT's people can run, and the values the deployments need, grouped by what each answer unblocks
and soonest first. The text lives here; the layout reuses `build_client_doc.py`'s
WordprocessingML builder, and Pages saves the result as .pages via AppleScript, as for the
whitelist brief. No board ids: MINT's own tracker uses the same key.

    python3 docs/tools/build_mint_questions.py
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "docs" / "tools"))
import build_client_doc as b  # noqa: E402

NAME = "MintABear-Questions-2026-10-12"

INTRO = """# MintABear — Questions for MINT

Prepared by Calea for MINT · 9 October 2026 · for the meeting on Monday 12 October

The contracts for the collection, activation and the mystery box are built and tested, and the
mystery box is in review for staging (pull request #13 into `release/1.1`). What remains depends
on fifteen answers from MINT. They are grouped by what each one unblocks, soonest first.

Four dates are fixed: **TGE on 20 October**, **the whitelist frozen on 27 October at 12:00 UTC**,
and **the mint and the start of burns on 29 October**. The mystery box's first cycle follows the
mint, on a date MINT chooses.

Each question says why it blocks, the options, and what Calea recommends. **If there is no answer
by the end of Monday's meeting, we go ahead with the default in the yellow box**, so the work keeps
moving. A default can still be changed later, unless the question says otherwise. The ids in
brackets (CQ-n) are the decision register's in the specification.
"""

# Each question: (number, title, ref, why, options, recommendation, default)
GROUPS = [
    ("A. Now — for the testnet rehearsal and the mint on 29 October", [
        ("1", "The test $MNTD on Robinhood Chain's testnet", "CQ-2",
         "Burns open on 29 October, and the burn has to be rehearsed against $MNTD first. The "
         "rehearsal runs on the testnet (46630) with a copy of $MNTD, which MINT said it would deploy "
         "and announce. It is not there yet, so the rehearsal is waiting.",
         ["**MINT deploys the copy** and sends us its address.",
          "**Calea deploys the copy itself**, from the reference token MINT shared (Base Sepolia "
          "`0xa212…9968`), and gives MINT the address."],
         "Calea deploys it, so the rehearsal no longer waits on anyone. The mainnet token is "
         "checked against the same code at TGE (question 6).",
         "Calea deploys a copy of the reference token on the testnet on Tuesday 13 October and "
         "rehearses against it."),
        ("2", "The admin wallet: one wallet, or a multisig?", "CQ-12",
         "Every contract is owned by MINT's admin, and the owner is written into each contract when "
         "it is deployed. MINT named one wallet, `0x1530…6141`, for every contract on every chain. "
         "MINT's team has since opened a task to create a multisig, so we need to know which one "
         "owns the contracts. With one wallet, a single key controls the collection's "
         "configuration, the pauses and the mystery box's cycles.",
         ["**One wallet**, `0x1530…6141`, owns every contract on Robinhood Chain and Arbitrum One.",
          "**A multisig (Safe)** on Robinhood Chain and on Arbitrum One owns them. Safe's contracts "
          "are on Robinhood Chain; whether its web app supports the chain is to be checked."],
         "The multisig, if it exists on both chains by Friday 16 October. Otherwise start with the "
         "one wallet and hand every contract over to the multisig later: each contract supports a "
         "handover that the new owner must accept, so nothing is lost on the way.",
         "`0x1530…6141` owns every contract on every chain, and a later move to a multisig goes "
         "through each contract's two-step handover."),
        ("3", "The time the whitelist stage starts on 29 October", "CQ-1",
         "The whitelist campaign closes on 27 October at 12:00 UTC. The final list has to be frozen "
         "at least 48 hours before the whitelist stage opens, so there is time to load it into "
         "OpenSea Studio and for Calea to check Studio's list against MINT's file before anyone "
         "mints.",
         ["The stage opens at **12:00 UTC on 29 October**, exactly 48 hours after the close.",
          "The stage opens **later that day**, which leaves more time for the checks."],
         "12:00 UTC or later, with MINT's final CSV sent to Calea by 14:00 UTC on 27 October, so the "
         "check is done the day before the mint.",
         "The whitelist stage opens at 12:00 UTC on 29 October, and the final CSV reaches Calea by "
         "14:00 UTC on 27 October."),
        ("4", "Two checks only MINT can run, and when", None,
         "The collection enforces creator royalties, which is new for OpenSea on Robinhood Chain. "
         "Two things are proven by hand before the drop page is published, and both need Iñigo's "
         "OpenSea Studio account.",
         ["**On the testnet:** Studio takes over a collection Calea deployed, with royalty "
          "enforcement on, and a whitelist mint goes through.",
          "**On mainnet:** one team bear is listed and sold on OpenSea before the drop page goes "
          "live."],
         "Both in the week of 19 October: the testnet check as soon as the collection is deployed "
         "there, and the mainnet sale right after the mainnet deployment.",
         "Calea proposes the two dates on Monday, and the drop page waits for both checks to pass."),
        ("5", "The whitelist's go-ahead for production", None,
         "The whitelist site works on staging (`mintabear.mintstage.io`). MINT's team still has to run "
         "the staging claim test, and then MINT's CTO deploys production from Calea's instructions.",
         ["**MINT's team runs the test this week**, and production goes live after it.",
          "**MINT's team and Calea run it together** on a short call."],
         "Together, on a 30-minute call, so any problem is fixed on the spot.",
         "Calea sets up a 30-minute call for Tuesday 13 October to run the staging test with MINT's "
         "team."),
    ]),
    ("B. Before burns open — TGE on 20 October", [
        ("6", "The $MNTD address on mainnet", "CQ-2",
         "The activation contract is tied to one $MNTD address for life. A different address later "
         "means a new activation contract. It is deployed paused at TGE, and burns are rehearsed in "
         "short windows before they open to holders on 29 October.",
         ["MINT sends the address **when $MNTD is deployed**, before TGE.",
          "MINT sends it **on the day of TGE**."],
         "As soon as it is deployed. Calea checks that its code matches the reference token, then "
         "deploys the activation contract, paused, the same day.",
         "Calea deploys the activation contract on 20 October against the address MINT sends, once "
         "its code matches the reference token."),
    ]),
    ("C. Before the mystery box's first cycle", [
        ("7", "The 222 bears out of play", "CQ-20",
         "The team's 222 bears never play the mystery box. Their ids are recorded before the first "
         "cycle and then frozen for good, because changing them mid-game would change everyone's "
         "odds. The first cycle cannot be scheduled without them. This answer was due on "
         "5 October.",
         ["**The team's 222 are minted first**, before any other mint, so they are ids 1 to 222.",
          "**MINT sends the list of ids**, as ranges, if they are minted some other way."],
         "Mint the team's 222 first. The list is then one range, ids 1 to 222, and anyone can check "
         "it.",
         "The team's 222 bears are minted first, and ids 1 to 222 are the bears out of play. This "
         "one cannot be changed once the first cycle is scheduled."),
        ("8", "Is ApeChain a prize chain?", "CQ-20",
         "Prizes sit in MINT's prize wallet and are paid by ordinary transfer, so no contract goes on "
         "any prize chain. The play page still names the chains a prize can come from.",
         ["**Robinhood Chain and Ethereum** only.",
          "**Robinhood Chain, Ethereum and ApeChain.**"],
         "Whatever MINT's prize list needs. Adding a chain later is a change to the page, not to "
         "the contracts.",
         "Prizes are on Robinhood Chain and Ethereum only."),
        ("9", "Who holds the randomness subscription", "CQ-17",
         "Each box opening buys one random number from Chainlink on Arbitrum One, paid from a prepaid "
         "subscription. A cycle can use up to 4,222 numbers, one per playable bear. Someone owns the "
         "subscription, keeps it funded, and adds the draw contract as its user. Its number is "
         "written into the draw contract when it is deployed.",
         ["**MINT creates, funds and owns it**, from a wallet MINT controls. Calea adds the draw "
          "contract during deployment.",
          "**Calea holds and funds it** and invoices MINT. It is then a service Calea keeps after "
          "the handover."],
         "MINT holds it, since MINT owns every other role. Calea walks MINT through creating it.",
         "MINT creates and funds the subscription on Arbitrum One. Calea adds the draw contract as "
         "its user at deployment."),
        ("10", "Who runs the worker", "CQ-23",
         "The worker is a small service that carries each box opening from Robinhood Chain to the "
         "draw on Arbitrum One, in order, and records each prize paid. It cannot change an outcome "
         "or the order of openings, but it must keep running for as long as cycles run, past the "
         "19 November handover. It needs an address MINT's admin authorises, and some ETH on "
         "Arbitrum One for gas.",
         ["**Calea runs it** as a priced service.",
          "**MINT runs it** on its own infrastructure, from Calea's code and instructions."],
         "Calea runs it at first, and MINT's admin can replace it with one transaction at any time. "
         "We also need to know who tops up its gas on Arbitrum One.",
         "Calea runs the worker as a priced service, with MINT able to replace it at any time. MINT "
         "tops up its gas on Arbitrum One."),
        ("11", "How a prize reaches the winner", "CQ-22",
         "Prizes sit in MINT's prize wallet `0xf6c0…e3e3`, and each win is paid by an ordinary "
         "transfer. Whoever sends it, every payment is recorded against the winning opening, so "
         "anyone can see a win that was never paid. This decides the payout step and the play "
         "page's prize screen.",
         ["**MINT sends every win to the winner's address**, with no action from the winner.",
          "**The winner requests the prize** on the page within 30 days, or gives it up."],
         "Sending every win. The winner does nothing, there is no deadline to miss, and nothing "
         "depends on a holder acting in time. MINT sends from the prize wallet by hand, so its key "
         "never sits on a server.",
         "MINT sends each win from the prize wallet to the winner's address, and the worker records "
         "it."),
        ("12", "The first cycle: dates and prizes", "CQ-1",
         "MINT's admin schedules each cycle with its start, end, number of prizes and the prize list "
         "MINT publishes. The same terms go on both chains before the cycle starts, and once it "
         "starts they cannot change. A cycle lasts at most 90 days.",
         ["MINT sends the first cycle's terms **this month**, and Calea checks them with MINT's admin "
          "on the testnet first.",
          "MINT schedules the first cycle **itself**, from the admin page, when it is ready."],
         "The first cycle's terms at least three days before it starts, so both chains can be "
         "scheduled and read back. The first one goes on the testnet first.",
         "The first cycle is scheduled once MINT sends its terms, at least three days before its "
         "start."),
    ]),
    ("D. Later", [
        ("13", "The first royalty split and the handover", "CQ-1",
         "Both dates come from the statement of work and are still proposals. The split pays holders "
         "from the royalty pot, weighted by activation level. The handover ends Calea's technical "
         "support.",
         ["**Keep them:** the first royalty split on 5 November, the handover on 19 November.",
          "**Move them** to dates MINT gives."],
         "Keep both.",
         "The first royalty split on 5 November and the handover on 19 November."),
        ("14", "The contracts' client library joining MINT's workspace", None,
         "The TypeScript library MINT's apps use to call the contracts sits beside the apps, but "
         "outside the shared package workspace, so it does not touch the shared lockfile. Bringing "
         "it in changes four indirect dependency versions in the wallet stack. That is safe in our "
         "tests, but it is Lorenzo's call when it lands.",
         ["**Now**, before the mint.",
          "**After the mint**, from 30 October."],
         "After the mint, so nothing in the wallet stack moves during the drop.",
         "The library joins the workspace from 30 October, when Lorenzo agrees."),
        ("15", "Pull request #13 into staging", None,
         "Pull request #13 adds the mystery box, the draw and the client library's new calls to "
         "`release/1.1`. It touches nothing Railway deploys, so merging it does not redeploy staging. "
         "After the merge, two checks are run on the testnets: a real Chainlink answer after the "
         "worker relays an opening, and the admin page scheduling a cycle on both chains from one "
         "Privy wallet.",
         ["**MINT's developers review and merge it** this week.",
          "**Calea walks them through it** first."],
         "A 30-minute walkthrough, then MINT merges.",
         "Calea offers the walkthrough on Monday, and the pull request waits for MINT's merge."),
    ]),
]


def kept(xml: str) -> str:
    """Every paragraph kept with the next, so a question never splits across pages."""
    return xml.replace("<w:pPr>", "<w:pPr><w:keepNext/>").replace("<w:keepNext/><w:keepNext/>", "<w:keepNext/>")


def question_xml(n, title, ref, why, options, rec, default) -> str:
    head = f"### {n}. {title}" + (f" ({ref})" if ref else "")
    md = (head + "\n\n**Why it blocks.** " + why + "\n\n**Options.**\n\n"
          + "\n".join(f"- {o}" for o in options) + "\n\n**Calea recommends.** " + rec + "\n")
    callout = b.callout_xml("If there is no answer by Monday", b.parse_blocks(default))
    # The callout ends with an empty spacer paragraph: the last one, left free to break after.
    last = callout.rindex("<w:p>")
    return kept(b.blocks_xml(b.parse_blocks(md)) + callout[:last]) + callout[last:]


def checklist_md() -> str:
    rows = ["| ✓ | # | Question | Needed by | Ref |", "|---|---|---|---|---|"]
    by = {"1": "13 Oct", "2": "16 Oct", "3": "12 Oct", "4": "19 Oct", "5": "13 Oct", "6": "20 Oct",
          "7": "12 Oct", "8": "12 Oct", "9": "12 Oct", "10": "12 Oct", "11": "12 Oct",
          "12": "3 days before", "13": "29 Oct", "14": "29 Oct", "15": "16 Oct"}
    for _, qs in GROUPS:
        for n, title, ref, *_ in qs:
            rows.append(f"| ☐ | {n} | {title} | {by[n]} | {ref or '—'} |")
    return "## Checklist for the meeting\n\n" + "\n".join(rows) + "\n"


def body_xml() -> str:
    out = b.blocks_xml(b.parse_blocks(INTRO))
    for group, qs in GROUPS:
        out += b.blocks_xml(b.parse_blocks(f"## {group}"))
        for q in qs:
            out += question_xml(*q)
    checklist = b.blocks_xml(b.parse_blocks(checklist_md()))
    # The checklist opens its own page, so the table and the paragraph Word requires after it fit.
    return out + '<w:p><w:r><w:br w:type="page"/></w:r></w:p>' + checklist


def main() -> int:
    out = ROOT / "docs" / "client"
    docx = out / f"{NAME}.docx"
    pages = out / f"{NAME}.pages"
    b.write_docx(docx, body_xml())
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
