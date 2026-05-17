**Status:** INFORMATIONAL → HMI agent. Design proposal for cycle-7.2 manual-mode rebind unblock. NO PLC code authored in this cycle — implementation triggers a separate "ABCDE Phase G" plan after HMI agent ACK.

# PLC_HANDOFF — C66 HMI Manual-Mode Tag Proposal (cycle-7.2 unblock)

**Project:** `hmiDemoSCARA_ABCDE`
**Cycle:** C66 (this cycle's Phase C.E sub-task)
**Predecessors:**
- HMI agent Cycle-7.0 (14 UBP screens, TIA Compile 0E/0W — see `HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md` in v9 comm tree)
- Phase C.0 GDB_MCDData explicit J{n} mirror landed earlier this cycle
**Trigger:** Operator directive 2026-05-17 22:00 — "how you expose all tags hmi need to control the motion and switch mode? confirm with hmi agent, if not expose more tags to hmi by handoff report"
**Date:** 2026-05-17

---

## 1. Current PLC tag exposure (Phase 1 + Phase 2 today)

### Auto-mode control (FULLY exposed; cycle-7.0 HMI is consuming these)

| Tag | Type | Direction | Purpose |
|---|---|---|---|
| `GDB_MachineCmd.bo_Start` | Bool | W PULSE | Fire ABCDE cycle (R_TRIG in FB_AutoCtrl_ABCDE consumes rising edge) |
| `GDB_MachineCmd.bo_Stop` | Bool | W PULSE | Halt cycle (step → 0) |
| `GDB_MachineCmd.bo_InitPath` | Bool | W PULSE | Initialize pts[1..5] (ABCDE coords) |
| `GDB_MachineCmd.bo_Mode` | Bool | W LEVEL | Auto-mode enable (permissive for Start). Mutex with `GDB_PalletizingCmd.bo_Mode` (separate v9 palletizing cycle). |
| `GDB_MachineCmd.bo_ESTOP_LOCK` | Bool | R LEVEL | Safety chain mirror (FALSE blocks Start) |
| `GDB_MachineCmd.bo_PathInitialed` | Bool | R LEVEL | Status lamp (TRUE after bo_InitPath fired) |
| `GDB_MachineCmd.bo_Alarm` | Bool | R LEVEL | System alarm placeholder (always FALSE in V1) |
| `GDB_MachineCmd.i16_AutoStep` | Int | R LEVEL | Current step (0=idle / 10/20/30/40/50=going-to-A/B/C/D/E) |
| `instFB_AutoCtrl_ABCDE.statTargetPos.{x,y,z,a}` | LReal × 4 | R LEVEL | Currently-commanded TCP target (HMI cardProgress IOFields) |
| `instFB_AutoCtrl_ABCDE.statProgress` | LReal | R LEVEL | V8 blending progress 0..1 (diagnostic) |
| `J{1..4}_SCARA_Arm3D.ActualPosition` | LReal × 4 | R LEVEL | Per-joint actual position (HMI per-axis screens — TO_Axis direct binding) |
| `J{1..4}_SCARA_Arm3D.ActualVelocity` | LReal × 4 | R LEVEL | Per-joint actual velocity (HMI per-axis Velocity row — TO_Axis direct) |

### Phase C.0 explicit-named TO_Axis mirror (NEW this cycle, DIAGNOSTIC ONLY)

| Tag | Purpose |
|---|---|
| `GDB_MCDData.J{1..4}_ActualPosition` | Direct mirror for PLCSIM-Adv API monitoring (TO_Axis not exposed via API) |
| `GDB_MCDData.J{1..4}_ActualVelocity` | Same |

**Not** for HMI binding — HMI keeps reading TO_Axis direct via S7 driver. These exist for cross-check + future tooling parity.

### Manual-mode + per-axis-cmd surface (MINIMAL today)

What exists:
- `GDB_MachineCmd.bo_Mode` doubles as a manual-mode enable proxy in HMI's UBP design (Kin footer ENABLE TOGGLE rebinds to it)
- `GDB_Control.{enableAxes, axesEnabled, homeAxes, axesHomed, resetAxes}` — group enable/home/reset (4 joints + kin TO all together)
- `GDB_Control.StartMode[1..6]`, `StopMode[1..6]`, `HomePos[1..6]`, `HomeMode[1..6]` — config arrays (rarely changed at runtime)

What's **missing** for manual-mode rebinds:
- Per-joint Enable / Home / Reset (group-level only today)
- Per-joint JOG Forward / JOG Backward
- Per-joint status mirror (ready / homed / error)
- Kin status mirror (enabled / ready / homed / error)
- Kin target (`cfgTargetX/Y/Z` R/W)
- Kin jog axis selector
- Kin jog Forward / Backward

---

## 2. Gap inventory — HMI agent's STRIPPED tags (per cycle-7.0 work)

Per `HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileFixAbcdePivot.md` §2, HMI agent pivoted UBP screens from v10 LKinCtrl namespace → Phase 1 ABCDE bindings. The following bindings were **STRIPPED** (widgets render as visual placeholders pending PLC-side equivalent):

### Manual-mode Kin screen (`02_Manual_Kin_Ubp`)

| Stripped binding | UBP widget | Phase 1 status |
|---|---|---|
| `mc_kin_cfgJogAxis` | active-axis selector (X/Y/Z dropdown) | STRIPPED |
| `mc_kin_cmdJogForward / Backward` | JOG+ / JOG- buttons | STRIPPED |
| `mc_kin_statusEnabled / Ready / Homed / Error` | 4 status banner lamps | STRIPPED (render static idle) |
| `mc_kin_cfgTargetX/Y/Z` R/W | 3 IOFields for axis-row targets | **PARTIAL**: rebound to `statTargetPos.{x,y,z}` ReadOnly (no operator-write yet) |

### Per-axis deep-drill screens (`02_Manual_Axis_Ubp_J{1..4}`)

| Stripped binding | UBP widget | Phase 1 status |
|---|---|---|
| `mc_axis_J{n}_cmd_Enable` | ENABLE button (per joint × 4) | STRIPPED |
| `mc_axis_J{n}_cmd_Home` | HOME button (per joint × 4) | STRIPPED |
| `mc_axis_J{n}_cmd_Reset` | RESET button (per joint × 4) | STRIPPED |
| `mc_axis_J{n}_cmd_JogForward / Backward` | JOG±  buttons (per joint × 4 × 2) | STRIPPED |
| `mc_axis_J{n}_status_ready / homed / error` | mini-lamps (per joint × 4 × 3) | STRIPPED (render static idle) |
| `mc_axis_J{n}_status_ActualPosition` | per-axis Position card | **REBOUND**: `J{n}_SCARA_Arm3D.ActualPosition` (TO_Axis direct — works) |
| `mc_axis_J{n}_status_ActualVel` | per-axis Velocity row | **REBOUND**: `J{n}_SCARA_Arm3D.ActualVelocity` (TO_Axis direct — defensive binding, accepted by TIA Compile) |

### Counts
- **20 cmd buttons** stripped (4 joints × {Enable, Home, Reset, JogFwd, JogBack}; 5 buttons × 4 = 20)
- **12 status lamps** stripped (4 joints × {ready, homed, error} = 12)
- **4 Kin status lamps** stripped
- **3 Kin axis JOG rows** stripped (X/Y/Z axis active-selector + JOG±)
- **3 Kin cfgTargetX/Y/Z** rebound R-only (need R/W for operator-set)

Total HMI rebind work pending cycle-7.2: rebind ~42 widgets (20 cmd buttons + 12 axis lamps + 4 kin lamps + 6 Kin jog widgets) once PLC delivers the new tag surface.

---

## 3. Proposed PLC tag surface for cycle-7.2 unblock

### 3.1 — New global DB `GDB_ManualCmd` (operator-write surface)

```scl
// 500_AutoCtrl/GDB_ManualCmd.xml
DATA_BLOCK "GDB_ManualCmd"
{ S7_Optimized_Access := 'TRUE' }
VERSION : 1.0
VAR
    // === Mode arbitration ===
    bo_Mode : Bool;                         // Manual-mode enable; mutex with GDB_MachineCmd.bo_Mode + GDB_PalletizingCmd.bo_Mode
    bo_ESTOP_LOCK : Bool := TRUE;           // Safety chain mirror (FALSE blocks manual cmds)

    // === Kin jog (3-axis frame jog) ===
    i16_ActiveJointJog : Int;               // 1=X, 2=Y, 3=Z (which kin-axis the operator is jogging)
    bo_KinJogForward : Bool;                // HOLD: TRUE while operator holds JOG+; FALSE on release
    bo_KinJogBackward : Bool;               // HOLD: TRUE while operator holds JOG-
    lr_KinTargetX : LReal;                  // R/W: operator-set kin target X (mm)
    lr_KinTargetY : LReal;                  // R/W: operator-set kin target Y (mm)
    lr_KinTargetZ : LReal;                  // R/W: operator-set kin target Z (mm)
    bo_KinMoveAbs : Bool;                   // PULSE: fire MC_MoveLinearAbsolute on ScaraArm3D toward lr_KinTarget*

    // === Per-axis cmds (4 axes × 5 cmds = 20 Bools) ===
    bo_J1_Enable : Bool;                    // HOLD: hold to enable J1
    bo_J1_Home : Bool;                      // PULSE
    bo_J1_Reset : Bool;                     // PULSE
    bo_J1_JogForward : Bool;                // HOLD
    bo_J1_JogBackward : Bool;               // HOLD
    bo_J2_Enable : Bool;
    bo_J2_Home : Bool;
    bo_J2_Reset : Bool;
    bo_J2_JogForward : Bool;
    bo_J2_JogBackward : Bool;
    bo_J3_Enable : Bool;
    bo_J3_Home : Bool;
    bo_J3_Reset : Bool;
    bo_J3_JogForward : Bool;
    bo_J3_JogBackward : Bool;
    bo_J4_Enable : Bool;
    bo_J4_Home : Bool;
    bo_J4_Reset : Bool;
    bo_J4_JogForward : Bool;
    bo_J4_JogBackward : Bool;

    // === Jog velocity / acceleration overrides ===
    lr_JogVelocity : LReal := 100.0;        // mm/s or deg/s depending on axis
    lr_JogAcceleration : LReal := 1000.0;
END_VAR
```

### 3.2 — New global DB `GDB_ManualStatus` (read-back surface) — OR extend `GDB_Control`

**OPTION A: New dedicated DB**
```scl
DATA_BLOCK "GDB_ManualStatus"
{ S7_Optimized_Access := 'TRUE' }
VAR
    // === Per-axis status mirror (4 × 3 = 12 Bools, extracted from J{n}_SCARA_Arm3D.StatusWord bits) ===
    bo_J1_Enabled : Bool;   bo_J1_Homed : Bool;   bo_J1_Error : Bool;
    bo_J2_Enabled : Bool;   bo_J2_Homed : Bool;   bo_J2_Error : Bool;
    bo_J3_Enabled : Bool;   bo_J3_Homed : Bool;   bo_J3_Error : Bool;
    bo_J4_Enabled : Bool;   bo_J4_Homed : Bool;   bo_J4_Error : Bool;

    // === Kin status mirror (4 Bools, from ScaraArm3D.StatusWord bits) ===
    bo_KinEnabled : Bool;   bo_KinReady : Bool;   bo_KinHomed : Bool;   bo_KinError : Bool;

    // === Kin TCP feedback (for operator visibility during jog) ===
    lr_KinTcpX : LReal;     lr_KinTcpY : LReal;     lr_KinTcpZ : LReal;     lr_KinTcpA : LReal;
END_VAR
```

**OPTION B: HMI-side bit-mask of `J{n}.StatusWord` directly via S7 driver** — saves all of `GDB_ManualStatus` + half the FB_ManualCtrl scanwork. HMI agent's call on whether bit-level manipulation in JS is acceptable.

**Open question for HMI agent → response in next HMI handoff**: Which approach? Default recommendation: Option A (clean PLC mirror; matches HMI's existing pattern of binding to typed DB members).

### 3.3 — New FB `FB_ManualCtrl.scl` (on OB124 10ms cyclic for jog responsiveness)

```scl
FUNCTION_BLOCK "FB_ManualCtrl"
{ S7_Optimized_Access := 'TRUE' }
VERSION : 1.0
VAR
    // Per-joint jog (4× MC_MoveJog)
    instJog_J1 { InstructionName := 'MC_MOVEJOG'; LibVersion := '9.0' } : MC_MOVEJOG;
    instJog_J2 { InstructionName := 'MC_MOVEJOG'; LibVersion := '9.0' } : MC_MOVEJOG;
    instJog_J3 { InstructionName := 'MC_MOVEJOG'; LibVersion := '9.0' } : MC_MOVEJOG;
    instJog_J4 { InstructionName := 'MC_MOVEJOG'; LibVersion := '9.0' } : MC_MOVEJOG;
    // Kin manual move
    instMoveAbsKin { InstructionName := 'MC_MOVELINEARABSOLUTE'; LibVersion := '9.0' } : MC_MOVELINEARABSOLUTE;
    // Rising-edge detectors for PULSE cmds (Home, Reset, MoveAbs)
    sRTRIG_J1_Home : R_TRIG;
    sRTRIG_J1_Reset : R_TRIG;
    // ... 4 axes × 2 PULSE cmds = 8 R_TRIGs, plus 1 for KinMoveAbs = 9
    sRTRIG_KinMoveAbs : R_TRIG;
END_VAR
BEGIN
    // Mutex check: only execute if manual-mode active AND auto-modes off
    IF "GDB_ManualCmd".bo_Mode
        AND NOT "GDB_MachineCmd".bo_Mode
        AND NOT "GDB_PalletizingCmd".bo_Mode
        AND "GDB_ManualCmd".bo_ESTOP_LOCK
    THEN
        // Per-joint jog (HOLD pattern)
        #instJog_J1(Axis := "J1_SCARA_Arm3D",
                    JogForward := "GDB_ManualCmd".bo_J1_JogForward,
                    JogBackward := "GDB_ManualCmd".bo_J1_JogBackward,
                    Velocity := "GDB_ManualCmd".lr_JogVelocity,
                    Acceleration := "GDB_ManualCmd".lr_JogAcceleration);
        // (J2/J3/J4 similar)

        // Kin manual move (PULSE)
        #sRTRIG_KinMoveAbs(CLK := "GDB_ManualCmd".bo_KinMoveAbs);
        IF #sRTRIG_KinMoveAbs.Q THEN
            #instMoveAbsKin(AxesGroup := "ScaraArm3D",
                            Execute := TRUE,
                            Position := [#"GDB_ManualCmd".lr_KinTargetX, ...],
                            Velocity := "GDB_ManualCmd".lr_JogVelocity,
                            ...);
        ELSE
            #instMoveAbsKin(AxesGroup := "ScaraArm3D", Execute := FALSE);
        END_IF;

        // Per-joint Enable / Home / Reset via existing FB_AxisCtrl group flags
        // (manual-mode FB sets group-level flags; FB_AxisCtrl actuates)
        // NOTE: FB_AxisCtrl is group-level today. For per-joint cmd, EITHER:
        //   - Refactor FB_AxisCtrl to accept per-joint masks (cleaner)
        //   - OR add per-joint MC_Power / MC_Home / MC_Reset instances directly here (32 extra MC instances — OB91 budget concern)
        //   - OR sequence per-joint cmds time-sliced through GDB_Control flags + FB_AxisCtrl (slowest but simplest)
        // RECOMMENDED: refactor FB_AxisCtrl to expose per-joint enable/home/reset on its iDB interface
        // (would need FB_AxisCtrl rev 1.3 — separate Phase G sub-task)
    END_IF;

    // Status mirror — copy J{n} StatusWord bits to GDB_ManualStatus (per Option A above)
    "GDB_ManualStatus".bo_J1_Enabled := "J1_SCARA_Arm3D".StatusWord.%X2;
    "GDB_ManualStatus".bo_J1_Homed := "J1_SCARA_Arm3D".StatusWord.%X5;
    "GDB_ManualStatus".bo_J1_Error := "J1_SCARA_Arm3D".ErrorWord.%X0;
    // ... J2/J3/J4 same pattern (12 lines)

    // Kin status
    "GDB_ManualStatus".bo_KinEnabled := "ScaraArm3D".StatusWord.%X2;
    "GDB_ManualStatus".bo_KinReady := "ScaraArm3D".StatusWord.%X4;
    "GDB_ManualStatus".bo_KinHomed := "ScaraArm3D".StatusWord.%X5;
    "GDB_ManualStatus".bo_KinError := "ScaraArm3D".ErrorWord.%X0;

    // Kin TCP feedback
    "GDB_ManualStatus".lr_KinTcpX := "ScaraArm3D".Tcp.x;
    "GDB_ManualStatus".lr_KinTcpY := "ScaraArm3D".Tcp.y;
    "GDB_ManualStatus".lr_KinTcpZ := "ScaraArm3D".Tcp.z;
    "GDB_ManualStatus".lr_KinTcpA := "ScaraArm3D".Tcp.a;
END_FUNCTION_BLOCK
```

### 3.4 — Edits to existing files

- `Main [OB1]`: add `"instFB_ManualCtrl"()` call alongside existing `instFB_AxisCtrl` + `instFB_AutoCtrl_ABCDE`
- OR move FB_ManualCtrl to OB124 (cyclic interrupt, 10ms) for jog responsiveness — needs new OB124 + Axis_Call FC restructure
- `Startup [OB100]`: clear `GDB_ManualCmd.bo_Mode := FALSE` defensively + clear all HOLD bits

### 3.5 — Per-scan MC instruction count impact

| Block | Current | + Phase G |
|---|---|---|
| FB_AxisCtrl | 4× MC_Power + 4× MC_Home + 5× MC_Reset + 1× MC_SetTool = 14 | unchanged |
| FB_AutoCtrl_ABCDE | 1× MC_MoveLinearAbsolute | unchanged |
| FB_AutoCtrl_Palletizing (v9 only) | 1× MC_MoveLinearAbsolute | n/a (v9 has this, ABCDE doesn't) |
| **FB_ManualCtrl (NEW)** | — | **4× MC_MoveJog + 1× MC_MoveLinearAbsolute = 5** |
| Total active (ABCDE) | ~5-6 | ~10-11 |
| OB91 budget | <50 (safe) | <50 (safe) |

Still within OB91 headroom — no Phase 1 OB91 overflow risk reintroduced.

---

## 4. Scope of cycle-7.2 PLC work ("ABCDE Phase G")

| Artifact | Lines | Notes |
|---|---|---|
| `500_AutoCtrl/GDB_ManualCmd.xml` | ~50 | NEW (~30 members) |
| `500_AutoCtrl/GDB_ManualStatus.xml` | ~30 | NEW (~17 members) — OR HMI uses Option B (no PLC GDB) |
| `500_AutoCtrl/FB_ManualCtrl.scl` | ~200-250 LOC | NEW (4× MC_MoveJog + 1× MC_MoveLinearAbsolute + status mirror + R_TRIGs + mutex) |
| `Instances/instFB_ManualCtrl.xml` | ~30 | NEW iDB |
| `100_OB/Main.scl` | +5 LOC | add `instFB_ManualCtrl()` call |
| `100_OB/Startup.scl` | +15 LOC | add `Clear_ManualCtrl_command_bits` REGION |
| `harness/SmokeTest_PhaseG_ManualMode.ps1` | ~400-500 LOC | NEW; ~18 gates (per-axis jog + per-axis cmd + Kin move + status mirror + mutex with auto) |
| Backups + handoff doc | n/a | standard |

**Estimated PLC agent time:** ~3-4 hours (FB_ManualCtrl design + author + smoke-test design + verification).
**Operator deploy time:** ~15 min (memory reset + download).
**HMI cycle 7.2 rebind time:** estimated ~2-3 hours per HMI agent (42 widget rebinds + JS event handlers for HOLD vs PULSE patterns).

---

## 5. Recommended cycle sequence (after this proposal ACK)

1. **HMI agent ACKs proposal** in next cycle handoff (~1 day round-trip)
   - Confirms binding ownership (Option A vs B for status lamps)
   - Confirms mode-arbiter scope (binary mutex sufficient OR enum-arbiter needed)
   - Confirms `lr_KinTarget*` need R/W (operator-set) or R-only
   - Confirms HOLD-event pattern is OK on UBP (Press↓ → set TRUE / Release↑ → set FALSE)
2. **PLC agent runs "ABCDE Phase G" cycle** (separate plan, ~half-day):
   - Authors FB_ManualCtrl + 2 new GDBs + Main/Startup edits + smoke test
   - Operator deploys (VCI + memory reset + download)
   - PLC agent runs SmokeTest_PhaseG_ManualMode.ps1 → expect ~16/18 PASS
   - Authors VERIFIED handoff
3. **HMI agent runs cycle-7.1** (~half-day): rebind UBP Kin manual-mode footer
4. **HMI agent runs cycle-7.2** (~half-day): rebind per-axis screens
5. **Operator end-to-end test**: TIA Runtime → click ENABLE on J1 → joint enables; JOG+ hold → joint moves; release → joint stops; Kin Move Abs → SCARA moves to operator-set XYZ target

Total cycle 7.1+7.2 unblock: ~1.5-2 days HMI + ~half-day PLC = ~2 days end-to-end (interleavable).

---

## 6. Open questions for HMI agent (respond in next HMI handoff §6)

1. **Status lamp ownership**: PLC mirror DB (Option A — `GDB_ManualStatus`) vs HMI-side bit-mask of `J{n}.StatusWord` (Option B — no new PLC code)? Recommendation: Option A (cleaner; matches existing pattern).
2. **Mode arbiter scope**: Is binary `bo_Mode` mutex (`GDB_MachineCmd.bo_Mode` XOR `GDB_PalletizingCmd.bo_Mode` XOR `GDB_ManualCmd.bo_Mode`) enough, OR do we need a single `enum_ActiveMode` Int (0=Off / 1=Auto / 2=Palletizing / 3=Manual / 4=Commissioning) with state-transition FB? Phase 1 + Phase 2 currently use mutex; Phase G manual would extend that pattern.
3. **Kin target IOFields R/W**: Should `lr_KinTargetX/Y/Z` be operator-writable (HMI sets target via IOField, then clicks "Move Abs")? Or read-only (target comes from elsewhere)?
4. **Jog button HOLD vs PULSE**: Per HMI agent's UBP design, Kin/per-axis JOG buttons are physical-touch (Press + Release). Confirm HOLD pattern is correct (write TRUE on Press↓ / write FALSE on Release↑). Alternative: PULSE 250ms via JS setTimeout (operator clicks → 250ms move chunk → release inherent; jog requires repeated clicks).
5. **Jog velocity override**: Should `lr_JogVelocity` be HMI-writable (operator slider) or PLC-only (fixed default)?
6. **`bo_J{n}_Enable` semantics**: Should this be HOLD (joint enabled only while button held) OR LATCH (toggle TRUE/FALSE via separate Press events)? Different safety implications.

Please respond with answers in next HMI cycle handoff §6 (or as a dedicated topical handoff). PLC agent will absorb into Phase G plan before authoring.

---

## 7. Closure markers

- `[INFORMATIONAL]` — design proposal; no PLC code changes this cycle
- `[NEEDS_HMI_ACK]` — 6 open questions in §6 above for HMI agent to confirm in next cycle
- `[BLOCKS]` — HMI cycle-7.1 + cycle-7.2 rebinds (until PLC Phase G ships per this proposal)
- `[REOPENABLE]` — if HMI agent's ACK reveals significantly different scope (e.g., wants Commissioning Mode as 5th state), proposal can be revised before Phase G author

---

## Cross-references

- `HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md` (v9 comm tree) — HMI agent's STRIPPED list source
- `HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileFixAbcdePivot.md` (v9 comm tree) — namespace pivot rationale + stripped tag table
- `HMI_BINDING_MAP.md` (this project) — current auto-mode binding map (will gain GDB_ManualCmd / GDB_ManualStatus rows post-Phase-G)
- `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` (this project, sibling handoff for Phase C verification)
- Existing FB pattern reference: `500_AutoCtrl/FB_AxisCtrl.scl` (group-level enable/home/reset) — Phase G FB_ManualCtrl follows same multi-instance MC pattern
- `~/.claude/plans/zazzy-mixing-hammock.md` — Phase C plan + Phase G future-work pointer
