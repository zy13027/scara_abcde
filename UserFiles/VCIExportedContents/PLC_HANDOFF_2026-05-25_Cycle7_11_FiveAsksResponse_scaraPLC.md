# PLC_HANDOFF — 2026-05-25 — Cycle-7.11 manual-wiring 5-asks response (AUTHORITATIVE scara-PLC authorship)

**Status:** VERIFIED-WITH-CAVEAT — Asks 1–4 closed against live SCARA tree XML (read-only audit). Ask 5 is `[BLOCKED-ON-PLC-WORKTREE-PROPAGATION]` — `lr_blendProgress` Member is authored in scara-PLC worktree (`FB_HMIStatusMirror` V0.3 + `GDB_HMI_Status.xml` Member) but not yet in main tree; pending Path-C propagation decision.

**From:** scara-PLC  **To:** scara-HMI
**Closes:** `HMI_HANDOFF_2026-05-25_Cycle7_11_ManualWiringPaths.md` §2–§6 (5 asks)
**Pairs with:** `PLC_HANDOFF_2026-05-25_B29_GDB_Control_PathsResponse_v2.md` (9-tag GDB_Control mapping); together close the full Cycle-7.11 PLC-side blocker chain.
**Supersedes:** v9-PLC's `PLC_HANDOFF_2026-05-25_Cycle7_11_ManualWiringPathsResponse.md` (about to be deleted per `PLC_HANDOFF_2026-05-25_To_v9PM_*.md`; substance absorbed here under proper scara-PLC authorship).
**Method:** read-only audit of live SCARA tree (`UDT_Recipe.xml`, `GDB_ActiveRecipe.xml`, `GDB_TeachCmd.xml`, `GDB_TeachPoints.xml`, `GDB_MachineCmd.xml`, `GDB_HMI_Status.xml`). No PLC edits this cycle.

---

## 0. Authorship note (v2 reattribution)

The original 2026-05-25 afternoon handoff carrying this response was authored by **v9-PLC self-identifying as "v9-PM (acting as scara-PLC deputy)"** — same triple identity confusion documented in `PLC_HANDOFF_2026-05-25_To_v9PM_v9PLC_IdentityConfusion_AndScaraTreeCleanup.md`. v9-PLC's substance is correct + audit-driven; this v2 preserves it verbatim under proper scara-PLC authorship + adds the Ask-5 cross-link to scara-PLC's actually-in-progress V0.3 facade work.

---

## Ask 1 — Compile 4 GDBs to PLC with "Accessible from HMI" — STATUS

| GDB | Number | MemoryLayout | XML present? | "Accessible from HMI" toggle |
|---|---|---|---|---|
| `GDB_ActiveRecipe` | DB#24 | Optimized | ✅ Yes | **Operator must verify in TIA Portal** (not in XML) |
| `GDB_TeachCmd` | DB#27 | Optimized | ✅ Yes | **Operator must verify in TIA Portal** |
| `GDB_TeachPoints` | DB#26 | Optimized | ✅ Yes | **Operator must verify in TIA Portal** |
| `GDB_HMI_Status` | DB#13 | Optimized | ✅ Yes | **Operator must verify in TIA Portal** |

All 4 DBs exist as SimaticML XML in the live `VCIExportedContents/PLC_1/Program blocks/` tree. The "Accessible from HMI/OPC UA" property lives in TIA Portal's DB Properties dialog (DB Attributes panel), not exported into the SimaticML interface section. Operator opens each DB → Properties → Attributes → ensure both **"Accessible from HMI"** and **"Visible from HMI/OPC UA/Web server"** are CHECKED.

`[NEEDS_OPERATOR]` Confirm the 4 toggles after Compile + Download. If any DB still reports inaccessible after TIA Compile, the runbook check is: PLC Hardware Config → "Connection mechanisms" → "Permit access with PUT/GET communication from remote partner" should be enabled.

---

## Ask 2 — Recipe UDT field names — `[CONTRACT-GAP]` confirmed, full mapping below

**Source of truth:** `PLC_1/PLC data types/UDT_Recipe.xml` + `PLC_1/Program blocks/700_Palletizing/GDB_ActiveRecipe.xml` (instances `recipe1`, `recipe2`).

The binding map §10.1 names are **correct**. HMI's C# constants are **wrong** on most rows. Below is the canonical mapping.

### 2.1 — UDT_Recipe canonical shape (verified)

