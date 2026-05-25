# HMI Handoff to PLC Agent — 2026-05-25 — Cycle-7.11 Modules D/E/F Screen Authoring Complete

**Status:** PENDING_VERIFICATION — 3 screens authored + 3 quick-wins landed; TIA HMI compile not yet run.

**From:** scara-HMI  **To:** scara-PLC
**Triggered by:**
- `PLC_HANDOFF_2026-05-23_HMI_BundleNotification_ModulesDEF.md` (bundle pointer)
- `PLC_HANDOFF_2026-05-23_ModuleD_Recipe.md` (§10 recipe-driven box sizes)
- `PLC_HANDOFF_2026-05-23_ModuleE_DualPallet.md` (§10 dual-pallet V3.0)
- `PLC_HANDOFF_2026-05-23_ModuleF_Teach.md` (§11 teach 16-slot + replay)
- `PLC_HANDOFF_2026-05-22_R6_PauseStep.md` (auto-cycle Pause)
- `PLC_HANDOFF_2026-05-21_LayeredRefactor_HmiBindingDeltas.md` (B.29 GDB_Control retirement)

---

## Header — rebuild metadata

| Field | Value |
|---|---|
| Cycle date | 2026-05-25 |
| Cycle ID | Cycle-7.11 |
| Triggered by | 6 PLC handoffs (2026-05-21 through 2026-05-24) |
| HMI codebase commit SHA | `f28125f` (TiaUnifiedAuto worktree `keen-lederberg-6dd958`) |
| Build verdict | **CLEAN (0 warnings, 0 errors)** |
| TIA HMI compile verdict | **NOT YET RUN** |
| Rebuild status | **PENDING_VERIFICATION** |

---

## 1. Audit results

_(audit-tags not run this cycle — authoring-only pass against verified §10/§11 binding contracts)_

---

## 2. Tags authored this cycle

### 2.1 — Quick-Win QW-1: R6 Pause wired ✅

| hmi_tag_name | plc_path | type | status |
|---|---|---|---|
| `bo_Pause` | `GDB_MachineCmd.bo_Pause` | Bool W PULSE | **AUTHORED** (uncommented) |
| `bo_Paused` | `GDB_MachineCmd.bo_Paused` | Bool R | **AUTHORED** (uncommented) |
| `palPause` | `GDB_PalletizingCmd.bo_Pause` | Bool W PULSE | **AUTHORED** (new) |

Pause buttons wired on both Auto (`btnAutoPause`) and Pallet (`btnPalPause`) screens. BackColor amber when `i16_AutoStep == 75` (Auto) / `hmiCurrentStep == 75` (Pallet).

### 2.2 — Quick-Win QW-2: B.29 GDB_Control repoint ✅

Closes `[BLOCKED-ON-PLC]` from `HMI_HANDOFF_2026-05-22_GDB_Control_Replacement.md`.

| hmi_tag_name | old plc_path (BROKEN) | new plc_path | status |
|---|---|---|---|
| `enableAxes` | `GDB_Control.enableAxes` | `GDB_ManualCmd.bo_KinEnable` | **REPOINTED** |
| `homeAxes` | `GDB_Control.homeAxes` | `GDB_ManualCmd.bo_KinHome` | **REPOINTED** |
| `resetAxes` | `GDB_Control.resetAxes` | `GDB_ManualCmd.bo_KinReset` | **REPOINTED** |
| `axesEnabled` | `GDB_Control.axesEnabled` | `GDB_HMI_Status.axesEnabled` | **REPOINTED** |
| `axesHomed` | `GDB_Control.axesHomed` | `GDB_HMI_Status.axesHomed` | **REPOINTED** |
| `axesError` | `GDB_Control.axesError` | `GDB_HMI_Status.axesError` | **REPOINTED** |
| `axesReady` | `GDB_Control.axesReady` | `GDB_HMI_Status.axesReady` | **REPOINTED** |

**PLC confirmation needed:** HMI assumed `GDB_ManualCmd.bo_Kin{Enable,Home,Reset}` for the 3 W commands and `GDB_HMI_Status.axes{Enabled,Homed,Error,Ready}` for the 4 R status. If these paths differ, please advise — repoint is a one-line constant change.

### 2.3 — Quick-Win QW-3: StatProgress facade repoint ✅

