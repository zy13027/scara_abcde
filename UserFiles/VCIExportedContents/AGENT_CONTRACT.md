# Three-Agent Contract — v9/v10 TIA Portal V20 Project

> **Authoritative role definitions for the hmiDemoMomoryCapacity dual-PLC-codebase + HMI workflow.** Established 2026-05-07. Supersedes the prior implicit 2-agent (PLC + HMI) model. All three agents read this document at session start and respect lane boundaries.

---

## 1. Roles at a glance

| Agent | Primary lane | Worktree base | Branch base |
|---|---|---|---|
| **PLC code agent** | SCL / XML / UDT / library-snapshot authoring + code-level verification | `hmiDemoMomoryCapacity_v9/UserFiles/VCIExportedContents/` | `plc/*` |
| **PM agent** (project manager) | Cycle orchestration, cross-agent handoffs, scoreboard/ledger/PLC_TODO maintenance, commits, **pushes (sole pusher across all repos per §4.3)** | `hmiDemoMomoryCapacity_v9/UserFiles/PM_Workspace/` (PM artifacts) + read-only into v9 VCI tree | `pm/*` (own commits) + can commit to `plc/*` for code agent's workspace edits |
| **HMI agent** | C# Openness builders, v10 HMI authoring, denylist maintenance, HMI handoffs | `E:\VS_Code_Proj\TiaUnifiedAuto\` + `hmiDemoMomoryCapacity_v10\` | `claude/*` (HMI side) |
| **Operator (you)** | Direct authoring outside agent lanes; TIA UI work; pytest runs; per-push push authorization | any worktree | `user/*` (own commits per §2.6) |

Plus the existing **Test_LJDM agent** (sandbox at `Demo_LJDM_DataManager/`) — out-of-scope for this contract; uses its own conventions.

### 1.1 — Worktree topology rationale

PLC code agent and PM agent share a single local git repo (`VCIExportedContents/.git`) but operate via **2 separate worktrees on 2 separate branches**, with each branch **tracking a different remote repo** (split landed 2026-05-12 evening — see remote-split note below):

| Worktree | Branch | Owner | Remote (since 2026-05-12) |
|---|---|---|---|
| `VCIExportedContents/` | `plc/*` (+ `main`) | PLC code agent | `origin` → `github.com/zy13027/VCIExportedContents.git` |
| `PM_Workspace/` | `pm/*` | PM agent (mirrors `PLC_1/` + `Types/` per §4.4) | `pm_origin` → `github.com/zy13027/pm_workspace_v9.git` |

The 2-worktree design is intentional and serves three concrete benefits:

1. **Branch-lane audit / revert** — PLC code commits land on `plc/*`; PM tracker commits land on `pm/*`. `git revert` can roll back one lane without disturbing the other.
2. **Simultaneous read** — PM agent reads `PLC_1/` + `Types/` files via the mirror without needing to `git checkout` (which would lose pending work in either worktree).
3. **Conflict-free authoring** — both agents have their own pending-changes namespace; no cross-lane interference on uncommitted state.

Cost: ~6 MB disk for mirror + 1 sync command per cycle close (the §4.4 hard gate).

Single-worktree alternatives were considered and rejected (decision recorded 2026-05-08):
- Single-worktree alternating branches loses simultaneous read + creates checkout-blocking conflicts.
- Single-branch subdirectory ownership loses lane-grained audit/revert.

HMI agent uses the same pattern (`.claude/worktrees/<name>/` subworktrees + main `master` worktree) for the same reasons.

**Remote-split note (2026-05-12 evening).** Originally both `plc/*` and `pm/*` branches pushed to the same `origin` remote (`VCIExportedContents.git`). On 2026-05-12 evening the `pm/*` branch was migrated to its own remote repo `pm_workspace_v9.git` and the `pm/*` branch was deleted from `VCIExportedContents.git`. Motivation: (a) silence GitHub "Compare & pull request" banner that auto-fires on every push of any non-default branch in `VCIExportedContents.git`; (b) cleaner logical separation matching the `harness/` precedent (which already lives in its own `plcsim_harness_v9.git` remote). Local .git directory is still shared by both worktrees — only the remote URLs split. PM agent's `git push` from `PM_Workspace/` now defaults to `pm_origin` (set by `git push -u pm_origin pm/claude-code-2026-05-06` during the migration). PLC code agent's `git push` from `VCIExportedContents/` still defaults to `origin` as before. Cross-agent comm tree (`HMI_HANDOFF_*` / `PLC_HANDOFF_*` / `HMI_BINDING_MAP.md` / `AGENT_CONTRACT.md`) stays in `VCIExportedContents.git` since that's where HMI agent reads them — no HMI-side impact. PM-internal tracking artifacts (`SCOREBOARD_PLC.md`, `PM_LEDGER.md`, `PROJECT_STATUS.md`, `PM_HANDOFF_*`, `PM_STATUS.md`, `PM_READING_INDEX.md`, `PLC_TODO.md`, `NOTE_*.md`) now live exclusively in `pm_workspace_v9.git`.