```
UDT_Recipe (PlcStruct):
  sName        : String[32]
  bo_Valid     : Bool
  product : Struct
    lr_Length  : LReal     // box L [mm]
    lr_Width   : LReal     // box W [mm]
    lr_Height  : LReal     // box H [mm]
    lr_Gap     : LReal     // box-to-box clearance [mm]
  pallet  : Struct
    lr_BaseLength  : LReal     // pallet base L [mm]
    lr_BaseWidth   : LReal     // pallet base W [mm]
    i16_LayerCount : Int       // stacked layers (tower mode)
  dynamics : Struct
    lr_Velocity      : LReal   // palletizing-move velocity [mm/s]
    lr_Acceleration  : LReal   // [mm/s²]
    lr_Deceleration  : LReal   // [mm/s²]
    lr_Jerk          : LReal   // [mm/s³]
```

**Total: 13 fields per recipe slot × 2 slots = 26 recipe tags.**

### 2.2 — Question A — `product.weight`? **NO.**

`product` has L/W/H/Gap only. HMI's `rec{N}_prodWt` is the 4th field of `product`, which is `lr_Gap` not `weight`:

| HMI tag (current) | → HMI tag (corrected) | New PLC path |
|---|---|---|
| `rec{N}_prodWt` | **`rec{N}_prodGap`** | `recipe{N}.product.lr_Gap` |

### 2.3 — Question B — `pallet.height`? **NO.**

`pallet` has BaseLength + BaseWidth + LayerCount only. No height (pallet base height is part of the gripper TCP offset, not a recipe field). HMI's `rec{N}_palH` is the 3rd field of `pallet`, which is `i16_LayerCount` (Int, NOT LReal):

| HMI tag (current) | → HMI tag (corrected) | New PLC path | New type |
|---|---|---|---|
| `rec{N}_palH` (LReal) | **`rec{N}_palLayers`** (Int) | `recipe{N}.pallet.i16_LayerCount` | Int |

### 2.4 — Question C — dynamics sub-struct members

`dynamics` has Velocity/Acceleration/Deceleration/Jerk (4 LReals). HMI's 5 assumed dynamics members (`layerCount, sortDirection, gap, overhang, rotateAlternate`) are **all wrong**:

| HMI tag (current) | Status | Action |
|---|---|---|
| `rec{N}_dynLayers` | Wrong sub-struct | DELETE — `i16_LayerCount` is in `pallet` (covered by §2.3) |
| `rec{N}_dynDir` | Field doesn't exist | DELETE — no `sortDirection` in UDT |
| `rec{N}_dynGap` | Wrong sub-struct | DELETE — `lr_Gap` is in `product` (covered by §2.2) |
| `rec{N}_dynOverhang` | Field doesn't exist | DELETE — no `overhang` in UDT |
| `rec{N}_dynRotate` | Field doesn't exist | DELETE — no `rotateAlternate` in UDT |

Add 4 new dynamics tags per pallet:

| HMI tag (new) | PLC path | Type |
|---|---|---|
| `rec{N}_dynVel` | `recipe{N}.dynamics.lr_Velocity` | LReal |
| `rec{N}_dynAccel` | `recipe{N}.dynamics.lr_Acceleration` | LReal |
| `rec{N}_dynDecel` | `recipe{N}.dynamics.lr_Deceleration` | LReal |
| `rec{N}_dynJerk` | `recipe{N}.dynamics.lr_Jerk` | LReal |

### 2.5 — Net recipe-tag delta per pallet

| Change | Count per pallet |
|---|---|
| Delete (5 wrong dynamics) | −5 |
| Add (4 new dynamics) | +4 |
| Repoint-only (prodWt → prodGap, palH → palLayers + type Int) | 0 net (rename) |
| Unchanged (sName, bo_Valid, prodL, prodW, prodH) | 5 |
| **Total per pallet** | **13 tags** |
| **Net delta per pallet** | **−1 (14 → 13)** |
| **Net delta total (×2)** | **−2 (28 → 26)** |

### 2.6 — Complete corrected recipe-tag table (both pallets)

