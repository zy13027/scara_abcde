**Status:** PENDING_VERIFICATION → operator (deploy runbook + smoke). **PLC source IMPLEMENTED tonight** (FB V3.0 + iDB shape + 2 GDB updates landed). **TIA target:** `hmiDemoSCARA_ABCDE.ap20`. **Predecessors:** `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_ConveyorAndSensors.md` (5 new GDB_MCDData Members, deployment pending) + `PLC_HANDOFF_2026-05-19_Cycle7_6_PlcSmokeResults_J2ModuloVerified.md` (current state baseline) + existing `FB_AutoCtrl_Palletizing.scl` V2.0 (16-box × 3-phase place-only cycle).

---

## ✅ IMPLEMENTATION STATUS (2026-05-19 late evening) — V3.0 SOURCE LANDED

V3.0 source-side changes implemented this session after operator-provided NX measurements via `nx_open_probe`. **4 files modified:**

| File | Change | LOC delta |
|---|---|---|
| `PLC_1/Program blocks/500_AutoCtrl/FB_AutoCtrl_Palletizing.scl` | V2.0 → **V3.0 full rewrite** (preserves V2.0's REGION 1 path init pattern + adds 6-phase per-box state machine + suction-cup gripper handshake + belt/spawn coordination + auto-complete at 16 boxes) | 234 → ~300 lines |
| `PLC_1/Program blocks/Instances/instFB_AutoCtrl_Palletizing.xml` | +10 new Members: `sRTRIGPalletizingSensor` (R_TRIG) + `statPhase` / `statBoxIdx` / `statBoxesPlaced` / `statSubState` (Int) + `statSpawnRequested` (Bool) + 4× TON_TIME (`instGripperCloseTimer` / `instGripperOpenTimer` / `instArrivalSettleTimer` / `instSpawnDelayTimer`) | +10 Members |
| `PLC_1/Program blocks/500_AutoCtrl/GDB_PalletizingCmd.xml` | +16 new Members with **NX-derived StartValues**: `bo_PalletDone` + `bo_RequireSensorGate` (Bool) + 14 LReal config values | +16 Members |
| `PLC_1/Program blocks/500_AutoCtrl/GDB_Control.xml` | +**2 new Members**: `bo_gripperGrip` (Bool, level — TRUE during transport) + `bo_gripperRelease` (Bool, pulse — TRUE during active release). Maps to MCD's TWO discrete gripper signals `sScaraGrip` + `sScaraRelease` (per operator's signal-mapping screenshot). | +2 Members |

**GDB_PalletizingCmd Member StartValues (operator-tunable post-deploy):**

| Member | StartValue | Source |
|---|---|---|
| `lr_PickX` / `lr_PickY` / `lr_PickZ` | 1170.44 / 531.76 / -1018.85 | nx_open_probe |
| `lr_PickApproachZOffset` | 220.0 | nx_open_probe |
| `lr_PalletTopX` / `lr_PalletTopY` / `lr_PalletTopZ` | -0.48 / 1500.31 / -866.73 | nx_open_probe (Pallet 1 N) |
| `lr_PlaceApproachZOffset` | 100.0 | default (V2.0 pattern) |
| `lr_BoxHeight` | 150.0 | default; operator tunes to actual box dims |
| `lr_BeltVelocityNormal` | 100.0 mm/s | default |
| `lr_ArrivalSettleMs` | 300.0 | default |
| `lr_GripperCloseMs` / `lr_GripperOpenMs` | 300.0 / 200.0 | defaults |
| `lr_SpawnDelayMs` | 500.0 | default |
| `bo_RequireSensorGate` | TRUE | enables real arrival gating; FALSE = phantom mode |

**V3.0 state machine fully wired:**

- Phase 7 (WAIT_ARRIVAL) → R_TRIG on `GDB_MCDData.PalletizingSensor` (per NX correction; NOT PackingSensor)
- Phases 1-3 (pick): ABOVE_PICK → PICK_DESCEND → close suction (300ms TON) → PICK_RAISE
- Phases 4-6 (place): APPROACH_PLACE → PLACE_DESCEND → open suction (200ms TON) → PLACE_RETRACT
- INCREMENT: statBoxesPlaced++; if = statActiveBoxes → COMPLETE (statPhase 8); else spawn next + restart belt + spawn-delay TON → WAIT_ARRIVAL
- COMPLETE (phase 8): BeltVelocity=0, bo_PalletDone=TRUE, i16_PalletStep=0, suction off; operator must Stop or re-Init

