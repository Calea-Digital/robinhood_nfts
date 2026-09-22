# Decisions Delta

<!--
  One namespace, one ID (<PREFIX>-n; D on a new project, or the prefix the register already uses),
  lifecycle lives in State (open / follow-up / resolved / deferred). Check the persistent
  openspec/decisions.md register for the next free number — do not restart numbering per change.
  Fields are the bullets right under the heading; everything after the first blank line is the
  decision's own record, verbatim in the tracker and the client document.
-->

## ADDED Decisions

### D-<!-- n --><!-- optional: " — longer title" -->
- **Statement:** <!-- the question/decision text, short -->
- **State:** open
- **Section:** <!-- optional: spec section or family -->
- **Needed by:** <!-- optional; start with YYYY-MM-DD to project a Due Date -->
- **Resolution:** <!-- optional: the answer or the default, one line -->
- **Blocks:** <!-- requirement id(s) this gates, comma-separated, or omit -->
- **Default if deferred:** <!-- client-engagement only — what gets built if nobody decides. Omit on internal work. -->

<!-- the record: the question as put, options, the answer as given, what remains -->

## RESOLVED Decisions

### D-<!-- n -->
- **Statement:** <!-- unchanged from when it was open -->
- **State:** resolved
- **Status label:** <!-- optional, e.g. Closed -->
- **Status note:** <!-- optional provenance, e.g. call, 21 September 2026 -->
- **Rationale:** <!-- why this, not an alternative -->
- **Blocks:** <!-- requirement id(s) this settled -->

## DEFERRED Decisions

### D-<!-- n -->
- **Statement:** <!-- unchanged -->
- **State:** deferred
- **Rationale:** <!-- why deferring is safe right now -->
