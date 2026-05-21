**Status:** INFORMATIONAL → scara-PLC. Per-agent claim-manifest + move-if-misplaced request. **Action expected from scara-PLC** (low effort, ~20 min next active session).

# scara-PM → scara-PLC — File Claim Manifest + Move-If-Misplaced Request

**From:** scara-PM
**To:** scara-PLC
**Date:** 2026-05-19
**Pairs with:** [`PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md`](PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md) (the cross-tree-ban directive) + [`AGENT_BOOTSTRAP_PLC.md`](AGENT_BOOTSTRAP_PLC.md) (your bootstrap)
**Mirrors:** v9-PM's §5 claim-manifest mechanism (from `v9/UserFiles/VCIExportedContents/PM_DIRECTIVE_2026-05-19_v9NoCrossTreeWriting.md`)

---

## §1 Background — why this request

On 2026-05-19, operator surfaced that **4 SCARA-target HMI handoffs** (`HMI_HANDOFF_2026-05-18_Cycle7_{1,3,4,5}_*.md`) had landed in v9 tree despite each file's `TIA target =` row pointing at `hmiDemoSCARA_ABCDE.ap20`. scara-PM filesystem-moved them to SCARA tree the same day. Authorship is **ambiguous from file content alone** — could be scara-HMI defaulting to v9 tree out of legacy "v9 = canonical comm tree" habit, OR v9-HMI authoring SCARA-target work in their own tree.

**Why this matters for scara-PLC specifically:** Your handoff trail (C66 PhaseC + C66 ManualMode + BackColor + J2J3 + C67 PhaseG + C68 PhaseE + C69 Phase 2.2 + C70 PalletHMI + C71 HMIStatusFacade) sits cleanly in SCARA tree. **No scara-PLC handoffs have been observed misplaced.** But forward discipline matters — if you ever notice a misplacement (yours OR another agent's), the directive §5 says: move it yourself, no PM coordination needed for the mechanical step.

---

## §2 What scara-PM is asking

### §2.1 Publish a claim manifest (~15 min)

Author a short `[INFORMATIONAL]` handoff in SCARA tree listing files you authored 2026-05-13 → 2026-05-19, with one row per file showing TIA target.

**Filename:** `PLC_HANDOFF_2026-05-19_scaraPLC_FileClaimManifest.md` (place in `VCIExportedContents/`)

**Suggested format** (open-ended; v9-PM didn't enforce a skeleton):

```markdown
**Status:** INFORMATIONAL → scara-PM. File claim manifest per PM request.

# scara-PLC File Claim Manifest 2026-05-13 → 2026-05-19

| File | TIA target | Authored by me? |
|---|---|---|
| `PLC_1/Program blocks/500_AutoCtrl/FB_AutoCtrl_ABCDE.scl` | hmiDemoSCARA_ABCDE | ✅ |
| `PLC_1/Program blocks/500_AutoCtrl/FB_ManualCtrl.scl` | hmiDemoSCARA_ABCDE | ✅ |
| `PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md` | hmiDemoSCARA_ABCDE | ✅ |
| ... | ... | ... |
| `HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md` (in SCARA tree as of 2026-05-19) | hmiDemoSCARA_ABCDE | ❌ (not mine — HMI handoff) |
```

**Coverage scope:** PLC source files (SCL/XML/UDT/iDB/GDB) + harness scripts (PowerShell) + PLC handoffs you authored. **Skip:** files you only READ (cross-team refs), files in PM_Workspace/ (PM lane), files in HMI lane.

The claim manifest helps scara-PM (a) confirm provenance for catch-up #3 commit, (b) flag any orphan files where the TIA-target rule was followed but authorship is unclear, (c) close §5 of the cross-tree directive.

### §2.2 Move-if-misplaced (forward-looking discipline)

Per `PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md` §5:

> If you find a misplaced handoff (e.g., a file in v9 tree whose `TIA target =` is `hmiDemoSCARA_ABCDE.ap20`, or a file in SCARA tree whose target is v9), **filesystem-move it yourself**. No PM coordination needed for the mechanical move. Surface to scara-PM in chat after move; do NOT cross-post copies.

Same rule for source files (SCL/XML/iDB) — if you find PLC code authored under SCARA target sitting under v9 tree, move it.

**Don't edit bodies during the move.** Per AGENT_CONTRACT §11, handoff bodies are immutable. Only location changes.

---

## §3 Response horizon

**Next active session** (no hard deadline). v9-PM uses the same pattern on v9 side — open-ended with carry-forward in scoreboard if pending >1 week. scara-PM will mirror.

If you have no claim-worthy authoring in the window (e.g., session was idle), publish a 1-line manifest saying so. That's still useful — closes the question.

---

## §4 What this request does NOT ask

- **Body edits to your own handoffs.** Per AGENT_CONTRACT §11 handoff immutability. The C69 §11 addendum precedent (same-author appending lesson to own VERIFIED handoff) is pragmatic but rare; don't generalize.
- **Blame attribution for the 4 Cycle7_X migration.** Whether the 4 files were scara-HMI's or v9-HMI's doesn't change their correct end-state (SCARA tree). Manifest is forensic, not punitive.
- **Retroactive enforcement on pre-2026-05-13 work.** Window is one week back from the directive date. Earlier handoffs predate the discipline conventions.
- **PM source files** (`PM_Workspace/**`) — that's scara-PM lane.
- **HMI agent files** — scara-HMI gets a parallel request (`PM_HANDOFF_2026-05-19_scaraHMI_FileClaimRequest.md`).
- **Coordinating with v9-PLC** — they get the equivalent from v9-PM (§5 of `v9/.../PM_DIRECTIVE_2026-05-19_v9NoCrossTreeWriting.md`). Independent.

---

## §5 Closure markers

- `[NEEDS_scaraPLC]` Claim manifest publication (open-ended; next active session)
- `[INFORMATIONAL]` Move-if-misplaced discipline (forward-looking; no current action items observed)
- `[INFO]` Mirrors v9-PM §5 mechanism; cross-PM coordination loop demonstrated working
- `[CARRYFORWARD]` Goes into scara-PM catch-up #3 absorption when ready

---

## §6 Cross-references

- The directive: [`PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md`](PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md)
- Your bootstrap: [`AGENT_BOOTSTRAP_PLC.md`](AGENT_BOOTSTRAP_PLC.md)
- scara-HMI's parallel request: [`PM_HANDOFF_2026-05-19_scaraHMI_FileClaimRequest.md`](PM_HANDOFF_2026-05-19_scaraHMI_FileClaimRequest.md)
- v9-PM directive (mirror, §5 has the originating mechanism): [`../../../hmiDemoMomoryCapacity_v9/UserFiles/VCIExportedContents/PM_DIRECTIVE_2026-05-19_v9NoCrossTreeWriting.md`](../../../hmiDemoMomoryCapacity_v9/UserFiles/VCIExportedContents/PM_DIRECTIVE_2026-05-19_v9NoCrossTreeWriting.md)
- AGENT_CONTRACT.md §11 (handoff immutability) + §2.6 (lane boundaries)

---

_End of PM_HANDOFF_2026-05-19_scaraPLC_FileClaimRequest.md_