---

## 2. Lane boundaries — who owns which file

### 2.1 — Files PLC code agent OWNS (writes)

- `VCIExportedContents/PLC_1/**` (all SCL, XML, GDB, UDT, iDB, OB)
- `VCIExportedContents/Types/**` (UDT XMLs + library meta `.libinfo` / `.libint` / `.liblink`)
- `harness/tests/**` (POC test authoring)
- `harness/tools/**` (verification scripts)

### 2.2 — Files PM agent OWNS (writes)

- `VCIExportedContents/PLC_HANDOFF_*.md` (cross-agent handoffs to HMI)
- `VCIExportedContents/HMI_BINDING_MAP.md` (PLC-side binding contract — single source of truth)
- `VCIExportedContents/UNSUPPORTED_PLC_DENYLIST.md` (mirror — actually regenerated by HMI; PM only ever pulls latest)
- `PM_Workspace/SCOREBOARD_PLC.md`
- `PM_Workspace/PM_LEDGER.md`
- `PM_Workspace/PLC_TODO.md`
- `PM_Workspace/PM_STATUS.md`
- `PM_Workspace/PM_HANDOFF_*.md` (PM-internal cycle handoffs)
- `PM_Workspace/NOTE_*.md` (architectural notes)
- `PM_Workspace/PM_READING_INDEX.md`
- `PM_Workspace/Types/**` and `PM_Workspace/PLC_1/**` (mirror of v9 VCI; sync after PLC code agent commits)
- `PM_Workspace/PROJECT_STATUS.md` (cross-agent dashboard — top-3-per-side index pointing at the two scoreboards)
- Cherry-picks HMI-owned `VCIExportedContents/HMI_HANDOFF_*.md` / `SCOREBOARD_HMI.md` / `HMI_LEDGER.md` files: PM **commits + pushes** these on HMI agent's behalf to `plc/*`. PM **never edits their content** (HMI agent authors; PM only stages + commits).

### 2.3 — Files HMI agent OWNS (writes)