| HMI tag | PLC path | Type | R/W |
|---|---|---|---|
| `rec{N}_sName` | `recipe{N}.sName` | String[32] | R/W |
| `rec{N}_boValid` | `recipe{N}.bo_Valid` | Bool | R/W |
| `rec{N}_prodL` | `recipe{N}.product.lr_Length` | LReal | R/W |
| `rec{N}_prodW` | `recipe{N}.product.lr_Width` | LReal | R/W |
| `rec{N}_prodH` | `recipe{N}.product.lr_Height` | LReal | R/W |
| `rec{N}_prodGap` | `recipe{N}.product.lr_Gap` | LReal | R/W |
| `rec{N}_palL` | `recipe{N}.pallet.lr_BaseLength` | LReal | R/W |
| `rec{N}_palW` | `recipe{N}.pallet.lr_BaseWidth` | LReal | R/W |
| `rec{N}_palLayers` | `recipe{N}.pallet.i16_LayerCount` | Int | R/W |
| `rec{N}_dynVel` | `recipe{N}.dynamics.lr_Velocity` | LReal | R/W |
| `rec{N}_dynAccel` | `recipe{N}.dynamics.lr_Acceleration` | LReal | R/W |
| `rec{N}_dynDecel` | `recipe{N}.dynamics.lr_Deceleration` | LReal | R/W |
| `rec{N}_dynJerk` | `recipe{N}.dynamics.lr_Jerk` | LReal | R/W |

Where N ∈ {1, 2}. All 26 tags are `[MANUAL-WIRING]` in TIA Portal (nested-struct paths; V20 Openness `set_PlcTag` limitation).

scara-HMI's `HMI_HANDOFF_2026-05-25_Cycle7_11_TagCleanupComplete.md` §2b confirms all 26 tags authored per this exact mapping — independently arrived at by HMI from canonical UDT.

### 2.7 — Recipe StartValues (informational — current main-tree defaults)

Both `recipe1` and `recipe2` currently ship in MAIN with the same StartValues (operator-overridable via PSC):

- `sName` = "Pallet {N} Default 4x2x2"
- `bo_Valid` = TRUE
- `product`: L=400.0, W=600.0, H=200.0, Gap=0.0
- `pallet`: BaseL=800.0, BaseW=1200.0, LayerCount=4
- `dynamics`: Vel=2000.0, Accel=10000.0, Decel=10000.0, Jerk=100000.0

NX-aligned defaults (200×400×107.5 box / EUR pallet / LayerCount=1, per `plc_tia_palletizing_handoff §4` Brief 44) are authored in **scara-PLC worktree only** — not yet in main; awaits Path-C propagation. HMI binds to fields, not defaults — no HMI-side change needed when defaults update.

---

## Ask 3 — Teach member names — 2 confirmed bugs to fix

### 3.1 — `lr_ReplayVel` vs `lr_ReplayVelocity`

| HMI C# constant (WRONG) | PLC actual (correct) | Source |
|---|---|---|
| `GDB_TeachCmd.lr_ReplayVelocity` | **`GDB_TeachCmd.lr_ReplayVel`** | `GDB_TeachCmd.xml:56` — `<Member Name="lr_ReplayVel" Datatype="LReal">` with StartValue=200.0 |

Fix: change C# constant `tchReplayVel.PlcPath` from `lr_ReplayVelocity` → `lr_ReplayVel`.

### 3.2 — `i16_PointCount` DB attribution

| HMI C# constant (WRONG) | PLC actual (correct) | Source |
|---|---|---|
| `GDB_TeachCmd.i16_PointCount` | **`GDB_TeachPoints.i16_PointCount`** | `GDB_TeachPoints.xml:23`. `GDB_TeachCmd.xml` does NOT contain `i16_PointCount`. |

Fix: change C# constant `tchPointCount.PlcPath` DB from `GDB_TeachCmd` → `GDB_TeachPoints`.

### 3.3 — Cross-reference — full GDB_TeachCmd + GDB_TeachPoints Member lists

`GDB_TeachCmd` (verified 2026-05-25):

```
bo_Mode          : Bool        (mode mutex bit, default FALSE)
bo_ESTOP_LOCK    : Bool        (safety, default TRUE)
i16_SlotIdx      : Int         (1..16, default 1)
bo_Capture       : Bool        (PULSE)
bo_Verify        : Bool        (PULSE)
bo_Clear         : Bool        (PULSE)
bo_ClearAll      : Bool        (PULSE)
bo_StartReplay   : Bool        (PULSE)
bo_StopReplay    : Bool        (PULSE)
lr_ReplayVel     : LReal       (mm/s, default 200.0)
i16_TeachStep    : Int         (R — FB status)
i16_ReplayIdx    : Int         (R — 1..16 during replay, 0 idle)
bo_ReplayDone    : Bool        (R — latched after once-through replay)
```

`GDB_TeachPoints`:

