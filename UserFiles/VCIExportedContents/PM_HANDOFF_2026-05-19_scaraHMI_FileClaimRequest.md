**Status:** INFORMATIONAL → scara-HMI. Per-agent claim-manifest + move-if-misplaced request. **Action expected from scara-HMI** (~25 min next active session; higher-priority than scara-PLC's parallel request because the 4 Cycle7_X migration is HMI-domain).

# scara-PM → scara-HMI — File Claim Manifest + Move-If-Misplaced Request

**From:** scara-PM
**To:** scara-HMI
**Date:** 2026-05-19
**Pairs with:** [`PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md`](PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md) (the cross-tree-ban directive) + [`AGENT_BOOTSTRAP_HMI.md`](AGENT_BOOTSTRAP_HMI.md) (your bootstrap)
**Mirrors:** v9-PM's §5 claim-manifest mechanism (from `v9/UserFiles/VCIExportedContents/PM_DIRECTIVE_2026-05-19_v9NoCrossTreeWriting.md`)

---

## §1 Background — why YOU specifically get this request

On 2026-05-19, operator surfaced that **4 SCARA-target HMI handoffs** had landed in v9 tree despite their `TIA target =` rows pointing at `hmiDemoSCARA_ABCDE.ap20`:

| Misplaced file | TIA target | Likely subject |
|---|---|---|
| `HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md` | SCARA | BackColor Range-dyn + 4 PLC Q&A answers |
| `HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md` | SCARA | 53 UBP Manual widget rebind to GDB_ManualCmd/Status |
| `HMI_HANDOFF_2026-05-18_Cycle7_4_Canvas1280x800Correction.md` | SCARA (despite name) | Canvas-size correction handoff |
| `HMI_HANDOFF_2026-05-18_Cycle7_5_PalletScreen_C71_FacadeAdoption.md` | SCARA | Palletizing screen adopting C71 HMI Status Facade |

scara-PM filesystem-moved all 4 to SCARA tree the same day (now `??` untracked there; awaits catch-up #3 commit). Cycle7_2 stayed in v9 tree — its `Project:` line says `hmiDemoMomoryCapacity_v9` so it's correctly v9-targeted, not misplaced.

**Authorship is ambiguous from file content alone.** Predecessor links inside the 4 moved files cite v9 PLC handoffs heavily (C65 rebind requirements, C66 mega absorption, C67 Phase 2 V3 verified) — could mean v9-HMI authored them as response handoffs to v9 PLC work, OR could mean scara-HMI cited v9 PLC predecessors and defaulted to v9 tree out of habit.

**This is why scara-HMI gets the more pointed request.** The 4 misplaced files are HMI-domain; you're either the author (defaulting-to-v9-tree drift) or you're not (lane violation by v9-HMI). The claim manifest disambiguates.

---

## §2 What scara-PM is asking

### §2.1 Publish a claim manifest (~20 min)

Author a short `[INFORMATIONAL]` handoff in SCARA tree listing files you authored 2026-05-13 → 2026-05-19, with one row per file showing TIA target.

**Filename:** `HMI_HANDOFF_2026-05-19_scaraHMI_FileClaimManifest.md` (place in SCARA `VCIExportedContents/`)

**Suggested format** (open-ended; v9-PM didn't enforce a skeleton):

```markdown
**Status:** INFORMATIONAL → scara-PM. File claim manifest per PM request.

# scara-HMI File Claim Manifest 2026-05-13 → 2026-05-19

## C# builder source (in shared TiaUnifiedAuto/)

| File | Lane | Authored by me? |
|---|---|---|
| `Builders/Ubp/UbpAutoBuilder.cs` | scara-HMI (UBP family) | ✅ |
| `Builders/Ubp/UbpManualBuilder.cs` | scara-HMI (UBP family) | ✅ |
| ... | ... | ... |

## HMI handoffs (cross-agent docs)

| File | TIA target | Authored by me? |
|---|---|---|
| `HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md` | SCARA | ✅ |
| `HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md` | SCARA (was in v9 tree, moved by scara-PM 2026-05-19) | ⬜ TBD — please indicate |
| `HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md` | SCARA (was in v9 tree, moved by scara-PM 2026-05-19) | ⬜ TBD — please indicate |
| `HMI_HANDOFF_2026-05-18_Cycle7_4_Canvas1280x800Correction.md` | SCARA (was in v9 tree, moved by scara-PM 2026-05-19) | ⬜ TBD — please indicate |
| `HMI_HANDOFF_2026-05-18_Cycle7_5_PalletScreen_C71_FacadeAdoption.md` | SCARA (was in v9 tree, moved by scara-PM 2026-05-19) | ⬜ TBD — please indicate |
| `HMI_HANDOFF_2026-05-18_Cycle7_2_C65RebindAbsorption.md` (in v9 tree) | v9 | ⬜ TBD (you read this file? authored? unrelated?) |
```

**The 4 ⬜ TBD rows are the key signal scara-PM needs.** If you claim them (any subset), it's the legacy "v9 = canonical comm tree" drift — fixable via the cross-tree-ban directive going forward, no retroactive blame. If you disclaim them, scara-PM logs `[INFO] authorship indeterminate` and flags to operator that v9-HMI may have been authoring SCARA-target work.

**Coverage scope:** C# builders in `TiaUnifiedAuto/Builders/Ubp/**` + HMI handoffs you authored + (optional) widget rebind notes / Cycle 7_X work products. **Skip:** files you only READ (cross-team refs from v9 PLC handoffs), files in PM_Workspace/ (PM lane), files in PLC lane.

### §2.2 Move-if-misplaced (forward-looking discipline)

Per `PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md` §5:

> If you find a misplaced handoff (e.g., a file in v9 tree whose `TIA target =` is `hmiDemoSCARA_ABCDE.ap20`, or vice versa), **filesystem-move it yourself**. No PM coordination needed for the mechanical move. Surface to scara-PM in chat after move; do NOT cross-post copies.

Same rule for C# builder source — if you find UBP builder code under v9-HMI's `Builders/Palletizing/` or `Builders/Recipe/`, that's misfiled; move to `Builders/Ubp/`. (Audit 2026-05-19 confirmed TiaUnifiedAuto folder structure is currently clean — `Builders/Ubp/` ↔ `Builders/Palletizing/`/`Recipe/`/`PalletPattern/` are properly isolated. But discipline applies forward.)

**Don't edit bodies during the move.** Per AGENT_CONTRACT §11, handoff bodies are immutable. Only location changes.

---

## §3 Pre-write checklist before any new HMI handoff

Reinforcement from your AGENT_BOOTSTRAP_HMI.md ⛔ warning box + PM_DIRECTIVE §3 — for every new HMI handoff you author going forward:

1. **What's my agent identity?** `scara-HMI` → SCARA tree
2. **What's the handoff's `TIA target =` line?** `hmiDemoSCARA_ABCDE.ap20` → SCARA tree
3. **Does my write path contain `hmiDemoSCARA_ABCDE`?** If you see `hmiDemoMomoryCapacity_v9` in your write path, **STOP** — you've drifted lanes.

The 4 misplaced files all had `TIA target = hmiDemoSCARA_ABCDE.ap20` in their header tables. The 3-question check would have caught it at step 3 (path mismatch) before write. Internalize this.

---

## §4 Response horizon

**Next active session** (no hard deadline). v9-PM uses the same pattern on v9 side — open-ended with carry-forward in scoreboard if pending >1 week. scara-PM will mirror.

The 4 ⬜ TBD claims are the highest-value rows in your manifest. If you have to skip everything else, populate those 4 rows + the Cycle7_2 row (whether you read/cited it).

---

## §5 What this request does NOT ask

- **Body edits to your own handoffs.** Per AGENT_CONTRACT §11 handoff immutability. The 4 moved files stay byte-identical in their new SCARA-tree location.
- **Blame attribution for misplacement.** Authorship discovery is forensic, not punitive. Whichever way the 4 ⬜ TBD rows resolve, the corrective path is the same: directive + bootstrap discipline going forward.
- **Retroactive Cycle 7_0 audit.** Pre-2026-05-13 work predates current conventions; out of scope.
- **PM source files** (`PM_Workspace/**`) — that's scara-PM lane.
- **PLC agent files** — scara-PLC gets a parallel request (`PM_HANDOFF_2026-05-19_scaraPLC_FileClaimRequest.md`).
- **Coordinating with v9-HMI** — they get the equivalent from v9-PM (§5 of `v9/.../PM_DIRECTIVE_2026-05-19_v9NoCrossTreeWriting.md`). Independent.

---

## §6 Closure markers

- `[NEEDS_scaraHMI]` Claim manifest publication, especially the 4 ⬜ TBD Cycle7_X rows + Cycle7_2 read/cite status (open-ended; next active session)
- `[NEEDS_scaraHMI]` Internalize 3-question pre-write checklist (§3); apply on every future HMI handoff
- `[INFORMATIONAL]` Move-if-misplaced discipline (forward-looking; TiaUnifiedAuto audit clean as of 2026-05-19)
- `[INFO]` Mirrors v9-PM §5 mechanism; cross-PM coordination loop demonstrated working
- `[CARRYFORWARD]` Goes into scara-PM catch-up #3 absorption when ready

---

## §7 Cross-references

- The directive: [`PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md`](PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md)
- Your bootstrap (⛔ warning box at top): [`AGENT_BOOTSTRAP_HMI.md`](AGENT_BOOTSTRAP_HMI.md)
- scara-PLC's parallel request: [`PM_HANDOFF_2026-05-19_scaraPLC_FileClaimRequest.md`](PM_HANDOFF_2026-05-19_scaraPLC_FileClaimRequest.md)
- The 4 moved files (now in SCARA tree, will be staged into catch-up #3 commit):
  - [`HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md`](HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md)
  - [`HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md`](HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md)
  - [`HMI_HANDOFF_2026-05-18_Cycle7_4_Canvas1280x800Correction.md`](HMI_HANDOFF_2026-05-18_Cycle7_4_Canvas1280x800Correction.md)
  - [`HMI_HANDOFF_2026-05-18_Cycle7_5_PalletScreen_C71_FacadeAdoption.md`](HMI_HANDOFF_2026-05-18_Cycle7_5_PalletScreen_C71_FacadeAdoption.md)
- Cycle7_2 (still in v9 tree, correctly v9-targeted): `../../../hmiDemoMomoryCapacity_v9/UserFiles/VCIExportedContents/HMI_HANDOFF_2026-05-18_Cycle7_2_C65RebindAbsorption.md`
- v9-PM directive (mirror, §5 has the originating mechanism): `../../../hmiDemoMomoryCapacity_v9/UserFiles/VCIExportedContents/PM_DIRECTIVE_2026-05-19_v9NoCrossTreeWriting.md`
- AGENT_CONTRACT.md §11 (handoff immutability) + §2.3 (HMI lane) + §2.5 (HMI_BINDING_MAP write rule)

---

_End of PM_HANDOFF_2026-05-19_scaraHMI_FileClaimRequest.md_