- `E:\VS_Code_Proj\TiaUnifiedAuto\**` (C# builders, source code)
- `hmiDemoMomoryCapacity_v10/**` (deployed HMI .ap20 project)
- `VCIExportedContents/HMI_HANDOFF_*.md` (cross-agent replies to PLC)
- `VCIExportedContents/Builders/Maintenance/UnsupportedPlcDenylist.cs` (the C# source for the denylist)

### 2.4 — Files NO ONE writes directly (auto-generated / regenerated)

- `harness/hmi_export_v10/**` (HMI builder output snapshot; regenerated by HMI's `dotnet run`)
- `VCIExportedContents/Project Review/**` (TIA project-review snapshots; manual operator action)

### 2.5 — Cross-agent file with strict ownership rule

- `VCIExportedContents/HMI_BINDING_MAP.md` — **PLC-side only writable** (PM agent acting on PLC's behalf). HMI agent never edits this file directly. HMI agent proposes new rows via `HMI_HANDOFF_*.md` §6 and PM agent absorbs proposals into Section 1 of `HMI_BINDING_MAP.md` in the next PLC cycle.

### 2.6 — User authoring lane (operator)

When the operator (you) edits code directly in any repo, the convention is:

- **Branch on `user/<topic>-<date>`** — never on `master`, `plc/*`, `pm/*`, or HMI's `claude/*`.
- Agents **do not** touch `user/*` branches automatically.
- PM agent **surfaces** `user/*` branches in `PROJECT_STATUS.md` as "user lane state" so the cross-agent picture is complete.
- If user-authored work needs to land on a mainline branch, user opens a PR or merges manually.

**Precedent:** the `experiments/master-side-2026-05-08` branch (created 2026-05-08 to preserve operator's master-side experimental edits) is the founding example. Use the `user/` prefix going forward; `experiments/` was a one-off naming.

---

## 3. Sequencing — who acts first

```
Cycle entry: PM agent reads latest HMI handoff (or operator triggers a new cycle)
         ↓
   PM agent drafts plan + cycle handoff scaffold
         ↓
   PLC code agent authors workspace edits (SCL/XML/UDT) + verification grep
         ↓
   PM agent reviews, integrates findings into handoff, commits to plc/* worktree
         ↓
   Operator runs TIA Portal sync + compile + memory reset + download + pytest
         ↓
   PLC code agent verifies post-runbook (grep + bridge verifier + interpret pytest result)
         ↓
   PM agent writes VERIFIED follow-up handoff, refreshes scoreboard/ledger/PLC_TODO,
   commits both plc/* (handoff) and pm/* (artifacts), pushes both
         ↓
   HMI agent picks up next cycle via HMI_HANDOFF_*.md reply
```

### Required handshakes

| Step | Required signal |
|---|---|
| Plan finalized | PM commits plan amendment file or signals "plan ready" in chat |
| Workspace edits done | PLC code agent runs verification grep + reports "ready for sync" |
| Operator runbook complete | Operator pastes pytest result + bridge verifier output |
| Cycle close | PM agent's VERIFIED handoff committed and pushed to origin |

---

## 4. Conflict resolution

### 4.1 — File-edit collisions

- If two agents need to edit the same file: **PM agent wins** (since they hold the canonical scoreboard/ledger view). PLC code agent must defer.
- Exception: SCL/XML/UDT files in `VCIExportedContents/PLC_1/**` and `Types/**` — PLC code agent always wins. PM agent never edits these.
- Exception: `VCIExportedContents/PLC_HANDOFF_*.md` — PM agent always wins. PLC code agent can author INFORMATIONAL companion handoffs (different filename) but never edits PM's bundle handoff.
- Exception: `user/*` branches — no agent edits these. Operator-only.

### 4.2 — Plan-mode discipline

- Only PM agent drives plan creation and ExitPlanMode. PLC code agent operates without plan mode (gets lane scope from this contract + PM's per-cycle guidance).
- HMI agent operates without plan mode (gets scope from HMI handoffs).

### 4.3 — Push coordination (PM-as-sole-pusher)

**PM agent is the sole pusher across all repos.** Effective 2026-05-08; supersedes the prior "PLC code agent may push harness directly" carve-out.

| Repo | Branches | Pushed by | Authorization |
|---|---|---|---|
| `VCIExportedContents/` | `plc/*` + `pm/*` (cross-tree worktrees) | PM | per-push by user |
| `harness/` | `main` (separate origin `plcsim_harness_v9`) | PM | per-push by user |
| `TiaUnifiedAuto` (HMI) | `claude/*` + `master` + `experiments/*` | PM | per-push by user |
| `Demo_LJDM_DataManager/` | (its own conventions) | Test_LJDM agent | (out of scope of this contract) |

**Rules:**
- PLC code agent and HMI agent **never** push. They author + commit only on the PM-owned `plc/*` (PLC code agent commits to `plc/*` via PM's worktree) or on their own `claude/*` (HMI agent commits to `claude/*` via their own worktree).
- PM agent pushes only on **explicit per-push user authorization** (e.g. "push both branches", "push the HMI repo"). Standing pre-authorization for any branch is **forbidden**.
- Cross-lane pushes (PM pushing HMI's `claude/*` or harness's `main`) are logged as `git.push.cross-lane` rows in `PM_LEDGER.md`.
- Operator (you) may push any branch directly at any time — you have full git access. PM logs operator-side pushes as `git.push.user-direct` rows when surfaced.

**Why centralize:** the 2026-05-08 session demonstrated the value — PM has full cross-agent context (scoreboards, ledgers, what's verified) and is best positioned to know what's safe to push. Single authorization point reduces "who pushes what" cognitive load to one rule. Replaces the older "lane-owned push" model.

### 4.4 — Mirror sync (hard gate at PM cycle close)

- `PM_Workspace/PLC_1/**` and `PM_Workspace/Types/**` mirror the v9 VCI tree.
- **PM cycle close REQUIRES mirror sync.** After every PM tracker commit on `pm/*`, PM agent MUST re-sync the mirror via:
  ```bash
  git -C "PM_Workspace" checkout plc/<active-branch> -- PLC_1/ Types/
  ```
  and commit the result on `pm/*` as a separate `mirror.sync` commit. **PM cycle is not closed until both commits land.**
- **Acceptance criterion:** `diff -q PM_Workspace/PLC_1/Program\ blocks/100_OB/Axis_Call.xml VCIExportedContents/PLC_1/Program\ blocks/100_OB/Axis_Call.xml` returns empty (sentinel-file check). Verify before considering PM cycle complete.
- **Between-cycle divergence** (operator TIA work mid-cycle, PLC code agent commits without PM cycle close yet, etc.) is acceptable. **At-cycle-close divergence** is a `[GAP]` requiring the sync commit.
- Originated from 2026-05-08 streamlining: hard gate prevents the mirror from drifting silently across cycles (previous "low-priority" framing led to mirror staleness across multiple cycles in 2026-04 → 2026-05).

### 4.5 — Read discipline for cross-agent comm tree (token-efficiency)

Per 2026-05-14 token-efficiency analysis (see `PLC_HANDOFF_2026-05-14_TokenEfficiencyRefactorAndReadDiscipline.md`), unchecked file growth in the cross-agent comm tree + PM tracker caused 100K+ tokens of per-session bootstrap cost across dedicated agents. Mitigations:

**Read patterns (all agents):**

| File type | Recommended read pattern |
|---|---|
| `SCOREBOARD_PLC.md` / `SCOREBOARD_HMI.md` | `Read(offset=1, limit=20)` — header + Last action + Last 3 milestones. Read targeted sections by anchor when needed. Do NOT full-Read. |
| `PM_LEDGER.md` / `HMI_LEDGER.md` | `Read(offset=lastN, limit=50)` for recent session. Use `Grep` for targeted event lookups (e.g., "find when C38 was first authored"). Do NOT full-Read. Older sessions live in `*_LEDGER_ARCHIVE.md`. |
| `HMI_BINDING_MAP.md` | `Grep` for specific tag name; or `Read(offset, limit)` for specific Section. Do NOT full-Read (1000+ lines). |
| Recent `PLC_HANDOFF_*.md` / `HMI_HANDOFF_*.md` (current cycle) | Full-Read OK. |
| Older handoffs (>5 cycles back) | `Grep` for specific section; full-Read only if explicitly needed. |
| `AGENT_CONTRACT.md` | Full-Read at session start (canonical reference, capped at ~350 lines). |
| LJDM sandbox MD files + sibling TIA project Vci/SCL/XML content (4 sibling projects under `E:\TIA_Project_Directory_V20\`: `Demo_LJDM_DataManager` + `Demo_FlatUBP_DataManager` + `Demo_LeanLJDM_DataManager` + `LJDM_Pallet2000_Feasibility`) | **FORBIDDEN — DO NOT READ.** Verdict canonical in [`PLC_HANDOFF_2026-05-14_C47_LjdmSandboxAbsorbed.md`](PLC_HANDOFF_2026-05-14_C47_LjdmSandboxAbsorbed.md) §1 (4-branch verdict table). Binds all 3 agents (PLC + HMI + PM). See §4.5 LJDM-vs-PSC ban rationale below. |

**Size budgets (authors must observe):**

| Artifact | Soft cap | Hard cap (refactor required) |
|---|---|---|
| `SCOREBOARD_*` line 8 "Last action" sentence | 200 chars | 500 chars |
| `SCOREBOARD_*` "Last 3 milestones" entries | 300 chars/bullet × 3-5 bullets | 500 chars/bullet or >5 bullets |
| Per-cycle handoff (`PLC_HANDOFF_*` / `HMI_HANDOFF_*`) | 150 lines | 250 lines |
| Ledger event row | 200 chars | 400 chars |
| `HMI_BINDING_MAP.md` Section 3 row notes column | 200 chars (link to handoff for detail) | 500 chars |

**Periodic archive rotation (PM responsibility):**

- `SCOREBOARD_*` line 8 + Last-3-milestones: rotate oldest milestone to `SCOREBOARD_*_ARCHIVE.md` when adding new milestone (keep inline list capped at 3-5).
- `*_LEDGER.md`: archive session blocks older than ~7 most-recent sessions to `*_LEDGER_ARCHIVE.md` periodically (when ledger > 500 lines or > 150 KB).
- Archive files are NOT read at session bootstrap; only when explicitly investigating historical context.

Rationale: bootstrap reads compound per agent per session. Multiple dedicated agents × multiple sessions per day × bloated files = significant token cost. Discipline applies AFTER 2026-05-14; pre-existing handoffs/ledger blocks stay (audit-trail rule).

**§4.5 LJDM-vs-PSC ban (added 2026-05-14 by C49):** The LJDM sandbox at 4 sibling TIA projects produced a 7-file MD corpus (~1458 lines / ~103 KB) plus supporting Vci/SCL/XML content; total ≈ 75-100K tokens per agent session if re-read. The verdict is canonical in [`PLC_HANDOFF_2026-05-14_C47_LjdmSandboxAbsorbed.md`](PLC_HANDOFF_2026-05-14_C47_LjdmSandboxAbsorbed.md) §1 (4-branch table) + `PROJECT_STATUS.md` Cross-agent gates + `PLC_TODO.md` LJDM track section — together ~10K tokens. For LJDM-vs-PSC architectural questions, use those three summaries. The 4 sibling projects are **out-of-scope reference material** for v9 PM/PLC/HMI work and shall not be Read/Globbed/Grep'd during bootstrap or cycle authoring. **Exception:** copying a specific SCL/XML/JS pattern from the sandbox into v9 may require a targeted Grep + Read on a specific file — only with **explicit operator authorization**, named in a PM_LEDGER row that documents the rationale + the exact files touched.

---

## 5. Communication protocols

### 5.1 — Cross-agent (PLC↔HMI)

Existing file-mediated convention applies unchanged:
- `VCIExportedContents/PLC_HANDOFF_<YYYY-MM-DD>[_<topic>].md` — PM-authored on PLC's behalf
- `VCIExportedContents/HMI_HANDOFF_<YYYY-MM-DD>[_<topic>].md` — HMI-authored
- Status line on row 1: `**Status:** VERIFIED | PENDING | INFO` (handoff-level state per §11 schema; effective 2026-05-08)
- Inline closure markers in body content: `[NEEDS_HUMAN]`, `[SAFE_TO_AUTO]`, `[GAP]`, `[INFO]` (per-item state per §11 schema)
- Legacy markers in pre-2026-05-08 handoffs (`PENDING_VERIFICATION`, `ACKNOWLEDGED`, `CONTRACT-GAP`, etc.) stay readable; map via §11 migration table

### 5.2 — Intra-PLC-side (PM↔PLC code)

Lighter-weight; user typically relays in real time. Conventions:
- PLC code agent surfaces findings as bullet lists in chat → PM agent absorbs into handoff
- PM agent drafts handoff in workspace (uncommitted) → PLC code agent reviews + suggests amendments → PM agent commits
- PM agent maintains plan file (`~/.claude/plans/<plan>.md`) as living document; PLC code agent reads it but only edits with PM's awareness

### 5.3 — Intra-PLC-side (PM↔Test_LJDM)

LJDM agent uses its own handoff convention at `Demo_LJDM_DataManager/UserFiles/AGENT_HANDOFF_*.md`. PM agent reads these but does not author replies — Test_LJDM is self-contained.

### 5.4 — Count-evidence rule

Any agent claiming a quantitative state in handoffs / scoreboards / ledgers (e.g. "N commits ahead", "N files modified", "+X / -Y lines", "N tests passing") **must cite the git/test command + output**. Acceptable formats:

- `git rev-list --count <baseline>..<head>` → `N`
- `git diff --stat <ref>` → "N files / +X / -Y"
- `git status --short | wc -l` → `N`
- `pytest <args>` → `N passed, N failed, ...`

Claims without evidence are flagged `[GAP]` on review. Originated from 2026-05-08 incident: HMI scoreboard claimed "~30 commits ahead" while actual `git rev-list --count 7fbd734..claude/tender-lovelace-aa0c0c` returned `20` — phantom commit count surfaced and fixed via documentation.correction event in `HMI_LEDGER.md`.

---

## 6. Specialization expectations

### PLC code agent should know
- SCL syntax, S7-1500 idioms, Optimized Access semantics
- UDT shape rules (cascade dependencies via library-versioning)
- TIA library `.liblink` / `.libinfo` / `.libint` mechanics
- Denylist patterns (flat-array UDTs, TO axis refs)
- `feedback_pytest_run_protocol.md` (memory reset trigger)
- `feedback_scl_no_shortcircuit.md` (Area-length error trigger)
- `feedback_plcsim_real_vs_lreal.md` (read_real vs read_lreal)
- iDB shape change → memory reset rule
- Held-execute pattern for FB rising-edge contracts

### PM agent should know
- `plc-hmi-handoff-cycle` skill end-to-end
- All ledger / scoreboard / PLC_TODO conventions
- Cross-tree git topology (PM_Workspace ↔ v9 VCI ↔ harness ↔ HMI source)
- Auto-routine gating rules
- Cycle handoff template structure (8 sections per `PLC_HANDOFF_TEMPLATE.md`)
- Closure marker semantics
- Push cadence (only on explicit user auth)

### HMI agent should know
- C# Openness API + idioms
- WinCC Unified PSC binding constraints
- v10 builders + `--only=audit-tags` workflow
- `feedback_v20_reauthor_crash_pattern.md` (chunked re-author)
- HMI handoff template structure (also 8 sections per `HMI_HANDOFF_TEMPLATE.md`)

---

## 7. Failure modes and recovery

| Mode | Recovery |
|---|---|
| PM agent commits PLC code by mistake | PLC code agent reverts via `git revert <sha>`, surfaces in next chat turn |
| PLC code agent edits scoreboard by mistake | PM agent reverts; updates lane note in chat |
| Both agents edit same file in parallel | First commit wins; second rebases or reverts; surface as `[CONTRACT-COLLISION]` marker in next handoff |
| Mirror in PM_Workspace gets badly stale | PM agent does full re-sync from canonical: `git -C "PM_Workspace" checkout plc/<branch> -- PLC_1/ Types/` |
| PLC code agent finds out HMI side has a binding to something we're deleting | Stop the cycle, surface via `[CONTRACT-GAP]` in PM's bundle handoff §6, wait for HMI handoff reply before proceeding |
| TIA library re-promotion fails (libinfo hash mismatch) | PLC code agent diagnoses → operator does TIA UI library re-promotion or terminates link → re-export → continue |
| Stale Claude Code worktrees in `.claude/worktrees/<name>` | Periodic cleanup by user via PowerShell. Identify branches with no unique commits vs `master`: `git for-each-ref refs/heads/claude/*`; for each branch, if `git log master..<br> --oneline` is empty → STALE. Safe to `git branch -d <br>` + `Remove-Item -Recurse .claude/worktrees/<name>`. Do this when no editor / Claude Code holds files in the dir. Originated from 2026-05-08 cleanup of 6 stale `claude/*` branches in HMI repo. |

---

## 8. Auto-routine policy (3-agent variant)

Existing 2-agent rules apply with small modifications:
- Cap stays at **max 2 `[SAFE_TO_AUTO]` items per run**
- Gated on most recent **PM-written `PLC_HANDOFF_*.md`** reading `Status: VERIFIED` (not just any handoff)
- PLC code agent's INFORMATIONAL companion handoffs do NOT gate the auto-routine (status `INFORMATIONAL` is awareness-only)
- PM agent runs the auto-routine; PLC code agent does not initiate auto-routine work

---

## 9. Versioning of this contract

- This document is a project-level convention, committed to `plc/*` branch alongside other contract surfaces (`HMI_BINDING_MAP.md`, `UNSUPPORTED_PLC_DENYLIST.md`).
- Amendments require: PM agent drafts revision → PLC code agent reviews → HMI agent acks via next HMI handoff reply → land via PM commit on `plc/*`.
- Supersedes any prior implicit 2-agent role assumptions in `~/.claude/skills/plc-hmi-handoff-cycle/` skill text. Skill should be amended in a follow-up cycle to reference this document.

---

## 10. Bottom line

The 3-agent split is net advantageous because **role specialization improves catch rate, artifact quality, and code review depth** — at the cost of slightly higher coordination overhead which this contract eliminates by making lanes explicit.

PLC code agent: stays in the SCL/XML world.
PM agent: stays in the cycle-discipline / cross-agent world.
HMI agent: stays in the C# / Openness / v10 world.
Each agent is faster and more accurate within its lane than a single agent juggling all three concerns.

---

---

## 11. Closure marker vocabulary (6-marker schema)

All agents use these 6 markers in handoffs / scoreboards / ledgers / NOTE files. Effective 2026-05-08; legacy markers stay readable in historical rows.

| Marker | Meaning | Subsumes (legacy markers retired) |
|---|---|---|
| `[VERIFIED]` | Cycle landed end-to-end with verification artifact (pytest result, grep proof, etc.) | — |
| `[PENDING]` | Authored, awaiting verification or operator action | `[PENDING_VERIFICATION]`, `[NEEDS_INVESTIGATION]` |
| `[NEEDS_HUMAN]` | User must act (decision, TIA UI work, manual-wiring, clarification request, etc.) | `[NEEDS_AMEND]`, `[NEEDS_CLARIFICATION]`, `[BLOCKED-ON-USER]`, `[MANUAL-WIRING]` |
| `[SAFE_TO_AUTO]` | Auto-routine eligible (PM agent picks up next routine run, max 2/run) | — |
| `[GAP]` | Discrepancy / cleanup needed (contract gap, file collision, untracked stale state) | `[CONTRACT-GAP]`, `[CONTRACT-COLLISION]`, `[NEEDS_CLEANUP]` |
| `[INFO]` | Awareness only, no action requested | `[INFORMATIONAL]`, `[ACKNOWLEDGED]`, `[CORRECTION]`, `[CONJECTURED]`, `[DEFERRED]`, `[UNBLOCKED]`, `[CLOSED]` |

**Migration policy:** PM agent migrates PM-owned files (`SCOREBOARD_PLC.md`, `PLC_TODO.md`, `PROJECT_STATUS.md`, NOTE files) on contract-revision day. HMI agent migrates HMI-owned files (`SCOREBOARD_HMI.md`, `HMI_LEDGER.md`) on next HMI cycle. `PM_LEDGER.md` and `HMI_LEDGER.md` historical rows are append-only — legacy markers stay as written.

**Historical handoff files are immutable.** `PLC_HANDOFF_<date>*.md` and `HMI_HANDOFF_<date>*.md` files authored before 2026-05-08 are NOT migrated to the new marker vocabulary — they reflect the contract state at authoring time and serve as audit-trail artifacts. Readers of historical handoffs use the migration table above (§11) to map legacy markers to the current schema. New handoffs created on or after 2026-05-08 use the 6-marker schema directly. The `PLC_HANDOFF_TEMPLATE.md` (PM-owned) and `HMI_HANDOFF_TEMPLATE.md` (HMI-owned) carry an HTML reader's-guide comment pointing at this section so future authors and readers can resolve any marker confusion.

---

---

## 12. Plan-file rotation policy

PM agent's plan files at `~/.claude/plans/<plan-name>.md` are **reusable working artifacts**, not durable history.

- **Active plan:** PM agent overwrites the active plan file at each new cycle's Phase 4 (Plan mode "write final plan to plan file" step). One file, many lifetimes.
- **Past plans are NOT preserved by default.** The durable history lives in:
  - `PM_LEDGER.md` row pointing at the cycle's commit SHA
  - The cycle's verifying handoff in `VCIExportedContents/PLC_HANDOFF_*.md`
  - The git commit body itself (HEREDOC commit messages capture intent)
- **Archival on demand:** if a plan needs preservation (e.g. an unfinished multi-cycle roadmap, an abandoned design under consideration), PM agent copies it to `PM_Workspace/plans/archive/<YYYY-MM-DD>-<topic>.md` BEFORE the next cycle's Phase 4 overwrite. The archive path lives on `pm/*` branch and is committed as part of the next PM cycle.
- **Plan filename reuse:** Claude Code may reuse the same `<plan-name>.md` filename across many cycles (e.g. `cd-vciexportedcontents-git-worktree-gleaming-dahl.md` was reused 4+ times in the 2026-05-08 session). This is intentional — the filename is meaningless; the plan content is what matters per-turn.

Originated from 2026-05-08 streamlining: prevents `~/.claude/plans/` from accumulating dozens of stale plan artifacts that would need separate retention rules.

---

_Authored 2026-05-07. **Streamlined 2026-05-08 (this revision):** PM-as-sole-pusher policy (§4.3), count-evidence rule (§5.4), user-authoring lane (§2.6 + §1 lane row + §4.1 exception), worktree-hygiene rule (§7), 6-marker closure-marker schema (§11), mirror-sync hard gate (§4.4 rewrite), plan-file rotation policy (§12), historical handoff immutability + status-line vocab refresh (§5.1 + §11). Supersedes implicit 2-agent model. Effective immediately for cycle-2026-05-08+ forward._