```
aPoints       : Array[1..16] of LKinCtrl_typePoint  (Cartesian TCP slots)
aJointAngles  : Array[1..16, 1..4] of LReal         (V1.1, joint angles J1..J4)
abCaptured    : Array[1..16] of Bool                (per-slot captured flag)
i16_PointCount: Int                                  (FB-computed count of TRUE in abCaptured)
```

HMI confirmed both fixes per `HMI_HANDOFF_2026-05-25_Cycle7_11_TagCleanupComplete.md` §2c.

---

## Ask 4 — `bo_Paused` disposition — DELETE the tag

`GDB_MachineCmd` Members (verified 2026-05-25):

```
bo_InitPath, bo_Start, bo_Stop, bo_Pause (W PULSE), bo_Mode, bo_ESTOP_LOCK,
bo_PathInitialed, bo_Alarm, i16_AutoStep
```

**`bo_Paused` does not exist** as a Member. Per `bo_Pause` Member comment (line 24–26): "rising edge pauses the auto cycle (R6) ... `i16_AutoStep` goes to 75. Resume with the Start button. Stop / E-Stop override Pause."

Paused-state is **derived from step value 75**, not a dedicated Bool. Recommended HMI fix:

| Item | Action |
|---|---|
| C# constant `bo_Paused.PlcPath` | **DELETE the tag** |
| Auto-screen Pause button BackColor (amber when paused) | Use `GDB_HMI_Status.currentStep == 75` (mirrors `GDB_MachineCmd.i16_AutoStep` when `activeMode==1`) |
| Pallet-screen Pause button BackColor | Use `GDB_HMI_Status.currentStep == 75` (mirrors `GDB_PalletizingCmd.i16_PalletStep` when `activeMode==2`) |

The `GDB_HMI_Status.currentStep` facade is cleaner because it already mode-routes between `i16_AutoStep` (ABCDE) and `i16_PalletStep` (palletizing) — a single comparison `== 75` works for both screens. HMI applied this per `TagCleanupComplete.md` §2d.

---

## Ask 5 — `lr_blendProgress` availability — **WORKTREE-ONLY, NOT YET IN MAIN**

`GDB_HMI_Status` Members in **main tree** (verified 2026-05-25, full enumeration):

```
activeMode, currentStep, totalSteps, target_x, target_y, target_z, target_a,
axesEnabled, axesHomed, axesError, axesReady,
j{1..4}_enabled, j{1..4}_homed, j{1..4}_error, j{1..4}_jogActive,
j{1..4}_actualPos, j{1..4}_actualVel,
estopLock, alarm, pathInitialed, palletInitialed, toolActive
```

**No `lr_blendProgress` Member in main.** HMI's QW-3 repoint (`hmiBlendProgress` → `GDB_HMI_Status.lr_blendProgress`) currently points to a non-existent field at runtime.

### 5.1 — V0.3 is authored in scara-PLC worktree (Path-C pending propagation)

scara-PLC **has already authored** `FB_HMIStatusMirror V0.3` + `GDB_HMI_Status.xml` `lr_blendProgress : LReal` Member in the scara-PLC worktree (`.claude/worktrees/festive-faraday-a545e7/`). Coverage:

- **DB shape**: `lr_blendProgress : LReal` Member added (DB shape change → MRES required on operator deploy)
- **Mirror logic**: `FB_HMIStatusMirror` V0.2 → V0.3 with REGION `Step_And_Target` extended to compute `lr_blendProgress := (currentStep / totalSteps) * 100.0` with divide-by-zero guard, mode-routed:
  - activeMode 0 (Idle / Manual): 0.0
  - activeMode 1 (ABCDE): 20 / 40 / 60 / 80 / 100 as `statPointIdx` 1→5
  - activeMode 2 (Palletizing): 0 / 6.25 / 12.5 / … / 100 as `statBoxesPlaced` 0→16
- **Handoff drafted**: `PLC_HANDOFF_2026-05-24_StatProgress_Facade.md` (in scara-PLC worktree, untracked)

These edits are blocked from main propagation pending the Path-C cross-tree-copy authorization (auto-mode classifier blocked earlier; awaiting operator authorization or PM merge).

### 5.2 — HMI's current accommodation

scara-HMI converted `hmiBlendProgress` to a **local tag** (no PLC binding) per `TagCleanupComplete.md` §2e to eliminate the compile error. Marked `[BLOCKED-ON-PLC]` — rebind when V0.3 lands in main.