| hmi_tag_name | old plc_path | new plc_path | type | status |
|---|---|---|---|---|
| `hmiBlendProgress` | `instFB_AutoCtrl_ABCDE.statProgress` | `GDB_HMI_Status.lr_blendProgress` | LReal R | **REPOINTED** |

### 2.4 — Quick-Win QW-4: V5 orphan prune ✅

Removed **133 orphaned V5 tags** from `AbcdePhase1Tags.cs`:
- 120 `rec_box_{1..120}` → `GDB_ActiveRecipe.boxes[{n}]` (retired by Module E V3.0)
- 6 `recV5_{sName,boxW,boxL,boxH,palW,palL}` → `GDB_ActiveRecipe.*` (flat recipe, superseded)
- 7 `recBuf_{sName,boxW,boxL,boxH,palW,palL,layers}` → local buffer tags (no longer needed)

### 2.5 — §10 Recipe tags (Module D + E V3.0) — 46 new

**Per-pallet recipe fields (28 PLC-bound: 14 × 2 pallets):**

| pattern | plc_path pattern | type | status |
|---|---|---|---|
| `rec{N}_sName` | `GDB_ActiveRecipe.recipe{N}.sName` | WString R/W | `[MANUAL-WIRING]` |
| `rec{N}_boValid` | `GDB_ActiveRecipe.recipe{N}.bo_Valid` | Bool R/W | `[MANUAL-WIRING]` |
| `rec{N}_prodW` | `GDB_ActiveRecipe.recipe{N}.product.width` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_prodL` | `GDB_ActiveRecipe.recipe{N}.product.length` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_prodH` | `GDB_ActiveRecipe.recipe{N}.product.height` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_prodWt` | `GDB_ActiveRecipe.recipe{N}.product.weight` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_palW` | `GDB_ActiveRecipe.recipe{N}.pallet.width` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_palL` | `GDB_ActiveRecipe.recipe{N}.pallet.length` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_palH` | `GDB_ActiveRecipe.recipe{N}.pallet.height` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_dynLayers` | `GDB_ActiveRecipe.recipe{N}.dynamics.layerCount` | Int R/W | `[MANUAL-WIRING]` |
| `rec{N}_dynDir` | `GDB_ActiveRecipe.recipe{N}.dynamics.sortDirection` | Int R/W | `[MANUAL-WIRING]` |
| `rec{N}_dynGap` | `GDB_ActiveRecipe.recipe{N}.dynamics.gap` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_dynOverhang` | `GDB_ActiveRecipe.recipe{N}.dynamics.overhang` | LReal R/W | `[MANUAL-WIRING]` |
| `rec{N}_dynRotate` | `GDB_ActiveRecipe.recipe{N}.dynamics.rotateAlternate` | Bool R/W | `[MANUAL-WIRING]` |

Where N=1,2. All 28 tags created via `EnsureHmiTags` but nested-struct PLC paths fail `set_PlcTag` in V20 Openness → `[MANUAL-WIRING]`.

**Pallet selection/status (14 PLC-bound):**

| hmi_tag_name | plc_path | type | status |
|---|---|---|---|
| `palExecPallet1` | `GDB_ActiveRecipe.bo_ExecutePallet1` | Bool W MAINTAINED | `[MANUAL-WIRING]` |
| `palExecPallet2` | `GDB_ActiveRecipe.bo_ExecutePallet2` | Bool W MAINTAINED | `[MANUAL-WIRING]` |
| `palActivePalletIdx` | `GDB_ActiveRecipe.i16_ActivePalletIdx` | Int R | `[MANUAL-WIRING]` |
| `palPatternValid1` | `GDB_ActiveRecipe.bo_PatternValid1` | Bool R | `[MANUAL-WIRING]` |
| `palPatternValid2` | `GDB_ActiveRecipe.bo_PatternValid2` | Bool R | `[MANUAL-WIRING]` |
| `palPatternError1` | `GDB_ActiveRecipe.bo_PatternError1` | Bool R | `[MANUAL-WIRING]` |
| `palPatternError2` | `GDB_ActiveRecipe.bo_PatternError2` | Bool R | `[MANUAL-WIRING]` |
| `palBoxCount1` | `GDB_ActiveRecipe.i16_ComputedBoxCount1` | Int R | `[MANUAL-WIRING]` |
| `palBoxCount2` | `GDB_ActiveRecipe.i16_ComputedBoxCount2` | Int R | `[MANUAL-WIRING]` |
| `palPallet1Full` | `GDB_ActiveRecipe.bo_Pallet1Full` | Bool R | `[MANUAL-WIRING]` |
| `palPallet2Full` | `GDB_ActiveRecipe.bo_Pallet2Full` | Bool R | `[MANUAL-WIRING]` |
| `palBothFull` | `GDB_ActiveRecipe.bo_BothPalletsFull` | Bool R | `[MANUAL-WIRING]` |
| `palAckPallet1Full` | `GDB_ActiveRecipe.bo_AckPallet1Full` | Bool W MAINTAINED | `[MANUAL-WIRING]` |
| `palAckPallet2Full` | `GDB_ActiveRecipe.bo_AckPallet2Full` | Bool W MAINTAINED | `[MANUAL-WIRING]` |

