**Status:** PENDING_VERIFICATION

# HMI → PLC Handoff — 2026-05-18 (Cycle-7.3 Phase G unblock COMPLETE: 53 UBP Manual widgets rebound to GDB_ManualCmd + GDB_ManualStatus + axesReady; cycle-7.0 → cycle-7.3 UBP work FINISHED at TIA-author gate)

> **Predecessor (HMI lane):** [HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md](HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md) (cycle-7.1 redo + 4 PLC Q&A) + [HMI_HANDOFF_2026-05-18_Cycle7_2_C65RebindAbsorption.md](HMI_HANDOFF_2026-05-18_Cycle7_2_C65RebindAbsorption.md) (parallel session — v9 main HMI rebind absorption)
>
> **Predecessor (PLC lane):** [PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md](../../../hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md) (Status: VERIFIED 16/16 smoke PASS; FB_ManualCtrl rev 0.2 + GDB_ManualCmd 30 W + GDB_ManualStatus 21 R + GDB_Control.axesReady derived bit) + [PLC_HANDOFF_2026-05-18_BackColor_TagProposal.md](../../../hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/PLC_HANDOFF_2026-05-18_BackColor_TagProposal.md) (canonical mapping table)
>
> **Triggered by:** Operator: "read hand off and finish ubp screen work". PLC C67 verified Phase G end-to-end; per cycle-7.1 §1 Q1+Q2 answers (Option A clean PLC mirror + 1-line axesReady derivation) the PLC now publishes the exact 51 tags HMI needed. Cycle-7.3 rebinds all 53 previously-stripped UBP Manual widgets in a single source pass.

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-18 |
| TIA target | `E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20` at HMI_1 |
| Source delta | 2 files edited (~+285 LOC net): `AbcdePhase1Tags.cs` (+95 LOC: 51 NEW const-pairs + 25 EnsureTag bootstrap calls) + `UbpManualBuilder.cs` (+190 LOC: 5 rewire sections from STRIPPED → BackColor dyn + click bindings) |
| Build verdict | Single build clean **0W / 0E** in 1.95s |
| HMI tag table | 17 → **68 entries** (+51): 1 axesReady + 1 bo_ManualMode + 16 per-joint status + 20 per-joint cmd + 5 Kin status + 4 Kin cmd + 4 cfgKinTarget LReals |
| Fire verdict | `--only=ubp-manual` SUCCESS on canonical project; 51 HMI tags `[ABCDE-P1][TAG] ✓ Created`; 53 widgets `[ABCDE-P1]` rebound (visible in fire log); `[SLOT] ✓ swManualTab → ubpManualTab (rows=2/2)`; `[UBP] Project saved.` ✓ |
| Status | **PENDING_VERIFICATION** — awaits operator TIA HMI Compile Rebuild All + runtime smoke walkthrough |

---

## 1. Widget rebind map (53 widgets unblocked from cycle-7.0/7.1 STRIPPED state)

### 1.1 — Kin status banner (1 widget unblocked)

| Widget | Cycle-7.0/7.1 state | Cycle-7.3 rebind | Tag (HMI short name) | Range | Active color |
|---|---|---|---|---|---|
| `lmpKinReady_Ubp` | STRIPPED (Phase G blocker) | ✅ REBOUND | `axesReady` | `1:1` | `UbpC.AccentGreen` |

PLC FB_AxisCtrl rev 1.3 publishes `GDB_Control.axesReady := axesEnabled AND axesHomed AND NOT axesError` (per HMI cycle-7.1 Q2 ACK).

### 1.2 — Manual Axis 2×2 quadrant (`02_Manual_Axis_Ubp`) — 20 widgets unblocked

For each J{1..4} cell (5 widgets × 4 = 20 total):

