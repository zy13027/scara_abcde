**Status:** INFORMATIONAL → scara-HMI. Phase 2.2 palletizing PLC surface is deployed + smoke-verified 12/12 PASS (`palletizing_20260518_205340.log`). 9 `GDB_PalletizingCmd` members + 4 `instFB_AutoCtrl_Palletizing.statTargetPos.*` LReals are ready for HMI binding. Proposes `02_Pallet_Ubp` screen + 6th bottom-nav tab "Pallet" for cycle-7.X.

# PLC_HANDOFF — C70 Palletizing HMI Surface Proposal (hmiDemoSCARA_ABCDE)

**Project:** `hmiDemoSCARA_ABCDE`
**Cycle:** C70 (follow-up to C69 Phase 2.2 + post-L1-fix C69 §10)
**Date:** 2026-05-18
**Predecessors:**
- `PLC_HANDOFF_2026-05-18_C69_Phase2_PalletizingBackport.md` — Phase 2.2 palletizing PLC surface VERIFIED 12/12 PASS
- `PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md` — manual control surface STAGED_FOR_PHASE_2
- HMI agent's Cycle-7.0 UBP family (`HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md` in v9 comm tree) — `02_Auto_Ubp` is the model to clone

---

## 1. What's ready to bind (no PLC code change needed)

### 1.1 GDB_PalletizingCmd (9 members, all HMI-accessible)

| Member | Datatype | R/W | Comment |
|---|---|---|---|
| `bo_Mode` | Bool | W | Palletizing AUTO mode selector. Mutex with `GDB_MachineCmd.bo_Mode` (ABCDE) + `GDB_ManualCmd.bo_Mode` (manual) — operator must turn other modes off before enabling. |
| `bo_InitPallet` | Bool | W (PULSE) | Rising edge → fills `pts[1..48]` with 16-box × 4-layer path (z=300/350/400/450). Operator clicks once at session start. Same 250ms JS PULSE pattern as ABCDE `btnInitPath`. |
| `bo_Start` | Bool | W (PULSE) | Rising edge → `i16_PalletStep := 1` (gated on `bo_Mode AND bo_ESTOP_LOCK AND bo_PalletInitialed AND NOT bo_Alarm AND NOT GDB_MachineCmd.bo_Mode AND NOT GDB_ManualCmd.bo_Mode`). |
| `bo_Stop` | Bool | W (PULSE) | Rising edge → `i16_PalletStep := 0`. |
| `bo_ESTOP_LOCK` | Bool | R (lamp, optional) | Safety chain healthy. StartValue TRUE. |
| `bo_PalletInitialed` | Bool | R (lamp) | Path-initialized status. Lights after first `bo_InitPallet` pulse. |
| `bo_Alarm` | Bool | R (lamp) | Reserved for palletizing-specific alarms (placeholder, always FALSE in V2 demo). |
| `i16_PalletStep` | Int | R | Current step 0..48. Display as numeric IOField + derive (box, phase, layer) on HMI side if needed. |
| `i16_TotalBoxes` | Int | R | Always 16 in V2 (hardcoded). May change in V3 recipe-driven. |

### 1.2 instFB_AutoCtrl_Palletizing.statTargetPos (4 LReals)