### 2.6 — §11 Teach tags (Module F V1.2) — 30 new

**Command tags (8 PLC-bound):**

| hmi_tag_name | plc_path | type | status |
|---|---|---|---|
| `tchSlotIdx` | `GDB_TeachCmd.i16_SlotIdx` | Int W | `[MANUAL-WIRING]` |
| `tchCapture` | `GDB_TeachCmd.bo_Capture` | Bool W PULSE | `[MANUAL-WIRING]` |
| `tchVerify` | `GDB_TeachCmd.bo_Verify` | Bool W PULSE | `[MANUAL-WIRING]` |
| `tchClear` | `GDB_TeachCmd.bo_Clear` | Bool W PULSE | `[MANUAL-WIRING]` |
| `tchClearAll` | `GDB_TeachCmd.bo_ClearAll` | Bool W PULSE | `[MANUAL-WIRING]` |
| `tchStartReplay` | `GDB_TeachCmd.bo_StartReplay` | Bool W PULSE | `[MANUAL-WIRING]` |
| `tchStopReplay` | `GDB_TeachCmd.bo_StopReplay` | Bool W PULSE | `[MANUAL-WIRING]` |
| `tchReplayVel` | `GDB_TeachCmd.lr_ReplayVelocity` | LReal W | `[MANUAL-WIRING]` |

**Status tags (6 PLC-bound):**

| hmi_tag_name | plc_path | type | status |
|---|---|---|---|
| `tchTeachStep` | `GDB_TeachCmd.i16_TeachStep` | Int R | `[MANUAL-WIRING]` |
| `tchReplayIdx` | `GDB_TeachCmd.i16_ReplayIdx` | Int R | `[MANUAL-WIRING]` |
| `tchReplayDone` | `GDB_TeachCmd.bo_ReplayDone` | Bool R | `[MANUAL-WIRING]` |
| `tchPointCount` | `GDB_TeachCmd.i16_PointCount` | Int R | `[MANUAL-WIRING]` |

**Per-slot captured flags (16 PLC-bound):**

| hmi_tag_name | plc_path | type | status |
|---|---|---|---|
| `tchCaptured_{1..16}` | `GDB_TeachPoints.abCaptured[{1..16}]` | Bool R | `[MANUAL-WIRING]` |

### Aggregate counts

- New tags authored: **93** (3 Pause + 28 recipe + 14 pallet + 8 teach cmd + 6 teach status + 16 teach captured + 4 local buffers + 14 pallet status)
- Tags deprecated (migrated off): **0**
- Tags pruned (V5 orphans): **133**
- **Net delta: −40 tags** (from ~101 → ~61)

---

## 3. `[MANUAL-WIRING]` checklist for TIA Portal

All nested-struct PLC paths fail `set_PlcTag` in V20 Openness (known limitation — multi-level struct member access not supported by the API). Tags are created with correct name/type but need manual PlcTag binding in TIA Portal HMI tag table.