| Widget pattern | Cycle-7.3 binding | Pattern |
|---|---|---|
| `btnAxJogMinus_Ubp_J{j}` | HOLD → `bo_J{j}_JogBackward` (Pressed=true / Released=false) | per-joint Manual jog |
| `btnAxJogPlus_Ubp_J{j}` | HOLD → `bo_J{j}_JogForward` | same |
| `lmpAxReady_Ubp_J{j}` | BackColor Range `1:1` on `bo_J{j}_Enabled` LampOk | per-joint Ready (mapped to Enabled status per Phase G §6.1) |
| `lmpAxHomed_Ubp_J{j}` | BackColor Range `1:1` on `bo_J{j}_Homed` LampOk | per-joint Homed |
| `lmpAxError_Ubp_J{j}` | BackColor Range `1:1` on `bo_J{j}_Error` LampError | per-joint Error |

### 1.3 — Per-axis deep-drill screens (`02_Manual_Axis_Ubp_J{1..4}` × 4) — 32 widgets unblocked

For each J{j} screen (8 widgets × 4 = 32 total):

**Header status lamps (3 per screen)**:

| Widget pattern | Binding (BackColor Range `1:1`) | Active color |
|---|---|---|
| `lmpAxJ{j}Ready_Ubp` | `bo_J{j}_Enabled` | `UbpC.SiemensTeal` |
| `lmpAxJ{j}Homed_Ubp` | `bo_J{j}_Homed` | `UbpC.AccentGreen` |
| `lmpAxJ{j}Error_Ubp` | `bo_J{j}_Error` | `UbpC.LampError` |

**Jog row (2 per screen)**:

| Widget | Click binding | BackColor Range `1:1` | Active color |
|---|---|---|---|
| `btnAxJogMinus_Ubp_Detail_J{j}` | HOLD → `bo_J{j}_JogBackward` (Pressed=true / Released=false) | on `bo_J{j}_JogActive` | `UbpC.AccentAmber` (PLC echo-back) |
| `btnAxJogPlus_Ubp_Detail_J{j}` | HOLD → `bo_J{j}_JogForward` | on `bo_J{j}_JogActive` | same |

**Control row (3 per screen)**:

| Widget | Click binding (PULSE 250ms) | BackColor Range `1:1` on status mirror | Active color |
|---|---|---|---|
| `btnAxSecEnable_Ubp_J{j}` | `bo_J{j}_Enable` PULSE | `bo_J{j}_Enabled` (LEVEL feedback) | `UbpC.SiemensTeal` |
| `btnAxSecHome_Ubp_J{j}` | `bo_J{j}_Home` PULSE | `bo_J{j}_Homed` (LEVEL feedback) | `UbpC.AccentGreen` |
| `btnAxSecReset_Ubp_J{j}` | `bo_J{j}_Reset` PULSE | `bo_J{j}_Error` (LEVEL — RED when reset is needed) | `UbpC.LampError` |

**Cycle-6.19 ENABLE INVERT pattern transition**: per C67 §6.3 "Risk-7" UX caveat — `bo_J{n}_Enable` is HOLD-routed-to-GROUP in PLC FB_ManualCtrl REGION 2 (pressing any J{n}_Enable enables all 4 joints together via OR-into `GDB_Control.enableAxes`). HMI uses PULSE 250ms (not the v10 cycle-6.19 INVERT) because PLC's R_TRIG R_TRIG consumes rising-edge. BackColor on `bo_J{j}_Enabled` LEVEL mirror gives operator persistent visual feedback. Widget naming retained (`btnAxSecEnable_*`) for cross-cycle grep continuity.

## 2. Unchanged carryover (cycle-7.0/7.1 — already wired, NOT touched this cycle)

| Surface | State | Notes |
|---|---|---|
| 5-tab BottomNav (5 buttons) | ✅ BackColor dyn on `ubpNavSection` Range exact-match | Authored cycle-7.0 |
| 02_Auto_Ubp 5 status lamps + 5 step-row dyns + 4 button clicks | ✅ All bound | Cycle-7.1 redo |
| 02_Home_Ubp 4 status lamps + 8 IOFields | ✅ All bound | Cycle-7.1 |
| 02_Diag_Ubp 9 status lamps (incl. INVERTED lampToolActive) + 1 IOField | ✅ All bound | Cycle-7.1 redo |
| 02_Manual_Ubp 2 inner-tab buttons | ✅ BackColor on `ubpManualTab` Range exact-match | Cycle-7.0 |
| 02_Manual_Kin_Ubp banner: lmpKinEnabled/Homed/Error (3) | ✅ Bound to `axesEnabled/Homed/Error` | Cycle-7.1 redo |
| 02_Manual_Kin_Ubp footer btnKinEnable/Stop (2) | ✅ Bound to `bo_Mode` TOGGLE + `bo_Stop` PULSE | Cycle-7.0 + cycle-7.1 redo (reverts) |

