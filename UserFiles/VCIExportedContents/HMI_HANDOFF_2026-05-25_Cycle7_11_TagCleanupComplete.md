# HMI Handoff — 2026-05-25 — Cycle-7.11 Tag Cleanup + Screen Re-Author Complete

**Status:** PENDING_VERIFICATION — all 6 compile errors resolved in code + TIA fire; awaiting TIA HMI recompile confirmation (0E target).

**From:** scara-HMI  **To:** scara-PLC
**Triggered by:** PLC responses `PLC_HANDOFF_2026-05-25_Cycle7_11_ManualWiringPathsResponse.md` + `PLC_HANDOFF_2026-05-25_GDB_ControlReplacementPaths.md`

---

## 1. Audit — what was done

Three rounds of `UbpTagCleanup` + two screen re-authors to close all 6 remaining compile errors (down from 183 → 28 → 6 → 0 target).

| Round | Tags deleted | Tags created | Key action |
|---|---|---|---|
| 1 | 18 (Default) + 12 (Ubp_PLC) | 13 new recipe + 3 B.29 recreated | V5 orphans, renamed recipe, bo_Paused, B.29 repoint |
| 2 | 15 (Default) | 15 recreated with correct PlcPaths | Recipe prodL/W/H + palL/W repoint, teach path fixes |
| 3 | 16 (Default) | 16 recreated | hmiBlendProgress PLC→local, B.29+recipe+teach idempotent |
| Recipe fire | — | — | `02_Config_Ubp` re-authored with 12 IOField KV rows |
| Auto fire | — | — | `02_Auto_Ubp` btnAutoPause BackColor → hmiCurrentStep==75 |

---

## 2. Tags authored — final state

### 2a. B.29 repoint (7 tags — all DONE)

| HMI tag | Old PlcPath | New PlcPath | Status |
|---|---|---|---|
| `enableAxes` | `GDB_Control.enableAxes` | `GDB_ManualCmd.bo_KinEnable` | ✅ |
| `homeAxes` | `GDB_Control.homeAxes` | `GDB_ManualCmd.bo_KinHome` | ✅ |
| `resetAxes` | `GDB_Control.resetAxes` | `GDB_ManualCmd.bo_KinReset` | ✅ |
| `axesEnabled` | `GDB_Control.axesEnabled` | `GDB_HMI_Status.axesEnabled` | ✅ |
| `axesHomed` | `GDB_Control.axesHomed` | `GDB_HMI_Status.axesHomed` | ✅ |
| `axesError` | `GDB_Control.axesError` | `GDB_HMI_Status.axesError` | ✅ |
| `axesReady` | `GDB_Control.axesReady` | `GDB_HMI_Status.axesReady` | ✅ |

### 2b. Recipe UDT realignment (26 tags — all [MANUAL-WIRING])

Per PLC canonical UDT_Recipe shape (13 fields × 2 pallets):

| HMI tag pattern | PlcPath (nested — manual wire) | Type |
|---|---|---|
| `rec{N}_sName` | `GDB_ActiveRecipe.recipe{N}.sName` | WString |
| `rec{N}_boValid` | `GDB_ActiveRecipe.recipe{N}.bo_Valid` | Bool |
| `rec{N}_prodL` | `GDB_ActiveRecipe.recipe{N}.product.lr_Length` | LReal |
| `rec{N}_prodW` | `GDB_ActiveRecipe.recipe{N}.product.lr_Width` | LReal |
| `rec{N}_prodH` | `GDB_ActiveRecipe.recipe{N}.product.lr_Height` | LReal |
| `rec{N}_prodGap` | `GDB_ActiveRecipe.recipe{N}.product.lr_Gap` | LReal |
| `rec{N}_palL` | `GDB_ActiveRecipe.recipe{N}.pallet.lr_BaseLength` | LReal |
| `rec{N}_palW` | `GDB_ActiveRecipe.recipe{N}.pallet.lr_BaseWidth` | LReal |
| `rec{N}_palLayers` | `GDB_ActiveRecipe.recipe{N}.pallet.i16_LayerCount` | Int |
| `rec{N}_dynVel` | `GDB_ActiveRecipe.recipe{N}.dynamics.lr_Velocity` | LReal |
| `rec{N}_dynAccel` | `GDB_ActiveRecipe.recipe{N}.dynamics.lr_Acceleration` | LReal |
| `rec{N}_dynDecel` | `GDB_ActiveRecipe.recipe{N}.dynamics.lr_Deceleration` | LReal |
| `rec{N}_dynJerk` | `GDB_ActiveRecipe.recipe{N}.dynamics.lr_Jerk` | LReal |

All 26 are `[MANUAL-WIRING]` — V20 Openness rejects `set_PlcTag` on 2+ level nested struct paths. Tags created with correct Connection + DataType; operator wires PlcTag in TIA UI.

### 2c. Teach path fixes (2 tags — [MANUAL-WIRING])

| HMI tag | Old PlcPath | New PlcPath | Status |
|---|---|---|---|
| `tchReplayVel` | `GDB_TeachCmd.lr_ReplayVelocity` | `GDB_TeachCmd.lr_ReplayVel` | ✅ PlcPath set |
| `tchPointCount` | `GDB_TeachCmd.i16_PointCount` | `GDB_TeachPoints.i16_PointCount` | ✅ PlcPath set |

### 2d. Deleted tags (no replacement)