For real-time target XYZA display (mirror of ABCDE's `instFB_AutoCtrl_ABCDE.statTargetPos.*`):

| Path | Datatype | R/W | Notes |
|---|---|---|---|
| `instFB_AutoCtrl_Palletizing.statTargetPos.x` | LReal | R | TCP X target (mm) — alternates 1500/1800 per 2×2 footprint |
| `instFB_AutoCtrl_Palletizing.statTargetPos.y` | LReal | R | TCP Y target (mm) — alternates -150/+150 |
| `instFB_AutoCtrl_Palletizing.statTargetPos.z` | LReal | R | TCP Z target (mm) — cycles 300/350/400/450 (place) + 100 dive per box |
| `instFB_AutoCtrl_Palletizing.statTargetPos.a` | LReal | R | TCP A wrist (deg) — always 0.0 in V2 |

---

## 2. Recommended HMI screen — clone `02_Auto_Ubp` pattern

### Option A (recommended): new `02_Pallet_Ubp` screen + 6th bottom-nav tab "Pallet"

Layout mirrors `02_Auto_Ubp`:

**Bottom nav** (was 5 tabs: Home / Auto / Manual / Diag / Config):
- New 6-tab variant: **Home / Auto / Pallet / Manual / Diag / Config**
- BackColor Range dyn on `ubpNavSection` Internal Int (same pattern as existing)

**Left column** (`cardStepList` clone, ~5 rows):
- row1: "Layer 1 (Box 1-4, z=300)"
- row2: "Layer 2 (Box 5-8, z=350)"
- row3: "Layer 3 (Box 9-12, z=400)"
- row4: "Layer 4 (Box 13-16, z=450)"
- row5: "Wrap (48 → 1)"
- Each row gets BackColor Range dyn on `i16_PalletStep` (e.g., row1 active when step ∈ [1,12], row2 when ∈ [13,24], ...)

**Center** (`cardProgress` clone): 6 IOFields
- `i16_PalletStep` (R Int)
- `i16_TotalBoxes` (R Int)
- `statTargetPos.x` (R LReal)
- `statTargetPos.y` (R LReal)
- `statTargetPos.z` (R LReal)
- `statTargetPos.a` (R LReal)

**Right column** (`cardPalletCtrl`, ~6 controls):
- `btnPalletInitPath` — PULSE → `GDB_PalletizingCmd.bo_InitPallet`
- `btnPalletStart` — PULSE → `GDB_PalletizingCmd.bo_Start`
- `btnPalletStop` — PULSE → `GDB_PalletizingCmd.bo_Stop`
- `swPalletMode` — TOGGLE → `GDB_PalletizingCmd.bo_Mode`
- `lampPalletInitialed` — Range "1:1" UbpC.SiemensTeal → `bo_PalletInitialed`
- `lampPalletAlarm` — Range "1:1" UbpC.AccentRed → `bo_Alarm`

### Option B (simpler): mode selector on existing `02_Auto_Ubp`

Add a 2-state switch `swAutoModeSelector` (ABCDE / Palletizing) on `02_Auto_Ubp` header. Backed by an HMI internal Bool. The existing buttons `btnAutoStart/Stop/InitPath/Mode` conditionally wire to either:
- ABCDE → `GDB_MachineCmd.bo_*`
- Palletizing → `GDB_PalletizingCmd.bo_*`

Implementation via Tag-set switching or a JS event router that reads `swAutoModeSelector` value and chooses the destination tag at button press time.

**Recommendation: Option A** (dedicated screen). Matches Wang Shuo / Huashili convention where each auto mode gets its own screen. Operator UX is clearer (no implicit mode router). Adding one screen + one nav tab is ~30 min C# Openness builder work cloning the existing `02_Auto_Ubp` Tags + ScreenItems.

---

## 3. Visual progression indicator (optional enhancement)

Per the 4-layer stacking pattern, a 2D top-down view of the pallet showing which box is being processed:

```
Layer 4 (z=450):  ▢ ▢
                  ▢ ▢
Layer 3 (z=400):  ▢ ▢
                  ▢ ▢
Layer 2 (z=350):  ▢ ▢
                  ▢ ▢
Layer 1 (z=300):  ▢ ▢  ← rectangle for box 1 highlighted when step ∈ [1,3]
                  ▢ ▢
```

Render with 16 rectangles, each with BackColor Range dyn on `i16_PalletStep`:
- box 1 rect: active when `i16_PalletStep` ∈ [1,3] → UbpC.AccentGreen
- box 2: ∈ [4,6]
- ...
- box 16: ∈ [46,48]

For each layer (4 boxes), use a 2×2 mini-grid; stack 4 mini-grids vertically. Total = 16 rectangles + 4 layer labels.

**Skip if budget-constrained** — operator can read `i16_PalletStep` numerically and infer layer/box.

---

## 4. Mutex UX guidance (3-way mode arbitration)

Per the 3-way mode mutex contract (ABCDE / Palletizing / Manual mutually exclusive — enforced in PLC's `FB_AutoCtrl_Palletizing` REGION 2 START gate):

**Option 4A (recommended): HMI auto-resolves on mode-toggle**

ALL THREE mode toggle buttons need symmetric auto-clear behavior. **This includes retrofitting the existing `btnAutoMode` on `02_Auto_Ubp`** — when cycle-7.0 was written, ABCDE was the only mode, so `btnAutoMode` is currently a single-write toggle that does NOT clear Palletizing or Manual. Now that Phase G + Phase 2.2 exist, all three need the auto-clear pattern:

```javascript
// btnAutoMode Activated (RETROFIT cycle-7.X — currently single-write in cycle-7.0)
HMIRuntime.Tags("autoMode").Write(true);
HMIRuntime.Tags("palMode").Write(false);     // NEW
HMIRuntime.Tags("manualMode").Write(false);  // NEW

// swPalletMode Activated (NEW from this proposal)
HMIRuntime.Tags("palMode").Write(true);
HMIRuntime.Tags("autoMode").Write(false);
HMIRuntime.Tags("manualMode").Write(false);

// btnManualMode Activated (Phase G rebind cycle-7.2 — currently STRIPPED placeholder)
HMIRuntime.Tags("manualMode").Write(true);
HMIRuntime.Tags("autoMode").Write(false);
HMIRuntime.Tags("palMode").Write(false);
```

Cycle-7.X scope: **3 button handlers retrofit/created**. Implementation cost: ~9 LOC C# Openness builder edits + a few minutes of testing.

**Option 4B: visible "Active Mode" lamp banner**
- 3-state visual: "ABCDE" / "Palletizing" / "Manual" / "None" derived from `(bo_Mode_abcde, bo_Mode_pal, bo_Mode_manual)`
- Read-only — operator manually resolves conflicts
- More work for operator; Option 4A is preferred

Without one of these, operator may try to enable Palletizing while ABCDE is still on → PLC silently blocks `bo_Start` (3-way mutex) and operator sees no feedback. Frustrating UX.

### Current state of HMI mode buttons (cycle-7.0 baseline)

| Button | Screen | Exists? | Auto-clears others? |
|---|---|---|---|
| `btnAutoMode` (ABCDE) | `02_Auto_Ubp` | ✅ | ❌ — single-write to `GDB_MachineCmd.bo_Mode` only |
| `btnManualMode` (if any) | `02_Manual_Ubp` | 🅿️ STRIPPED (Phase G blocked) | N/A |
| `swPalletMode` | `02_Pallet_Ubp` (new in this proposal) | ❌ doesn't exist | N/A |

→ Cycle-7.X delivers: (a) new `02_Pallet_Ubp` screen, (b) `swPalletMode` with Option 4A handler, (c) **retrofit `btnAutoMode` with the 2 new mutex-clear writes**. Manual button gets the same pattern when cycle-7.2 Phase G rebind lands.

---

## 5. HMI tag table additions

If HMI agent uses direct PLC bindings (PlcTag attribute = full path), no new HMI tags needed.

If HMI agent prefers bootstrapped HMI tag names (per Cycle-7.0 convention — see `Builders/Ubp/AbcdePhase1Tags.cs` `EnsureHmiTags()`), add 13 entries:

| HMI tag name | Datatype | Direction | PLC path |
|---|---|---|---|
| `palMode` | Bool | W | `GDB_PalletizingCmd.bo_Mode` |
| `palInitPallet` | Bool | W | `GDB_PalletizingCmd.bo_InitPallet` |
| `palStart` | Bool | W | `GDB_PalletizingCmd.bo_Start` |
| `palStop` | Bool | W | `GDB_PalletizingCmd.bo_Stop` |
| `palESTOP_LOCK` | Bool | R | `GDB_PalletizingCmd.bo_ESTOP_LOCK` |
| `palInitialed` | Bool | R | `GDB_PalletizingCmd.bo_PalletInitialed` |
| `palAlarm` | Bool | R | `GDB_PalletizingCmd.bo_Alarm` |
| `palStep` | Int | R | `GDB_PalletizingCmd.i16_PalletStep` |
| `palTotalBoxes` | Int | R | `GDB_PalletizingCmd.i16_TotalBoxes` |
| `palTargetX` | LReal | R | `instFB_AutoCtrl_Palletizing.statTargetPos.x` |
| `palTargetY` | LReal | R | `instFB_AutoCtrl_Palletizing.statTargetPos.y` |
| `palTargetZ` | LReal | R | `instFB_AutoCtrl_Palletizing.statTargetPos.z` |
| `palTargetA` | LReal | R | `instFB_AutoCtrl_Palletizing.statTargetPos.a` |

iDB access for `instFB_AutoCtrl_Palletizing.statTargetPos.*` requires the iDB to have "Accessible from HMI" flag. Per Cycle-7.0 precedent (`instFB_AutoCtrl_ABCDE` already exposes `statTargetPos`), this should compile-resolve automatically. If TIA Compile flags it, operator toggles iDB Properties → Attributes → "Accessible from HMI" ON.

---

## 6. Operator runbook (HMI palletizing usage, post-cycle-7.X delivery)

1. Power up PLC + HMI runtime
2. Open `02_Auto_Ubp` → press `btnAutoMode` to ensure ABCDE mode is OFF (or pressing `swPalletMode` ON does this auto-resolution per §4A)
3. Open `02_Pallet_Ubp` → press `swPalletMode` ON (palletizing active)
4. Press `btnPalletInitPath` ONCE (path table populated; `lampPalletInitialed` lights up)
5. Press `btnPalletStart` → cycle begins; `i16_PalletStep` IOField counts 1..48 then wraps
6. cardProgress shows live X/Y/Z/A targets cycling through 16 boxes × 4 layers
7. SCARA visibly traces 4-layer stack in NX MCD viewport (assuming PC bindings + L1 geometry are correct per C69 §10)
8. Press `btnPalletStop` to halt (`i16_PalletStep` → 0)

For operator simulator runs (no NX MCD), the smoke `harness/SmokeTest_Phase2_Palletizing.ps1` automates this sequence.

---

## 7. Open questions for scara-HMI agent

1. **Option A vs B (§2)?** Dedicated `02_Pallet_Ubp` screen + 6th nav tab (recommended) OR mode-selector on existing `02_Auto_Ubp`? Trade-off: A = more screens, less JS; B = less screens, more JS routing.
2. **2D pallet view (§3)?** Worth the extra ~16 rectangles for visual stacking feedback, or skip for first version?
3. **Mutex auto-resolution (§4)?** Option 4A (HMI JS auto-disables other modes on toggle) or 4B (visible Active Mode lamp + manual operator resolution)?
4. **Manual cycle-7.2 deps?** Palletizing rebind (this proposal) is independent of Manual cycle-7.2 rebind — can they land in the same HMI cycle or separate cycles? PLC side is fully ready for both.
5. **Tag-table naming convention?** `pal*` prefix per §5, or HMI agent prefers different convention (e.g., `palletStart` instead of `palStart`)?

---

## 8. Closure markers

- [INFORMATIONAL → scara-HMI] palletizing PLC surface ready since C69 12/12 PASS
- [NEEDS_HMI_DESIGN] scara-HMI picks Option A or B + responds to §7 questions in next cycle handoff
- [BLOCKS-ON] none — PLC side is independent; HMI work can start any time
- [INFO] PLC's ABCDE + Palletizing share `instMoveLinAbs` on `ScaraArm3D` via different iDBs; 3-way mode mutex enforces single-active-cycle invariant
- [INFO] Palletizing Z range = 300..550 mm (commanded TCP_z); SCARA reach validated post-L1=1028.48 correction (see C69 §10)
- [INFO] V3 recipe-driven palletizing is a future Phase 2.3 — `i16_TotalBoxes` may become non-constant; HMI should not assume 16

---

## 9. Operator alternative (current workaround until HMI ships)

Until the HMI palletizing screen lands, operator drives palletizing via:

**Option I — TIA Watch Table:**
1. TIA → Project tree → PLC_1 → Watch and force tables → add rows for `GDB_PalletizingCmd.bo_Mode/bo_InitPallet/bo_Start/bo_Stop` + status fields
2. Set `GDB_MachineCmd.bo_Mode := FALSE` + `GDB_ManualCmd.bo_Mode := FALSE` (clear other modes)
3. Set `GDB_PalletizingCmd.bo_Mode := TRUE`
4. Pulse `GDB_PalletizingCmd.bo_InitPallet` TRUE → FALSE
5. Pulse `GDB_PalletizingCmd.bo_Start` TRUE → FALSE
6. Observe `i16_PalletStep` cycling 1..48

**Option II — PowerShell smoke:**
- `& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_Phase2_Palletizing.ps1"` does the full end-to-end automation including bring-up, InitPallet, Start, 120s observation, Stop. 12/12 gates verified.

---

## Cross-references

- `PLC_HANDOFF_2026-05-18_C69_Phase2_PalletizingBackport.md` (§1-§10) — palletizing PLC implementation + L1 geometry correction follow-up
- `PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md` — manual control surface, STAGED_FOR_PHASE_2; shares the 3-way mutex contract documented in §4
- `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` — Phase C V6 verification of ABCDE HMI (cardProgress + statTargetPos pattern that this proposal clones)
- `HMI_BINDING_MAP.md` §5 — UBP family canonical conventions (UbpC color palette, BackColor Range dyn, JS PULSE 250ms)
- `harness/SmokeTest_Phase2_Palletizing.ps1` — operator-runnable cycle trigger pending HMI delivery
- HMI agent's `Builders/Ubp/UbpAutoBuilder.cs` — model to clone for the new `UbpPalletBuilder.cs`