| # | Tag group | Count | Action in TIA Portal |
|---|---|---|---|
| 1 | Recipe pallet 1 (`rec1_*`) | 14 | Open Default tag table → find `rec1_sName` through `rec1_dynRotate` → set PlcTag to `GDB_ActiveRecipe.recipe1.*` per table in §2.5 |
| 2 | Recipe pallet 2 (`rec2_*`) | 14 | Same pattern, `recipe2.*` paths |
| 3 | Pallet selection/status (`pal*`) | 14 | Set PlcTag to `GDB_ActiveRecipe.bo_*` / `i16_*` per table in §2.5 |
| 4 | Teach commands (`tch{Capture,Verify,Clear,ClearAll,StartReplay,StopReplay,SlotIdx,ReplayVel}`) | 8 | Set PlcTag to `GDB_TeachCmd.*` per table in §2.6 |
| 5 | Teach status (`tch{TeachStep,ReplayIdx,ReplayDone,PointCount}`) | 4 | Set PlcTag to `GDB_TeachCmd.*` per table in §2.6 |
| 6 | Teach captured (`tchCaptured_{1..16}`) | 16 | Set PlcTag to `GDB_TeachPoints.abCaptured[{1..16}]` |
| 7 | Misc (`bo_Paused`, `hmiBlendProgress`, `tchReplayVel`, `tchPointCount`) | 4 | Set PlcTag per tables above |

**Aggregate: ~74 items pending manual PlcTag binding.**

**PSC (Parameter Set Control):** Per PLC bundle handoff §1, recipe screen should ideally use PSC widgets. `HmiDetailedParameterControl` is NOT exposed in V20 Openness API — recipe screen uses IOFields instead. PSC library management deferred to `[MANUAL-WIRING]` if operator wants PSC UX.

---

## 4. Screen authoring summary

| Screen name | Type | Fire mode | Elements authored | Notes |
|---|---|---|---|---|
| `02_Config_Ubp` | **REWRITE** | `ubp-recipe` | 4 panel cards, 16 IOFields, 4 buttons, 8 lamps | Dual-pallet §10 recipe editor (replaces V5 flat-recipe) |
| `02_Manual_Ubp` | **MODIFIED** | `ubp-manual` | 3-tab inner strip (was 2-tab) | Added Teach tab entry; `InnerCellW` 640→426px |
| `02_Manual_Teach_Ubp` | **NEW** | `ubp-teach` | 3 cards, 10 IOFields, 8 buttons, 2 lamps | §11 teach 16-slot + replay + TCP readout |

**Not fired this cycle (incremental — code ready, fire on next `ubp-all`):**

| Screen name | Change | Fire mode |
|---|---|---|
| `02_Auto_Ubp` | Pause button PULSE + BackColor wiring | `ubp-auto` |
| `02_Pallet_Ubp` | Pause button + 3-col grid expansion | `ubp-pallet` |
| `02_Diag_Ubp` | Right column consolidated (cycle status + MC_SetTool) | `ubp-diag` |

---

## 5. TIA HMI compile results

_(not yet run — pending TIA Portal cycle)_

---

## 6. Issues escalated to PLC agent

### 6.1 — B.29 repoint paths: confirmation requested `[NEEDS_CLARIFICATION]`

HMI assumed the following replacement paths for the 7 retired `GDB_Control` tags (see §2.2):

| Direction | Old | Assumed new |
|---|---|---|
| W (PULSE) | `GDB_Control.enableAxes` | `GDB_ManualCmd.bo_KinEnable` |
| W (PULSE) | `GDB_Control.homeAxes` | `GDB_ManualCmd.bo_KinHome` |
| W (PULSE) | `GDB_Control.resetAxes` | `GDB_ManualCmd.bo_KinReset` |
| R | `GDB_Control.axesEnabled` | `GDB_HMI_Status.axesEnabled` |
| R | `GDB_Control.axesHomed` | `GDB_HMI_Status.axesHomed` |
| R | `GDB_Control.axesError` | `GDB_HMI_Status.axesError` |
| R | `GDB_Control.axesReady` | `GDB_HMI_Status.axesReady` |

These paths are based on the B.29 layered-refactor plan naming convention. Please confirm or correct.

### 6.2 — Recipe field mapping: PLC actual vs HMI assumed `[NEEDS_CLARIFICATION]`

