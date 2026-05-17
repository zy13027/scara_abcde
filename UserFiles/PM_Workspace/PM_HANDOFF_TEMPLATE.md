# PM Handoff — _YYYY-MM-DD[_<topic>]_

> **Template.** Copy to `PM_HANDOFF_<date>[_<topic>].md` at session end.
> Lives in `PM_Workspace/` on `pm/*` branch — does NOT pollute the
> PLC↔HMI contract tree (`VCIExportedContents/`). PLC/HMI agents do not
> consume these; only future PM-agent invocations do.
>
> **First line MUST be `**Status:** <STATE>`** so resume can grep without
> opening the file. States:
> - `READY_FOR_NEXT_SESSION` — clean checkpoint, no decisions pending
> - `AWAITING_USER_DECISION` — listed decisions in §5 block progress
> - `PARKED` — work intentionally suspended, see §6 for unpark conditions

**Status:** _STATE_
**Session trigger:** _what made you (or the user) start this session_
**Predecessor:** _PM_HANDOFF_<prior-date>.md_ or `bootstrap`

---

## §1 — Cross-agent cycle state at session end

| Side | Latest handoff | Status line |
|---|---|---|
| PLC | `PLC_HANDOFF_<date>[_<topic>].md` | _verbatim status line_ |
| HMI | `HMI_HANDOFF_<date>[_<topic>].md` | _verbatim status line_ |

Auto-routine state today: _ran X items / NO-OP because Y_.
Pytest baseline: _36P/2S/2F or whatever current_.

---

## §2 — PM work done this session

Bullet list. What PM agent actually did. File reads count if they were
load-bearing for a decision; routine grep/skim does not.

- _e.g. Read full PLC_TODO.md, surfaced 3 dead links_
- _e.g. Created PM_Workspace worktree on `pm/claude-code-2026-04-30`_

---

## §3 — Workspace changes

Diff summary of `PM_Workspace/` files added/modified/deleted this session.
Use git status / git diff against the predecessor handoff's commit.

```
+ PM_HANDOFF_<date>.md     # this file
~ PM_STATUS.md             # refreshed cycle state
~ PM_LEDGER.md             # appended session entries
- (none deleted)
```

---

## §4 — Findings & hygiene flags

Things PM agent noticed that don't fit the cross-agent contract.
Contradictions between docs, dead links, zombie files, stale memory entries,
naming-convention drift.

For each: lead with the finding, then **Why it matters** + **Suggested
fix** + **Owner** (PM / PLC / HMI / user).

---

## §5 — Asks back to user

Decisions the user must make before PM agent can make further progress.
Each ask: lead with the question, then the options + PM-agent
recommendation + reasoning.

If no asks: write `_(none — autonomous progress unblocked)_`.

---

## §6 — Notes for next PM session

Free-form. What to read first, what to verify, what NOT to redo.
Keep tight — detail belongs in the linked file.

---

## §7 — Cross-agent observations (optional)

Items PM agent noticed that PLC or HMI agent should know. Almost always
empty — PM does not usually drive cross-agent work. If you write one,
also flag it on the user's desk in §5 because the other agent will not
see this file.

If empty: write `_(none)_`.

---

_End of PM_HANDOFF_<date>.md_