**Pre-promotion gates STILL OPEN (operator's lane):**

| Gate | Status | What operator does |
|---|---|---|
| 🟡 NX MCD Object Source addition + `sActivateSpawnContainer` wiring | NOT yet done | Per §2.2 of this handoff (4 steps in saContainerBelt Signal Adapter) |
| 🟡 NX MCD suction-cup signal wiring | NOT yet done | Add `sScaraGripperClose` (or equivalent) signal to the SCARA-side Signal Adapter → bind via TIA Hardware Config to `GDB_Control.bo_gripperCloseCmd` PLC path. Without this, suction physics won't actuate when PLC commands. |
| 🟢 NX MCD pallet positions verified | DONE via nx_open_probe | Reflected in GDB StartValues |
| 🟢 PalletizingSensor confirmed as pick gate | DONE via nx_open_probe | V3.0 SCL binds to it |
| 🟡 GDB_MCDData additions deploy | PENDING | Earlier handoff `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_ConveyorAndSensors.md` — needs same VCI import cycle |

### Concrete Signal Mapping Table (for TIA Hardware Config External Signal Mapping)

After VCI import + Compile + MRES + Download, the operator opens **Hardware Config → SCARA station → kinematic group → External Signal Mapping** dialog. The PLCSIMAdv Instances type already has 8 mapped signals (the 4 axis positions + 4 velocities, pre-existing). The remaining **9 MCD signals need mapping**:

| MCD Signal | Owner | IO Type | Map to PLC tag | Notes |
|---|---|---|---|---|
| `sScaraGrip` | SignalAdapter | Input (PLC→MCD) | **`GDB_Control.bo_gripperGrip`** | Suction-cup vacuum ON (level signal) |
| `sScaraRelease` | SignalAdapter | Input (PLC→MCD) | **`GDB_Control.bo_gripperRelease`** | Suction-cup active-release pulse |
| `sContainerBeltPackingSensor` | saContainerBelt_1 | Output (MCD→PLC) | **`GDB_MCDData.PackingSensor`** | Optional/informational sensor (NOT pick gate) |
| `sContainerBeltPalletizingSensor` | saContainerBelt_1 | Output (MCD→PLC) | **`GDB_MCDData.PalletizingSensor`** | ★ THE PICK GATE — V3.0 cycle waits here |
| `sActivateSpawnContainer` | saContainerBelt_1 | Input (PLC→MCD) | **`GDB_MCDData.SpawnContainerCmd`** | Pulse triggers Object Source spawn |
| `sContainerBeltVel` | saContainerBelt_1 | Input (PLC→MCD) | **`GDB_MCDData.BeltVelocity`** | Conveyor belt speed (mm/s) |
| `sSinkContainer` | **saContainerPallet_1** | Input (PLC→MCD) | **`GDB_MCDData.SinkContainerLeft`** | Left-pallet sink (V3.0 doesn't actively use; map for V3.1+) |
| `sSinkContainer` | **saContainerPallet_2** | Input (PLC→MCD) | **`GDB_MCDData.SinkContainerRight`** | Right-pallet sink (V3.0 doesn't actively use; map for V3.1+) |

**Auto-map vs manual map**: Click **Do Auto Mapping** first — TIA will probably auto-match all 8 by name similarity (e.g., `sScaraGrip` ↔ `bo_gripperGrip` may need fuzzy match). For any unmapped rows, drag-drop from MCD-side list to PLC tag selector. The two `sSinkContainer` rows are distinguishable by Owner column (`saContainerPallet_1` vs `_2`).

After mapping: click **Check for N→1 Mapping** → expect pass → **OK**. Mapped Signals count should go 8 → 16 (8 existing + 8 new; the 17th MCD signal scaraXSpeed is one extra in your screenshot count — may be a hidden A-axis or similar; doesn't affect the cycle).

### Operator full deploy runbook (after pre-promotion gates clear)

1. **NX MCD work**: Add Object Source (or confirm exists) + wire `pActivateSpawnContainer ← sActivateSpawnContainer` in saContainerBelt_1; for the suction cup, confirm the signal adapter named "SignalAdapter" already has sScaraGrip + sScaraRelease declared (per your screenshot — they DO exist). Save MCD scene.
2. **VCI import**: 5 files into TIA project — `FB_AutoCtrl_Palletizing.scl`, `instFB_AutoCtrl_Palletizing.xml`, `GDB_PalletizingCmd.xml`, `GDB_Control.xml`, `GDB_MCDData.xml`. Force overwrite.
3. **TIA Compile**: Right-click PLC_1 → Compile → Hardware and software. Expect 0E / 0W.
4. **PLCSIM-Adv DemoScara_ABCDE → MRES** (mandatory — multiple GDB + iDB shape changes)
5. **Download to device**: Hardware and software (only changes)
6. **TIA Hardware Config**: External Signal Mapping dialog → map the 8 new signals per the table above
7. **PLCSIM-Adv Watch Table** preflight: write `GDB_PalletizingCmd.bo_Mode := TRUE` → pulse `bo_InitPallet := TRUE` then FALSE → confirm `bo_PalletInitialed = TRUE` + `i16_TotalBoxes = 16`
8. **Pulse `bo_Start := TRUE` then FALSE** — observe in NX MCD viewport:
   - First box spawns at source
   - Belt runs at 100 mm/s
   - Box reaches end → PalletizingSensor fires → belt stops
   - SCARA descends, suction on, raises, traverses to pallet, places, releases, retracts
   - Process repeats 16 times
   - After box 16: `bo_PalletDone = TRUE`, belt stays stopped
9. **Pulse `bo_Stop := TRUE` then FALSE** — cycle returns to idle
10. **Reset for next run**: pulse `bo_InitPallet` again → ready

### Carry-forward to next session

- 🟡 `[NEEDS_HUMAN]` Operator runs §5 step 1-2 (NX MCD wiring + VCI import) — earliest gate
- ⏳ `[NEEDS_SCARA_PLC]` Author `SmokeTest_PalletizeOrchestrated_V3.ps1` (15-gate suite per §6 of this handoff) once operator confirms first manual smoke succeeded; harness gives automated regression coverage
- ⏳ If gripper actuation doesn't work after step 6: operator + scara-HMI may need to add a separate suction-cup signal adapter or confirm the existing one is wired
- ⏳ V3.1 enhancements: PalletizingSensor confirmation (deferred); two-pallet variant; recipe-driven dimensions; HMI cycle-7.7 header strip integration

---

# PLC_HANDOFF — Full simulation fit-out: box-orchestrated palletizing with conveyor + sensors (2026-05-19)

**Project:** `hmiDemoSCARA_ABCDE`
**Audience:** operator (NX MCD pre-flight + deploy runbook) + scara-PLC agent (FB code work, next session)
**Scope:** Convert the current free-running 16-box palletizing cycle (place-on-pallet only, no real pick) into a **fully orchestrated end-to-end simulation** where boxes spawn at source, ride conveyor, get picked by SCARA at belt end, and land at calculated pallet positions, repeating until 16 boxes are stacked.

## 1. Executive summary — what changes

| Aspect | Today (V2.0) | Target (V3.0 — this handoff) |
|---|---|---|
| Cycle origin | Free-running on `bo_Mode=TRUE`, wraps 48→1 forever | Spawn-driven; one box at a time; **stops after 16 placed** |
| Box source | Nonexistent (SCARA just dances over pallet positions) | NX MCD Object Source spawns physical boxes |
| Pick action | Not modeled — SCARA goes only to pallet `approach/place/retract` | **Real pick from belt end**; gripper close/open commands; box rides on SCARA TCP |
| Belt | Static (no behavior) | PLC-driven `BeltVelocity` — runs at V_norm; pauses to 0 during pick descend |
| Arrival detection | None | **`GDB_MCDData.PackingSensor`** (MCD collision sensor at belt end) gates pick phase |
| Spawn rhythm | None | PLC pulses `GDB_MCDData.SpawnContainerCmd` after each retract — paces box arrivals |
| Cycle completion | Never (operator manually stops) | Auto-complete after `boxCount = TotalBoxes` (16); sets `bo_PalletDone` lamp |
| Phases per box | 3 (approach / place / retract) | **6** (above_pick / pick_descend / pick_raise / approach_place / place_descend / place_retract) |
| Architecture | Single FB with counter-driven step | Single FB with explicit per-box state machine + outer box counter |

**Key invariant preserved**: 1 active `MC_MoveLinearAbsolute` instance per scan on `ScaraArm3D` (OB91 safety) — multi-phase state machine drives the single shared instance with different target positions and Execute pulses, mirroring `FB_AutoCtrl_ABCDE` Wang Shuo 4-REGION pattern + C69 V1.0 pick-place FB pattern.

## 2. Operator's NX MCD pre-flight (BEFORE any PLC change can deploy)

### 2.1 — Required physics objects (operator confirms existence or adds)

| Object | Type | Purpose | Status (operator to confirm) |
|---|---|---|---|
| `osContainerSource` (or similar) | **Object Source** | Spawns box at source position when triggered | ❓ Likely NOT yet present — operator's screenshot (saContainerBelt signal adapter) showed `sActivateSpawnContainer` signal declared but NO parameter mapping. Needs to be added or wired. |
| `tsContainerBelt` | Transport Surface | Conveyor belt with `parallel speed` parameter | ✅ Present (saContainerBelt → pContainerBeltVel → tsContainerBelt parallel speed) |
| `csContainerBeltPacking` | Collision Sensor | Fires when box arrives at belt end (pick position) | ✅ Present |
| `csContainerBeltPalletizing` | Collision Sensor | Fires when box arrives at palletizing area | ✅ Present (used optionally as safety/confirmation) |
| Box `RigidBody` prefab | Rigid Body | Template the Object Source spawns | ❓ Operator confirms exists and has gripper-attachable point |
| SCARA TCP gripper mount | Rigid Body / Frame | Where picked boxes attach during transport | ❓ Operator confirms — depends on whether the demo uses a real gripper FB or phantom attach |

### 2.2 — Required signal-adapter wiring (operator completes `saContainerBelt`)

Per the operator's screenshot, `saContainerBelt` is wired for 3 of 4 signals. **One gap remains:**

| Signal | Wired? | Operator action |
|---|---|---|
| `sContainerBeltVel` (Input, PLC→MCD) | ✅ Formula `pContainerBeltVel ← sContainerBeltVel` | nothing |
| `sContainerBeltPackingSensor` (Output, MCD→PLC) | ✅ Formula `sContainerBeltPackingSensor ← pContainerBeltPackingSensor` | nothing |
| `sContainerBeltPalletizingSensor` (Output, MCD→PLC) | ✅ Formula `sContainerBeltPalletizingSensor ← pContainerBeltPalletizingSensor` | nothing |
| **`sActivateSpawnContainer`** (Input, PLC→MCD) | ❌ **NOT wired** — signal exists but no Parameter row + no Formula | **REQUIRED before PLC retest can spawn** |

**Step-by-step for the `sActivateSpawnContainer` wiring:**

1. NX MCD viewport → open `saContainerBelt` Signal Adapter (Mechatronics ribbon → Signal Adapter, double-click `saContainerBelt`)
2. **Parameters section** → click ➕ Add Parameter → in dialog:
   - Select the **Object Source** physics object (`osContainerSource` or whatever it's named)
   - Pick its **trigger** parameter (may be named `active`, `start`, `trigger`, or `enabled` depending on the Object Source builder version)
   - Alias: `pActivateSpawnContainer`
   - Data Type: bool
   - R/W: W (write — PLC drives MCD)
3. **Formulas section** → click ➕ Add Formula:
   - Assign to: `pActivateSpawnContainer`
   - Formula: `sActivateSpawnContainer`
4. OK to commit; Save MCD scene; re-export physics if your workflow requires it
5. Verify: in saContainerBelt → Parameters tab now shows 4 rows (currently shows 3); Formulas tab shows 4 (currently 3)

### 2.3 — Operator-confirmed geometric values (from nx_open_probe 2026-05-19 late evening)

**Resolved via NX Open probe** (`nx_open_probe / locations.json`). Values are WCS-frame.

| Parameter | Value | Source |
|---|---|---|
| **SCARA shoulder hub** (column rotation pivot) | (0.0, 0.0, 1028.5) | NX Open — reference only |
| **PICK_STOP_WCS** (where box halts and SCARA grabs) | **(1170.44, 531.76, -1018.85)** mm | NX Open — `csContainerBeltPalletizing` sensor centre |
| **PICK_APPROACH_Z** (~220mm above pick, safe clearance) | **-800.0** | NX Open — `PICK_STOP_WCS.z + 218.85` |
| **PALLET_NORTH_TOP_WCS** (Pallet 1, +Y side; place target centre) | **(-0.48, 1500.31, -866.73)** mm | NX Open — `palletContainer` top centre |
| **PALLET_SOUTH_TOP_WCS** (Pallet 2, -Y side; mirror) | (-0.48, -1499.69, -866.97) mm | NX Open — `palletContainer mirror` top centre |
| **PALLET_APPROACH_Z** (~220mm above pallet top) | **-650.0** | NX Open — `PALLET_TOP.z + 216.73` |
| **PALLET_XY_FOOTPRINT** (each pallet's bbox X × Y dimensions) | **800 × 1200** mm | NX Open — `palletContainer` bbox |
| **Vertical lift pick → place** | +152 mm | NX Open — `PALLET_TOP.z - PICK_STOP.z` |
| **Horizontal travel pick → Pallet 1** | ΔX=-1170, ΔY=+969 (≈1518 mm) | NX Open derived |
| **Distance from SCARA column** — pick / Pallet 1 / Pallet 2 | 1286 / 1500 / 1500 mm | NX Open — all reachable; SCARA effective reach ≈3550 mm |

**Sensor naming correction (important):**

| Original handoff assumption | NX Open reality |
|---|---|
| `csContainerBeltPacking` = pick station | NOT the pick gate (operator decides what it does — possibly box-entry-on-belt or unused) |
| `csContainerBeltPalletizing` = palletizing-area sensor | **THIS IS THE PICK GATE** — built-in conveyor sensor that fires when box reaches halt position; SCARA grabs at `Z ≈ -1019` |

**V3.0 design correction**: The pick-arrival gate binds to **`GDB_MCDData.PalletizingSensor`** (mirrors `sContainerBeltPalletizingSensor` ← `csContainerBeltPalletizing.triggered`), NOT `PackingSensor` as initially specified. `PackingSensor` role becomes optional / informational (operator may wire it to mark box-spawn-confirmed or leave unused).

### 2.4 — Remaining timing parameters (operator confirms or accepts defaults)

| Parameter | Default | Operator-chosen |
|---|---|---|
| Default belt velocity | 100 mm/s | `_______` |
| Pre-pick pause (after PalletizingSensor TRUE, before SCARA descends) | 300 ms | `_______` |
| Gripper close hold time (between command and verify-pick) | 300 ms | `_______` |
| Gripper open hold time | 200 ms | `_______` |
| Inter-box spawn delay (after one box placed, before next spawn) | 500 ms | `_______` |

## 3. PLC architecture — `FB_AutoCtrl_Palletizing` V3.0

### 3.1 — Decision: modify in place vs new FB

**Recommendation: modify in place (V2.0 → V3.0).** Rationale:
- Existing iDB (`instFB_AutoCtrl_Palletizing` DB#4) already wired in OB1 (Main.scl REGION C69_FB_PalletizingProgramme analog OR REGION Palletizing_Cycle)
- All HMI bindings to `i16_PalletStep` + `statTargetPos` + facade routing continue to work (semantics preserved per §3.4)
- Single bo_Mode/bo_Start/bo_Stop/bo_InitPallet control surface unchanged
- Mode mutex with ABCDE + Manual modes unchanged
- iDB shape change needs MRES on download regardless of which approach

### 3.2 — New iDB Members (added to existing instFB_AutoCtrl_Palletizing)

| New Member | Datatype | Purpose | Notes |
|---|---|---|---|
| `statPhase` | Int (1..6) | Current phase within current box | 1=ABOVE_PICK, 2=PICK_DESCEND, 3=PICK_RAISE, 4=APPROACH_PLACE, 5=PLACE_DESCEND, 6=PLACE_RETRACT |
| `statBoxIdx` | Int (1..16) | Current box being processed | Independent of `i16_PalletStep` (which stays 1..48 for HMI compat) |
| `statBoxesPlaced` | Int | Boxes successfully placed (completion counter) | Increments after PLACE_RETRACT; cycle complete when = statActiveBoxes |
| `statSubState` | Int | Phase-internal sub-state | Encoded: 0=request_motion, 1=motion_in_progress, 2=motion_done, 3=waiting_external (sensor/timer) |
| `statSpawnRequested` | Bool | TRUE between SpawnContainerCmd pulse and PackingSensor rising edge | Prevents double-spawn |
| `instGripperCloseTimer` | TON_TIME | Gripper close hold timer | New TON instance |
| `instGripperOpenTimer` | TON_TIME | Gripper open hold timer | New TON instance |
| `instArrivalSettleTimer` | TON_TIME | Post-arrival belt-stop settle timer | New TON instance |
| `instSpawnDelayTimer` | TON_TIME | Inter-box spawn delay timer | New TON instance |

GDB additions:

| New GDB_PalletizingCmd Member | Datatype | Purpose |
|---|---|---|
| `lr_PickX` | LReal | Pick position X in WCS (StartValue: operator-confirmed) |
| `lr_PickY` | LReal | Pick position Y |
| `lr_PickZ` | LReal | Pick position Z (descend target) |
| `lr_PickApproachZOffset` | LReal | Z offset above pick for approach/retract (default 100) |
| `lr_BeltVelocityNormal` | LReal | Belt velocity when running (default 100 mm/s) |
| `bo_PalletDone` | Bool | Pulses TRUE when all 16 boxes placed; HMI lamp / cycle-complete indicator |
| `bo_RequireSensorGate` | Bool | If TRUE: cycle requires PackingSensor before each pick. If FALSE: phantom mode (free-running like V2.0 for backward-compat smoke testing). Default TRUE in V3.0. |

GDB_MCDData additions: **none** — already added in `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_ConveyorAndSensors.md` (BeltVelocity / SpawnContainerCmd / SinkContainer / PackingSensor / PalletizingSensor).

### 3.3 — State machine (per box, 6 phases × 16 boxes)

```
                              ┌───────────────────────────────┐
   bo_Mode RISING + Start ──> │  INIT (statBoxIdx := 1,       │
                              │       statBoxesPlaced := 0,   │
                              │       SpawnContainerCmd pulse,│
                              │       BeltVelocity := V_norm) │
                              └─────────────┬─────────────────┘
                                            │
                                            ▼
                              ┌───────────────────────────────┐
                              │  WAIT_ARRIVAL                 │
                              │  poll PackingSensor           │ <───┐
                              │  on TRUE -> BeltVelocity := 0 │     │
                              │  start instArrivalSettleTimer │     │
                              └─────────────┬─────────────────┘     │
                                            │ (300ms settle)        │
                                            ▼                       │
PHASE 1 ABOVE_PICK ──> drive (pickX, pickY, pickZ+offset)            │
   wait Done                                                          │
                                            │                       │
                                            ▼                       │
PHASE 2 PICK_DESCEND ──> drive (pickX, pickY, pickZ)                  │
   wait Done                                                          │
   on Done: bo_gripperCloseCmd := TRUE                                │
            start instGripperCloseTimer (300ms)                       │
            wait Timer.Q                                              │
                                            │                       │
                                            ▼                       │
PHASE 3 PICK_RAISE ──> drive (pickX, pickY, pickZ+offset)             │
   wait Done                                                          │
                                            │                       │
                                            ▼                       │
PHASE 4 APPROACH_PLACE ──> drive pts[(boxIdx-1)*3 + 1] (approach z+100)│
   wait Done                                                          │
                                            │                       │
                                            ▼                       │
PHASE 5 PLACE_DESCEND ──> drive pts[(boxIdx-1)*3 + 2] (place z)       │
   wait Done                                                          │
   on Done: bo_gripperCloseCmd := FALSE                               │
            start instGripperOpenTimer (200ms)                        │
            wait Timer.Q                                              │
                                            │                       │
                                            ▼                       │
PHASE 6 PLACE_RETRACT ──> drive pts[(boxIdx-1)*3 + 3] (retract z+100) │
   wait Done                                                          │
                                            │                       │
                                            ▼                       │
   INCREMENT: statBoxesPlaced++                                       │
              statBoxIdx++                                            │
   IF statBoxesPlaced >= statActiveBoxes (=16) THEN goto COMPLETE     │
   ELSE: SpawnContainerCmd pulse                                      │
         BeltVelocity := V_norm                                       │
         start instSpawnDelayTimer (500ms)                            │
         wait Timer.Q                                                 │
                                            │                       │
                                            ▼                       │
                                       (loop back to WAIT_ARRIVAL)────┘

COMPLETE: BeltVelocity := 0
          bo_PalletDone := TRUE (one-shot pulse, cleared on next bo_Mode rising edge)
          i16_PalletStep := 0
          statPhase := 0
          (bo_Mode stays TRUE — operator must manually stop or re-init)
```

### 3.4 — HMI display semantics (`i16_PalletStep` 1..48 preserved)

To keep existing HMI bindings + C71 facade routing working, drive `i16_PalletStep` to mirror the **place phase** progression only:

```
i16_PalletStep := (statBoxIdx - 1) * 3 + (statPhase - 3)   when statPhase IN (4, 5, 6)
i16_PalletStep := (statBoxIdx - 1) * 3 + 1                  when statPhase IN (1, 2, 3, "WAIT_ARRIVAL")
                                                              (holds at "approach" position display)
```

This way, the HMI's existing step display (1..48) shows the place progression. Pick phases (which are belt-side) freeze the display at the approach step for the current box. No HMI rebind required.

If operator wants pick-phase visibility too, V3.1 can add a separate `i16_PhaseInBox` Int Member (1..6) for diagnostic display.

### 3.5 — `statTargetPos` (facade source)

The facade's `target_x/y/z/a` should reflect whatever the SCARA is moving toward right now. So `statTargetPos` updates per-phase:
- Phases 1,2,3: target = pick pose (X, Y, Z varies per phase)
- Phases 4,5,6: target = pallet pose (existing pts[] data)

No new bindings needed; just update the variable per phase.

## 4. SCL code skeleton (for next-cycle scara-PLC implementation)

```scl
FUNCTION_BLOCK "FB_AutoCtrl_Palletizing"
{ S7_Optimized_Access := 'TRUE' }
VERSION : 3.0
// V3.0 (2026-05-19): Full simulation fit-out — sensor-gated pick-from-belt
//                   + place-on-pallet + spawn rhythm + auto-stop at 16 boxes.
// Replaces V2.0 free-running 3-phase cycle.

   VAR
      // (existing V2.0 statics preserved)
      sRTRIGInitialPath { InstructionName := 'R_TRIG' } : R_TRIG;
      sRTRIGStart       { InstructionName := 'R_TRIG' } : R_TRIG;
      sRTRIGStop        { InstructionName := 'R_TRIG' } : R_TRIG;
      instMoveLinAbs    { InstructionName := 'MC_MOVELINEARABSOLUTE'; S7_SetPoint := 'False' } : MC_MOVELINEARABSOLUTE;
      pts : Array[1..48] of "UDT_typePoint5";
      statTargetPos     { S7_SetPoint := 'False' } : "UDT_typePoint5";
      statOldStep       : Int;
      statExecutePulse  : Bool;
      statMoveDoneOld   : Bool;
      statTotalDistance : LReal;
      statProgress      : LReal;
      statActiveBoxes   : Int;

      // V3.0 additions
      statPhase             : Int;     // 0=idle, 1..6=motion phases, 7=WAIT_ARRIVAL, 8=COMPLETE
      statBoxIdx            : Int;     // 1..16
      statBoxesPlaced       : Int;
      statSubState          : Int;     // 0=request, 1=in_progress, 2=done, 3=waiting_external
      statSpawnRequested    : Bool;
      sRTRIGPackingSensor   { InstructionName := 'R_TRIG' } : R_TRIG;
      instGripperCloseTimer { InstructionName := 'TON_TIME' } : TON_TIME;
      instGripperOpenTimer  { InstructionName := 'TON_TIME' } : TON_TIME;
      instArrivalSettleTimer{ InstructionName := 'TON_TIME' } : TON_TIME;
      instSpawnDelayTimer   { InstructionName := 'TON_TIME' } : TON_TIME;
   END_VAR

BEGIN
   // REGION 1 — INITIALIZE_PATH (unchanged from V2.0, computes pts[1..48])
   // ... (same FOR loop as V2.0)

   // REGION 2 — START (modified to set up V3.0 state machine)
   #sRTRIGStart(CLK := "GDB_PalletizingCmd".bo_Start);
   IF "GDB_PalletizingCmd".bo_Mode
       AND "GDB_PalletizingCmd".bo_ESTOP_LOCK
       AND ("GDB_PalletizingCmd".i16_PalletStep = 0)
       AND #sRTRIGStart.Q
       AND "GDB_PalletizingCmd".bo_PalletInitialed
       AND NOT "GDB_PalletizingCmd".bo_Alarm
       AND NOT "GDB_MachineCmd".bo_Mode
       AND NOT "GDB_ManualCmd".bo_Mode
   THEN
       #statBoxIdx        := 1;
       #statBoxesPlaced   := 0;
       #statPhase         := 7;        // WAIT_ARRIVAL
       #statSubState      := 0;
       "GDB_PalletizingCmd".bo_PalletDone := FALSE;
       "GDB_PalletizingCmd".i16_PalletStep := 1;
       "GDB_MCDData".SpawnContainerCmd := TRUE;     // pulse first spawn
       #statSpawnRequested := TRUE;
       "GDB_MCDData".BeltVelocity := "GDB_PalletizingCmd".lr_BeltVelocityNormal;
   END_IF;

   // REGION 3 — STOP (unchanged, also reset state)
   #sRTRIGStop(CLK := "GDB_PalletizingCmd".bo_Stop);
   IF #sRTRIGStop.Q THEN
       "GDB_PalletizingCmd".i16_PalletStep := 0;
       #statPhase := 0;
       "GDB_MCDData".BeltVelocity := 0.0;
       "GDB_MCDData".SpawnContainerCmd := FALSE;
   END_IF;

   // REGION 4 — V3.0 STATE MACHINE
   #sRTRIGPackingSensor(CLK := "GDB_MCDData".PackingSensor);

   // Clear spawn pulse 1 scan after sent (rising-edge contract with MCD)
   IF "GDB_MCDData".SpawnContainerCmd AND #statSpawnRequested AND #statSubState = 0 THEN
       "GDB_MCDData".SpawnContainerCmd := FALSE;
   END_IF;

   CASE #statPhase OF
       7: // WAIT_ARRIVAL
           IF #sRTRIGPackingSensor.Q OR NOT "GDB_PalletizingCmd".bo_RequireSensorGate THEN
               "GDB_MCDData".BeltVelocity := 0.0;
               #statSpawnRequested := FALSE;
               #instArrivalSettleTimer(IN := TRUE, PT := T#300MS);
           END_IF;
           IF #instArrivalSettleTimer.Q THEN
               #instArrivalSettleTimer(IN := FALSE);
               #statPhase    := 1;       // -> ABOVE_PICK
               #statSubState := 0;
           END_IF;

       1: // ABOVE_PICK
           #statTargetPos.x := "GDB_PalletizingCmd".lr_PickX;
           #statTargetPos.y := "GDB_PalletizingCmd".lr_PickY;
           #statTargetPos.z := "GDB_PalletizingCmd".lr_PickZ + "GDB_PalletizingCmd".lr_PickApproachZOffset;
           #statTargetPos.a := 0.0;
           // (issue Execute pulse on statSubState transition; on Done -> next phase)
           // ... (state-transition logic; see "motion helper" below)

       2: // PICK_DESCEND
           #statTargetPos.z := "GDB_PalletizingCmd".lr_PickZ;
           // on motion Done: pulse gripperClose + start timer + wait Q
           // on timer.Q: -> phase 3

       3: // PICK_RAISE
           #statTargetPos.z := "GDB_PalletizingCmd".lr_PickZ + "GDB_PalletizingCmd".lr_PickApproachZOffset;
           // on Done: -> phase 4

       4: // APPROACH_PLACE
           #statTargetPos := #pts[(#statBoxIdx - 1) * 3 + 1];
           // ... + HMI step mirror: i16_PalletStep := (statBoxIdx-1)*3 + 1
           // on Done: -> phase 5

       5: // PLACE_DESCEND
           #statTargetPos := #pts[(#statBoxIdx - 1) * 3 + 2];
           // ... + HMI step mirror: i16_PalletStep := (statBoxIdx-1)*3 + 2
           // on Done: open gripper + timer
           // on timer.Q: -> phase 6

       6: // PLACE_RETRACT
           #statTargetPos := #pts[(#statBoxIdx - 1) * 3 + 3];
           // ... + HMI step mirror: i16_PalletStep := (statBoxIdx-1)*3 + 3
           // on Done: increment + check complete

       8: // COMPLETE
           "GDB_MCDData".BeltVelocity := 0.0;
           "GDB_PalletizingCmd".bo_PalletDone := TRUE;
           "GDB_PalletizingCmd".i16_PalletStep := 0;
           #statPhase := 0;
   END_CASE;

   // Motion driver (one MC_MoveLinearAbsolute, Execute pulses on phase transition):
   #statExecutePulse := (motion phase active) AND (statSubState = 0 transition);
   #instMoveLinAbs(AxesGroup    := "ScaraArm3D",
                   Execute      := #statExecutePulse,
                   Position     := (statTargetPos packed into array),
                   Velocity     := 300.0, ...);

   // Motion-done detection: when instMoveLinAbs.Done & statSubState=1 -> statSubState:=2
   // After-Done logic in each phase advances state machine.

END_FUNCTION_BLOCK
```

The full ~250-300 LOC implementation is deferred to scara-PLC's next session — this skeleton lays out the architecture; the patterns from `FB_AutoCtrl_ABCDE` V8 (progress-based blending) and C69 `FB_PalletizingProgramme` V1.0 (8-phase pick-place state machine with TON gripper handshake) are directly reusable for filling in the gaps marked `// ...`.

## 5. Operator deploy runbook (after scara-PLC implements V3.0)

| Step | Action | Expected |
|---|---|---|
| 0 | Operator does NX MCD pre-flight per §2.1-2.2 (Object Source + sActivateSpawnContainer wiring); fills §2.3 measured values | NX scene saved with 4-of-4 signals wired in saContainerBelt |
| 1 | scara-PLC modifies FB_AutoCtrl_Palletizing.scl V2.0 → V3.0; updates instFB_AutoCtrl_Palletizing.xml iDB shape; adds GDB_PalletizingCmd Members per §3.2 | Source diff ready for VCI import |
| 2 | scara-PLC writes new smoke `SmokeTest_PalletizeOrchestrated_V3.ps1` (~15 gates per §6) | Harness ready |
| 3 | Operator VCI imports the 3 modified files (FB + iDB + GDB) | TIA project tree shows updated shapes |
| 4 | TIA Compile → Hardware and software (only changes) | 0E / 0W |
| 5 | **PLCSIM-Adv DemoScara_ABCDE → MRES (Memory Reset)** — mandatory, GDB + iDB shape changes | State → Stop |
| 6 | Download to device → Hardware and software | State → Run |
| 7 | Operator confirms NX MCD scene running with simulation play active | Box renders waiting at source |
| 8 | scara-PLC runs `SmokeTest_PalletizeOrchestrated_V3.ps1` | Expect 15/15 PASS |
| 9 | Operator visual confirmation: NX viewport shows box-by-box spawn → belt → pick → place across 16 boxes → stops | 4 layers × 4 boxes stacked on pallet |

## 6. Smoke test plan — `SmokeTest_PalletizeOrchestrated_V3.ps1`

| Gate | Test |
|---|---|
| V3.PreflightTags | All new GDB / iDB Members readable |
| V3.SclLoaded | statPhase + statBoxIdx + statBoxesPlaced exposed in iDB |
| V3.SeedPickPosition | Operator-confirmed pick position written to GDB_PalletizingCmd.lr_PickX/Y/Z; round-trip read-back |
| V3.InitPallet | bo_InitPallet pulse → bo_PalletInitialed=TRUE + statActiveBoxes=16 |
| V3.StartTriggersSpawn | bo_Start pulse → SpawnContainerCmd=TRUE for 1 scan → returns FALSE |
| V3.BeltStarts | BeltVelocity=lr_BeltVelocityNormal after Start |
| V3.WaitArrivalGates | Until PackingSensor=TRUE (manual write via Watch Table or smoke-driven), statPhase stays at 7 |
| V3.OnArrivalBeltStops | After PackingSensor TRUE: BeltVelocity → 0 within 1s |
| V3.PickPhaseAdvance | statPhase advances 1→2→3 with MC.Done events; gripper close at end of phase 2 |
| V3.PlacePhaseAdvance | statPhase advances 4→5→6 with MC.Done events; gripper open at end of phase 5 |
| V3.BoxCountIncrements | After phase 6 Done: statBoxesPlaced++, statBoxIdx++ |
| V3.SpawnPulseAfterPlace | After phase 6: SpawnContainerCmd pulses again for next box |
| V3.SixteenBoxesComplete | After 16 boxes: bo_PalletDone=TRUE; statPhase=0; BeltVelocity=0; i16_PalletStep=0 |
| V3.HmiStepMirror | i16_PalletStep correctly mirrors place phases (1..48) and freezes during pick phases |
| V3.NoAbcdeRegression | ABCDE cycle still works in mutex (operator toggles modes, both isolated) |

Target: 15/15 PASS.

## 7. Optional MCD-side enhancements (defer)

| Feature | When | Why |
|---|---|---|
| Use `PalletizingSensor` (csContainerBeltPalletizing) as visual confirmation of box-on-pallet | After V3.0 lands | Adds safety: if SCARA places + retracts but PalletizingSensor doesn't fire, raise alarm |
| `SinkContainer[1..2]` (pallet sink + belt sink) wiring | V3.1 cycle | Pallet-full clean-up; not strictly needed for first orchestration |
| Multi-pallet support (after 16 boxes, sink pallet + restart cycle) | V3.2+ | Demo enhancement |
| Variable box dimensions (recipe-driven from C70 V5 V1.0 `GDB_ActiveRecipe`) | V3.3+ | Integration with existing recipe system |

## 8. Open decisions for operator (please confirm in next session)

1. **Gripper actuation model**: Does NX MCD have a real gripper attached to SCARA TCP that responds to `GDB_Control.bo_gripperCloseCmd`? Or phantom (box just attaches via Object Sink trick)?
2. **Belt stop during pick**: Should belt stop completely (BeltVelocity=0) or slow down (BeltVelocity=10) during pick? Default = stop.
3. **Cycle restart**: After 16 boxes placed, should the operator manually restart (bo_Mode FALSE → TRUE) or auto-restart on next bo_InitPallet pulse?
4. **Box spacing on belt**: Should next spawn be gated on previous box's pick complete (current design) or on a fixed time interval (alternative — risks pile-up)?
5. **Initial pick-position values for GDB defaults**: Operator measures and provides lr_PickX/Y/Z + lr_PickApproachZOffset + lr_BeltVelocityNormal defaults; these go into GDB_PalletizingCmd.xml StartValues.

## 9. Closure markers

- `[DESIGN]` Architecture + state machine + iDB shape + operator runbook documented for scara-PLC's next implementation cycle
- `[NEEDS_HUMAN]` Operator NX MCD pre-flight per §2.1-2.2 (Object Source + sActivateSpawnContainer wiring) — required before deploy
- `[NEEDS_HUMAN]` Operator confirms / measures geometric parameters per §2.3 (8 values) — required for GDB StartValues
- `[NEEDS_HUMAN]` Operator answers 5 open decisions per §8 — required before SCL implementation
- `[NEEDS_SCARA_PLC]` Next session: implement FB_AutoCtrl_Palletizing V3.0 SCL + update iDB.xml + update GDB_PalletizingCmd.xml + write SmokeTest_PalletizeOrchestrated_V3.ps1 per §3-§6 spec
- `[BLOCKS-ON]` §2 + §8 operator inputs gate the SCL work
- `[INFO]` Cross-tree write #4 of the night (operator-routed); audit-trail PM_HANDOFF deferred to next v9-PM cycle now covers 4 deviations
- `[INFO]` Cycle-7.6 PLC-side closure + J2 modulo VERIFIED enable this next-step work (V3.0 leverages the stable rotary-joint behavior from Wang Shuo's modulo convention)

## 10. Cross-references

- `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_ConveyorAndSensors.md` — 5 new GDB_MCDData Members already added (BeltVelocity / SpawnContainerCmd / SinkContainer / PackingSensor / PalletizingSensor); this design uses them all
- `PLC_HANDOFF_2026-05-19_Cycle7_6_PlcSmokeResults_J2ModuloVerified.md` — current baseline (V2.0 12/12 PASS, J2 modulo confirmed)
- `PLC_HANDOFF_2026-05-18_C71_Phase2_HmiStatusFacade_Verified.md` — C71 facade routes target_x/y/z/a + currentStep/totalSteps; preserved in V3.0
- v9-PLC's C69 `FB_PalletizingProgramme` V0.1→V1.0 rewrite — reference 8-phase pick-place state machine pattern (this V3.0 simplifies to 6 phases — picks aren't from a dynamic point)
- `FB_AutoCtrl_ABCDE` V8 — reference for progress-based blending advance + BM_BLENDING_HIGH BufferMode=5
- Existing `FB_AutoCtrl_Palletizing.scl` V2.0 — base to modify
- Existing `GDB_Palletizing.palletPoints[]` — V2.0 uses pts[] internally; V3.0 keeps same pts[] for place phases

End of full-simulation fit-out design handoff 2026-05-19.