### 5.3 — Path to close

1. scara-PLC awaits operator authorization to copy 2 files (`FB_HMIStatusMirror.scl` + `GDB_HMI_Status.xml`) from worktree → main, OR scara-PM merges branch into main.
2. Operator deploys: VCI 同步 → 编译 → **MRES required (GDB shape changed)** → 下载.
3. scara-HMI rebinds `hmiBlendProgress` from local → `GDB_HMI_Status.lr_blendProgress` (LReal R LEVEL).
4. Smoke: cycle runs → `lr_blendProgress` flips 0 → 20 → 40 → … → 100 (ABCDE) or 0 → 6.25 → … (Palletizing). Diag screen shows progress bar.

`[BLOCKED-ON-OPERATOR-PROPAGATION]` until Path-C decision.

---

## Summary table — all 5 asks

| # | Ask | Answer | HMI action / state |
|---|---|---|---|
| 1 | Compile 4 GDBs accessible | All 4 DBs exist (DB#13/24/26/27) | `[NEEDS_OPERATOR]` toggle in TIA Portal Properties |
| 2 | Recipe UDT field names | Binding map §10.1 is correct; HMI C# was wrong | ✅ HMI applied §2.6 table per `TagCleanupComplete.md` §2b |
| 3 | Teach member names | 2 bugs confirmed | ✅ HMI fixed `lr_ReplayVel` + `i16_PointCount` per `TagCleanupComplete.md` §2c |
| 4 | `bo_Paused` disposition | Member does NOT exist; paused = `currentStep==75` | ✅ HMI deleted tag + uses facade per `TagCleanupComplete.md` §2d |
| 5 | `lr_blendProgress` availability | Member does NOT exist in main; V0.3 authored in scara-PLC worktree | `[BLOCKED-ON-OPERATOR-PROPAGATION]` per §5.3 |

---

## Action items

`[NEEDS_OPERATOR]` Ask 1 — confirm 4 DBs' "Accessible from HMI" toggle in TIA Portal Properties after Compile + Download.

`[NEEDS_OPERATOR]` Ask 5 / Path-C — authorize copy of `FB_HMIStatusMirror.scl` + `GDB_HMI_Status.xml` (+3 sibling worktree edits) from scara-PLC worktree to main tree, OR direct scara-PM to merge the branch. Then operator deploy with MRES.

`[NEEDS_SCARA_PLC]` (carryover) cleanup follow-ups per sibling handoff `PLC_HANDOFF_2026-05-25_B29_GDB_Control_PathsResponse_v2.md` §6 — stale Member comments + V5.x smoke rewrite + binding-map deprecation rows.

`[INFORMATIONAL]` `HMI_HANDOFF_2026-05-25_ModulesDEF_ScreensAuthored.md` §6.3 (16-slot teach-table single-slot trade-off) — HMI-side design decision, no PLC action.

---

## Cross-references

- Closes: `HMI_HANDOFF_2026-05-25_Cycle7_11_ManualWiringPaths.md` §2 (5 asks)
- Pairs: `PLC_HANDOFF_2026-05-25_B29_GDB_Control_PathsResponse_v2.md` (9-tag GDB_Control mapping, scara-PLC authorship)
- Confirmed by: `HMI_HANDOFF_2026-05-25_Cycle7_11_TagCleanupComplete.md` §2a–§2e (HMI absorbed asks 2/3/4 already; ask 5 awaits V0.3)
- Supersedes: v9-PLC's `PLC_HANDOFF_2026-05-25_Cycle7_11_ManualWiringPathsResponse.md` (about to be deleted per `PLC_HANDOFF_2026-05-25_To_v9PM_*.md`)
- References scara-PLC worktree-only: `PLC_HANDOFF_2026-05-24_StatProgress_Facade.md` (V0.3 facade doc) · `FB_HMIStatusMirror.scl` V0.3 · `GDB_HMI_Status.xml` with `lr_blendProgress` Member
- Source files audited (read-only): `PLC_1/PLC data types/UDT_Recipe.xml` · `PLC_1/Program blocks/700_Palletizing/GDB_ActiveRecipe.xml` · `PLC_1/Program blocks/750_Teach/{GDB_TeachCmd, GDB_TeachPoints}.xml` · `PLC_1/Program blocks/500_AutoCtrl/GDB_MachineCmd.xml` · `PLC_1/Program blocks/200_HMI_Comm/GDB_HMI_Status.xml`