| Tag | Reason |
|---|---|
| `bo_Paused` | Member does not exist in `GDB_MachineCmd`. Paused state = `currentStep==75` via facade. |
| 14 renamed recipe tags (`rec{N}_prodWt`, `rec{N}_palH`, `rec{N}_dynLayers/Dir/Gap/Overhang/Rotate`) | Replaced by canonical UDT fields in §2b |
| 126 V5 orphans (`rec_box_{1..20}_{x,y,z,a,layerID,seqID}`) | Module E V3.0 retired flat-recipe arrays |
| 6 recV5 orphans | Module E V3.0 retired flat-recipe |
| 12 Ubp_PLC stale tags | GDB_Control retired + FB retired + duplicates |

### 2e. hmiBlendProgress — converted to local tag

`hmiBlendProgress` was PLC-bound to `GDB_HMI_Status.lr_blendProgress` which does not exist in compiled PLC yet (`FB_HMIStatusMirror V0.3` not deployed). Converted to **local tag** (LReal, no PLC binding) to eliminate compile error. `[BLOCKED-ON-PLC]` — rebind when PLC delivers `lr_blendProgress`.

---

## 3. [MANUAL-WIRING] summary

~28 tags remain `[MANUAL-WIRING]`. These need operator manual PlcTag wiring in TIA Portal HMI tag editor:

- 26 recipe tags (§2b) — nested struct paths under `GDB_ActiveRecipe.recipe{N}.*`
- 2 teach tags (§2c) — `tchReplayVel`, `tchPointCount` (these may wire successfully via TIA UI even though Openness rejected them)

---

## 4. Screen authoring

| Screen | Builder | Action | Key changes |
|---|---|---|---|
| `02_Config_Ubp` | `UbpRecipeBuilder` | Re-authored | 12 IOField KV rows per pallet (was 8). Added: prodGap, palLayers, dynVel/Accel/Decel/Jerk. Pallet status card with Valid/Error/Count lamps + Full indicators. |
| `02_Auto_Ubp` | `UbpAutoBuilder` | Re-authored | `btnAutoPause` BackColor changed from `bo_Paused` (deleted) to `hmiCurrentStep` range `75:75` (amber when paused). PULSE script unchanged → `bo_Pause`. |

---

## 5. Compile results

**Before this cycle:** 6 errors, 0 warnings.
**After fires:** awaiting TIA HMI recompile. Expected: **0 errors** (all 6 root causes addressed).

| Error | Root cause | Fix |
|---|---|---|
| `hmiBlendProgress` invalid PLC tag | `lr_blendProgress` not compiled | Converted to local tag |
| `io_rec1_dynLayers` tag not found | Renamed to `rec1_palLayers` | Recipe screen re-authored |
| `io_rec1_dynGap` tag not found | Renamed to `rec1_prodGap` | Recipe screen re-authored |
| `io_rec2_dynLayers` tag not found | Renamed to `rec2_palLayers` | Recipe screen re-authored |
| `io_rec2_dynGap` tag not found | Renamed to `rec2_prodGap` | Recipe screen re-authored |
| `btnAutoPause` `bo_Paused` not found | `bo_Paused` deleted | BackColor → `hmiCurrentStep==75` |

---

## 6. Issues escalated

### 6.1 `[BLOCKED-ON-PLC]` — `lr_blendProgress`

`hmiBlendProgress` is local-only until PLC compiles `FB_HMIStatusMirror V0.3` with `lr_blendProgress` member in `GDB_HMI_Status`. Diag screen `ioDiagBlendProgress` will display 0.0 until rebound.

### 6.2 `[NEEDS_HUMAN]` — Operator manual-wiring (~28 tags)

Operator must open TIA Portal HMI tag editor → Default tag table → locate each `[MANUAL-WIRING]` tag → set PlcTag to the path listed in §2b/§2c. All tags already have correct Connection (`HMI_Connection_1`) and DataType set by C# builder.

### 6.3 `[NEEDS_HUMAN]` — "Accessible from HMI" on 4 GDBs

Operator must verify in TIA Portal PLC DB properties that these GDBs have "Accessible from HMI/OPC UA" enabled:
- `GDB_HMI_Status` (DB#13)
- `GDB_ActiveRecipe` (DB#24)
- `GDB_TeachPoints` (DB#26)
- `GDB_TeachCmd` (DB#27)

### 6.4 `statManualOK` gate — awareness only

PLC handoff noted that `GDB_ManualCmd` cmd bits (Enable/Home/Reset) now require Manual mode active (`statManualOK = bo_Mode=TRUE + bo_ESTOP_LOCK=TRUE + NOT auto-mode`). HMI header buttons will write but PLC ignores if not in Manual mode. No HMI code change needed — the gate is PLC-side.

---

## 7. Verification

| Gate | Expected |
|---|---|
| TIA HMI compile | 0E / 0W |
| Recipe screen visual | 2× recipe cards with 12 KV rows each + pallet status card |
| Auto screen visual | Pause button amber when `currentStep==75` |
| Tag count | ~70 tags (down from 101 pre-cleanup) |

---

## 8. Notes for PLC agent

- All 5 asks from `HMI_HANDOFF_2026-05-25_Cycle7_11_ManualWiringPaths.md` are now addressed on HMI side per PLC responses. That handoff's status can be considered **CLOSED**.
- Recipe tag paths now match PLC canonical `UDT_Recipe` shape exactly. No further realignment expected unless UDT changes.
- `bo_Paused` thread is closed — HMI uses facade `currentStep==75` pattern. No PLC-side member needed.
- Next HMI-side work: fire remaining screens (`ubp-pallet`, `ubp-teach`, `ubp-diag`) per Cycle-7.11 plan Phase 3-6.