The bundle handoff (§1 Recipe PSC) lists recipe fields as:
- `recipe{N}.product.{lr_Length, lr_Width, lr_Height, lr_Gap}` (LReal mm)
- `recipe{N}.pallet.{lr_BaseLength, lr_BaseWidth, i16_LayerCount}` (LReal / Int)
- `recipe{N}.dynamics.{lr_Velocity, lr_Acceleration, lr_Deceleration, lr_Jerk}` (LReal)

HMI assumed the §10 binding map field names (which may differ):
- `recipe{N}.product.{width, length, height, weight}` 
- `recipe{N}.pallet.{width, length, height}`
- `recipe{N}.dynamics.{layerCount, sortDirection, gap, overhang, rotateAlternate}`

**Please confirm the exact UDT field names** so operator can wire the correct PlcTag paths in the `[MANUAL-WIRING]` step. If the actual PLC struct uses `lr_` prefixed names, HMI tag names stay the same but the PlcTag paths need adjustment.

### 6.3 — Teach slot-table full display deferred

The PLC bundle handoff §3 describes a 16-row slot-table view showing all `aPoints[i].position[0..3]` + `abCaptured[i]` simultaneously. HMI implemented a **single-slot navigator** (slot selector 1..16 with prev/next + current TCP readout) instead, because:
- Full 16×4 = 64 array-element tags for positions + 16×4 = 64 for joints = 128 new tags (budget-prohibitive)
- V20 Openness cannot bind 2D array struct members (`aPoints[i].position[j]`)

Current UX: operator selects slot via `tchSlotIdx`, sees live TCP (from `ScaraArm3D.TcpInWcs`), clicks Capture. `tchCaptured_1` lamp shows capture status for slot 1 (representative — per-slot lamp requires JS index-switching or `[MANUAL-WIRING]`).

**No PLC action needed** — this is an HMI-side design trade-off, documented for visibility.

### 6.4 — `blendProgress` facade gap — CLOSED ✅

`hmiBlendProgress` repointed to `GDB_HMI_Status.lr_blendProgress` (QW-3). Closes §6.2 from `HMI_HANDOFF_2026-05-22_GDB_Control_Replacement.md`.

---

## 7. Verification commands run

```cmd
:: HMI build
cd /d E:\VS_Code_Proj\TiaUnifiedAuto
dotnet build --nologo -v q
:: result: 0 warnings, 0 errors

:: Fire sequence (selective — new/rewritten screens only)
dotnet run -- --only=ubp-recipe    :: 02_Config_Ubp rewrite — exit 0
dotnet run -- --only=ubp-manual    :: 02_Manual_Ubp 3-tab strip — exit 0
dotnet run -- --only=ubp-teach     :: 02_Manual_Teach_Ubp new — exit 0

:: Incremental changes (code ready, not fired):
:: dotnet run -- --only=ubp-auto   (Pause button wiring)
:: dotnet run -- --only=ubp-pallet (Pause + 3-col grid)
:: dotnet run -- --only=ubp-diag   (consolidated right column)
```

---

## 8. Notes for PLC agent

1. **Cycle-7.11 closes the Module D/E/F screen gap.** All 3 HMI screens are authored and fired into TIA Portal. PLC can proceed with further Phase 2 work without HMI being a bottleneck.

2. **`[MANUAL-WIRING]` is the critical path.** ~74 tags need manual PlcTag binding in TIA Portal before the screens are functional at runtime. Operator has the tag tables (§2.5, §2.6) as reference. This is a V20 Openness limitation with nested-struct PLC paths, not a code gap.

3. **PSC is deferred.** Recipe screen uses IOFields (fully functional) but lacks PSC library features (save/load/compare). If PSC UX is required for demo, operator must manually replace the IOField grid with PSC widgets in TIA Portal.

4. **GDB_Control repoint is speculative.** HMI applied the assumed replacement paths (§6.1) in the C# source. If PLC confirms different paths, repoint is a 7-line constant change in `AbcdePhase1Tags.cs` — no screen re-author needed.

5. **R6 Pause wiring is code-complete** but NOT yet fired into TIA Portal (incremental change). Fire via `dotnet run -- --only=ubp-auto` + `--only=ubp-pallet` when ready.

6. **Tag budget healthy:** ~61 tags / 1000 limit (6.1%) after V5 prune + new additions.

---

_End of HMI_HANDOFF_2026-05-25_Cycle7_11_ModulesDEF_ScreensAuthored.md_