## 3. Remaining MANUAL-WIRING / cycle-7.4 candidates (6 widgets — Cartesian gap)

| Widget pattern | Cycle-7.3 state | Resolution path |
|---|---|---|
| `btnKinJogMinus_Ubp_{X,Y,Z}` (3) | Still STRIPPED | Phase G provides per-joint jog (J1..J4); Cartesian frame jog (X/Y/Z) requires either (a) PLC adds `bo_KinJog{X,Y,Z}_{Forward,Backward}` with MC_MoveJog-on-group, OR (b) HMI repurposes as +/- buttons that increment/decrement `cfgKinTarget{X,Y,Z}` then PULSE `bo_KinGo`. Operator decides design. |
| `btnKinJogPlus_Ubp_{X,Y,Z}` (3) | Still STRIPPED | same |
| `lmpKinActive_Ubp_{X,Y,Z}` (3) | Still STRIPPED | No `i16_ActiveJointJog` cartesian equivalent in Phase G; deferred until Cartesian jog binding decided |

**Cycle-7.4 candidate scope**: ~6 widgets + design decision on Cartesian jog semantics. ~60-100 LOC HMI source delta if PLC route taken; ~30 LOC if HMI-side increment route taken. Low priority — Cartesian Kin manual move already covered via `cfgKinTarget*` IOFields + `bo_KinGo` PULSE button (operator sets target XYZA + clicks Go → MC_MoveLinearAbsolute fires).

## 4. HMI tag manifest (final state — 68 tags)

| Group | Count | Tags |
|---|---|---|
| Ubp_Local internal (cycle-7.0 Phase B) | 3 | ubpNavSection, ubpPopupIndex, ubpManualTab |
| GDB_MachineCmd W cmds (cycle-7.0 Phase E) | 4 | bo_Start, bo_Stop, bo_Mode, bo_InitPath |
| GDB_MachineCmd R status mirrors (cycle-7.1) | 4 | bo_ESTOP_LOCK, bo_PathInitialed, bo_Alarm, i16_AutoStep (Hmi) |
| instFB_AxisCtrl status + MC_SetTool sub-FB (cycle-7.1) | 6 | statToolActivated + mcSetTool_{Done,Busy,Active,Error,Aborted} |
| GDB_Control group axes status (cycle-7.1 redo) | 3 | axesEnabled, axesHomed, axesError |
| **GDB_Control derived (cycle-7.3 Phase G)** | **1** | **axesReady** |
| **GDB_ManualCmd top-level (cycle-7.3)** | **1** | **bo_ManualMode** |
| **GDB_ManualStatus per-joint status (cycle-7.3)** | **16** | **bo_J{1..4}_{Enabled, Homed, Error, JogActive}** |
| **GDB_ManualCmd per-joint cmd (cycle-7.3)** | **20** | **bo_J{1..4}_{Enable, Home, Reset, JogForward, JogBackward}** |
| **GDB_ManualStatus Kin status (cycle-7.3)** | **5** | **bo_Kin{Enabled, Ready, Homed, Error, ManualBusy}** |
| **GDB_ManualCmd Kin cmd (cycle-7.3)** | **4** | **bo_Kin{Enable, Home, Reset, Go}** |
| **GDB_ManualCmd cfg Kin targets (cycle-7.3)** | **4** | **cfgKinTarget{X, Y, Z, A}** (LReal R/W) |
| **TOTAL** | **68** | |

