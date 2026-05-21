**Status:** [NEEDS_HUMAN] — operator: point every other open session at this directive + confirm it has stopped running git, then authorize scara-PM's §4 reconciliation. Binds scara-PLC + scara-HMI + every session on `hmiDemoSCARA_ABCDE`. Effective immediately, 2026-05-21.

# PM Directive — Git Single-Owner Rule (hmiDemoSCARA_ABCDE)

**From:** scara-PM
**Date:** 2026-05-21
**Applies to:** every Claude session that touches `E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/` — scara-PLC, scara-HMI, scara-PM, and any future session.
**Pairs with:** `AGENT_CONTRACT.md` §4.3 (PM-as-sole-pusher) · [`PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md`](PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md)

---

## §1 Why this directive

`hmiDemoSCARA_ABCDE` is one git repo on a single branch (`main`). Two Claude sessions have been running `git` against it concurrently. This has already cost:

- **A clobbered staging area + split commit.** On 2026-05-21 two sessions ran `git add` / `git commit` for catch-up #4 in parallel. One session's staging was overwritten by the other's; the work split — the real 204-file changeset landed as `a36f789`, while a near-empty duplicate `6e9582d` was created and had to be undone (`git reset HEAD~1`).
- **Stale cross-session views.** The folder re-architecture (`8fdae36` + `2b88a7d`) was committed by the refactor session; scara-PM only discovered it via `git log`. Each session keeps acting on a snapshot the other has already moved past — and across the remaining R1–R6 refactor phases this will recur and compound.

`AGENT_CONTRACT.md` §4.3 already names scara-PM the **sole pusher** — but §4.3 was written for v9's **two-worktree / two-branch** topology (`plc/*` + `pm/*`), where lane-separate branches make concurrent *commits* safe. **SCARA has no worktree split — it is single-branch `main`.** On one branch, concurrent commits race the index the same way concurrent pushes race the remote. So for SCARA, §4.3 must extend from "sole pusher" to **sole git operator**.

## §2 The rule

**Exactly one session runs git on `hmiDemoSCARA_ABCDE`. That session is scara-PM.**

No other session — scara-PLC, scara-HMI, or any session — runs **any** git **write** command on this repo:
`git add` · `git commit` · `git push` · `git pull` · `git merge` · `git rebase` · `git reset` · `git revert` · `git stash` · `git checkout` / `git switch` (branch or file) · `git restore` · `git rm` · `git clean` · `git tag` · `git branch`.

**Read-only git is fine for anyone:** `git status`, `git log`, `git diff`, `git show`, `git fetch` (fetch updates only local remote-tracking refs — it touches no working tree or index). Anything that changes the index, working tree, or history is **forbidden** except for scara-PM.

## §3 What each session does instead

**scara-PLC (refactor session) — for R1–R6 and all future work:**
1. Edit SCL / XML / UDT files under `PLC_1/**` freely — that is your lane (`AGENT_CONTRACT.md` §2.1).
2. At each phase / cluster boundary: **stop touching files** and signal **"phase N ready"** to the operator (chat) and/or via an INFORMATIONAL companion handoff.
3. **Do not commit.** scara-PM stages + commits + pushes the cluster as one clean commit.
4. Never run a git write command — not even to "save a checkpoint." If you want a checkpoint, ask scara-PM.

**scara-PM (this session) — sole git operator:**
- Stages + commits + pushes every change on `main`.
- Commits each scara-PLC cluster as a discrete commit once scara-PLC signals "phase N ready."
- Commits its own docs (handoffs, scoreboard, ledger, directives) in the same or adjacent commits.
- Pushes only on **explicit per-push operator authorization** (`AGENT_CONTRACT.md` §4.3 unchanged).

**scara-HMI:** unchanged — HMI files reach the SCARA repo via scara-PM cherry-pick (`AGENT_CONTRACT.md` §2.2). scara-HMI does not run git on this repo.

## §4 Current state to reconcile

scara-PM executes this in one clean sweep — **only after** the operator confirms every other session has stopped running git (see §5):

| Item | State | scara-PM action |
|---|---|---|
| `8fdae36` + `2b88a7d` (folder re-architecture) | committed local-only; `main` `[ahead 2]` | push to `origin/main` |
| `PM_HANDOFF_2026-05-21_scaraPLC_CatchUp4_PreRefactorBaseline.md` | untracked | commit |
| `SCOREBOARD_PLC.md`, `PM_LEDGER.md` | modified | commit |
| this directive + `AGENT_BOOTSTRAP_PLC.md` edit | new / modified | commit |
| `hmiDemoSCARA_ABCDE.info` | tracked, but operator-local TIA metadata (in `.gitignore` by name) | `git rm --cached` — untrack so it stops being swept into commits |

## §5 Enforcement

- The operator points every other open session at this directive and confirms it has stopped running git.
- scara-PM does **not** begin the §4 reconciliation until that confirmation — otherwise scara-PM is just the next racing actor.
- This directive should be folded into the SCARA adaptation of `AGENT_CONTRACT.md` (scoreboard task B.8) and into `AGENT_BOOTSTRAP_HMI.md` at next opportunity. `AGENT_BOOTSTRAP_PLC.md` is reinforced now (2026-05-21) with a ⛔ git box.

## §6 Cross-references

- `AGENT_CONTRACT.md` §4.3 — PM-as-sole-pusher. This directive extends it to sole-*committer* for SCARA's single-branch topology.
- [`PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md`](PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md) — sibling directive (cross-tree write ban); same enforcement pattern (directive file + bootstrap reinforcement).
- [`AGENT_BOOTSTRAP_PLC.md`](AGENT_BOOTSTRAP_PLC.md) — reinforced with a ⛔ "DO NOT RUN GIT ON THIS REPO" box, 2026-05-21.
- [`PM_HANDOFF_2026-05-21_scaraPLC_CatchUp4_PreRefactorBaseline.md`](PM_HANDOFF_2026-05-21_scaraPLC_CatchUp4_PreRefactorBaseline.md) — the R1–R6 refactor brief this directive protects.

---

_End of PM_DIRECTIVE_2026-05-21_GitSingleOwner.md_