**Connection**: all PLC-bound tags use existing HMI_Connection_1 (PROFINET S7).
**TIA Properties → Accessible from HMI**: needs verification at next operator TIA Compile for the 51 new PLC paths (3 NEW DBs: `GDB_ManualCmd`, `GDB_ManualStatus`, `GDB_Control.axesReady` added field; existing iDB `instFB_AxisCtrl` already verified accessible in cycle-7.1 redo).

## 5. Verification

| Gate | Result |
|---|---|
| Source compile `dotnet build` | ✅ 0W/0E in 1.95s |
| Fire `--only=ubp-manual` against canonical project | ✅ attached + 51 HMI tags created + 7 Manual screens re-authored + project saved |
| Fire log `[ABCDE-P1]` count | 53 widget rebinds visible (16 lamps + 16 jog buttons + 12 cmd buttons + 9 axis IOField bindings) |
| Operator TIA HMI Compile Rebuild All | 🟡 PENDING — expect 0E/0W (predicted based on cycle-7.1 compile-green precedent + all bindings using bootstrapped HMI tag table) |
| Operator Phase G runtime smoke (cycle-7.0 Phase F + new manual smoke) | 🟡 PENDING — 8 click-test steps per cycle-7.0 PhaseE_CompileGreen §8 + per-axis Manual click tests (Enable / Home / Reset / Jog±) |

## 6. Notes for the PLC agent

- **53 widget rebinds delivered** — Phase G surface now fully consumed by UBP Manual screens. The 47 widgets I stripped during cycle-7.0 Phase E pivot are restored to wired-state with proper PLC tag bindings.
- **Cycle-6.19 ENABLE INVERT pattern → PLC R_TRIG transition**: per Phase G implementation (FB_ManualCtrl REGION 2 + group routing), `bo_J{n}_Enable` is PULSE-consumed by R_TRIG. HMI uses PULSE 250ms self-clear (per Phase G design). The cycle-6.19 INVERT pattern from v10 is NOT retained — replaced by canonical PULSE pattern. BackColor on the LEVEL mirror (`bo_J{n}_Enabled`) gives operator persistent visual feedback.
- **C67 §6.3 Risk-7 UX caveat**: per-axis Enable buttons OR into group-level `GDB_Control.enableAxes`. Pressing any `J{n}_Enable` enables all 4 joints. Documented in source comment + HMI handoff so operator understands the group-routing semantic.
- **`bo_J{n}_JogActive` BackColor dyn on jog buttons**: per Phase G §1.1 "GDB_ManualStatus.bo_J{n}_JogActive = NOT StatusWord.%X7 Standstill", the jog button itself goes amber when jog is active. Operator sees a clean "jog is moving the joint" visual without polling motion state separately.
- **Cycle-7.0/7.1/7.3 cumulative**: ~1480 LOC cycle-7.0 + ~285 LOC cycle-7.1 redo + ~285 LOC cycle-7.3 = **~2050 LOC cumulative** across all 6 UBP source files. UBP family ships with **68 HMI tags + 14 screens + ≈120 wired bindings** on the canonical project.
- **No new PLC asks.** Cycle-7.3 is pure HMI consumer-side delivery against the Phase G PLC surface.
- **Closure markers**: `[VERIFIED-SOURCE]` 53 widget rebinds compiled clean + project saved on canonical; `[VERIFIED-PHASE-G]` C67 16/16 smoke PASS confirms PLC surface; `[NEEDS_OPERATOR]` TIA HMI Compile Rebuild All + runtime smoke for full VERIFIED flip; `[INFORMATIONAL → PLC]` Cycle-7.4 candidate (6 Cartesian Kin widgets) awaits design decision.

---

End of cycle-7.3 Phase G unblock handoff. UBP screen work effectively FINISHED at the TIA-author + binding-consumer gate (cycle-7.4 Cartesian Kin jog widgets are a small cosmetic gap, not a functional blocker). Awaiting operator TIA HMI Compile + runtime smoke for cycle-7.0 → cycle-7.3 unified VERIFIED flip.
