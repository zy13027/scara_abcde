# HMI_BINDING_MAP — hmiDemoSCARA_ABCDE

**Target device:** MTP1000 Unified Basic Panel 10" (6AV2123-3KB32-0AW0, 1280×800)
**5-control-per-screen cap** (Siemens docs; operator empirically confirms during authoring)
**HMI driver:** WinCC Unified Basic (NOT Comfort — no `ToggleTag` system function; use JS PULSE pattern via `HMIRuntime.Tags(...).Write()` + setTimeout 250ms)
**Last updated:** 2026-05-21 (Phase 6 — architectural-refactor binding deltas; see Section 7)
**Plan:** Architectural refactor (`C:\Users\Admin\.claude\plans\dazzling-squishing-sloth.md`)
**Status:** Sections 1-4 below are the **originally-spec'd MTP1000 1280×800 design** (superseded — HMI agent's Cycle-7.0 UBP 1024×600 build is canonical). See Section 5 for the as-built UBP family, Section 6 for the PLC diagnostic mirror tags, and **Section 7 for the 2026-05-21 architectural-refactor binding deltas — the HMI agent's action list.**

---

## 4-screen layout (15 widgets distributed per UBP 5-cap)

### 1. Home_Screen — primary control + step display (5 controls)

| # | Widget name | Type | Binding | R/W | Notes |
|---|---|---|---|---|---|
| 1 | `swModeAuto` | Switch (2-state) | `GDB_MachineCmd.bo_Mode` | W Bool | OFF=manual idle, ON=auto enabled. Default ON (per Startup OB initialization). |
| 2 | `btnInitPath` | Button (PULSE) | `GDB_MachineCmd.bo_InitPath` | W Bool | One-time path-init trigger; JS PULSE 250ms. Operator clicks ONCE after startup to populate `pts[1..5]`. |
| 3 | `btnStart` | Button (PULSE) | `GDB_MachineCmd.bo_Start` | W Bool | JS PULSE pattern: `HMIRuntime.Tags("bo_Start").Write(true); setTimeout(()=>HMIRuntime.Tags("bo_Start").Write(false),250);` |
| 4 | `btnStop` | Button (PULSE) | `GDB_MachineCmd.bo_Stop` | W Bool | Same PULSE pattern as btnStart |
| 5 | `txtAutoStep` | IOField (R Int) | `GDB_MachineCmd.i16_AutoStep` | R Int | Current step number (source spec §4.1). Shows 0/10/20/30/40/50. |

**Navigation buttons** (counted separately if they fit; otherwise add as a 6th control after empirical 5-cap verification): `btnToTarget` → Target_Screen; `btnToActualPos` → Actual_Pos_Screen.

---

### 2. Target_Screen — current commanded target (5 controls — source spec §4.2)

| # | Widget name | Type | Binding | R/W | Notes |
|---|---|---|---|---|---|
| 1 | `txtTargetX` | IOField (R LReal) | `instFB_AutoCtrl_ABCDE.statTargetPos.x` | R LReal | X coordinate in WCS (mm) |
| 2 | `txtTargetY` | IOField (R LReal) | `instFB_AutoCtrl_ABCDE.statTargetPos.y` | R LReal | Y coordinate (mm) |
| 3 | `txtTargetZ` | IOField (R LReal) | `instFB_AutoCtrl_ABCDE.statTargetPos.z` | R LReal | Z coordinate (mm) |
| 4 | `txtTargetA` | IOField (R LReal) | `instFB_AutoCtrl_ABCDE.statTargetPos.a` | R LReal | A wrist rotation (deg) |
| 5 | `btnHome` | Button | `ActivateScreen "Home_Screen"` (system function) | — | Navigate back to Home |

---

### 3. Actual_Pos_Screen — current TCP position (5 controls — source spec §4.3 first half)

| # | Widget name | Type | Binding | R/W | Notes |
|---|---|---|---|---|---|
| 1 | `txtActualX` | IOField (R LReal) | `ScaraArm3D.Position[1]` | R LReal | TCP X (kinematic group exposes 6-DoF; UBP 5-cap forces dropping [5][6]) |
| 2 | `txtActualY` | IOField (R LReal) | `ScaraArm3D.Position[2]` | R LReal | TCP Y |
| 3 | `txtActualZ` | IOField (R LReal) | `ScaraArm3D.Position[3]` | R LReal | TCP Z |
| 4 | `txtActualA` | IOField (R LReal) | `ScaraArm3D.Position[4]` | R LReal | TCP A wrist |
| 5 | `btnToJoints` | Button | `ActivateScreen "Actual_Joints_Screen"` | — | Navigate to joint angles |

---

### 4. Actual_Joints_Screen — per-axis joint angles (5 controls — source spec §4.3 second half)

| # | Widget name | Type | Binding | R/W | Notes |
|---|---|---|---|---|---|
| 1 | `txtJoint1` | IOField (R LReal) | `J1_SCARA_Arm3D.ActualPosition` | R LReal | J1 base shoulder angle (deg) |
| 2 | `txtJoint2` | IOField (R LReal) | `J2_SCARA_Arm3D.ActualPosition` | R LReal | J2 elbow angle (deg) |
| 3 | `txtJoint3` | IOField (R LReal) | `J3_SCARA_Arm3D.ActualPosition` | R LReal | J3 prismatic Z (mm) |
| 4 | `txtJoint4` | IOField (R LReal) | `J4_SCARA_Arm3D.ActualPosition` | R LReal | J4 wrist rotation (deg) |
| 5 | `btnHome` | Button | `ActivateScreen "Home_Screen"` | — | Navigate back to Home |

---

## Widget-count budget

- **Home_Screen**: 5 controls (5/5 — at cap)
- **Target_Screen**: 5 controls (4 IOFields + 1 nav button — at cap)
- **Actual_Pos_Screen**: 5 controls (4 IOFields + 1 nav button — at cap)
- **Actual_Joints_Screen**: 5 controls (4 IOFields + 1 nav button — at cap)
- **Total**: 20 controls (15 functional + 4 nav buttons + 1 home nav from Joints back)

If empirical TIA Portal HMI compile reveals the UBP 5-cap is more permissive than docs, the operator can collapse the 4-screen split toward 1-2 screens.

---

## JS PULSE pattern (for btnStart / btnStop / btnInitPath)

UBP does NOT support `ToggleTag` system function. Use this JavaScript helper on Button.Press event:

```javascript
// btnStart Press event handler
HMIRuntime.Tags("bo_Start").Write(true);
setTimeout(() => HMIRuntime.Tags("bo_Start").Write(false), 250);
```

(Same pattern for `bo_Stop` and `bo_InitPath`. 250ms pulse width is well within 1 PLC scan time for reliable rising-edge detection by the R_TRIG in FB_AutoCtrl_ABCDE.)

---

## Tag-table mapping (PLC tags → HMI internal tags)

HMI tags should be authored under `HMI_1/HMI tags/Default tag table/` with direct PLC tag bindings (PROFINET S7 connection). 15 PLC tags needed (4 read-only LReal for target, 4 R LReal for TCP pos, 4 R LReal for joint angles, 1 R Int for step, 4 W Bool + 1 W Bool for mode = 5 W Bool + 12 R = 17 total ... wait, see breakdown above for actual count).

Per WinCC Unified Basic convention, the HMI tag table maps 1:1 with the PLC DB Member by name; no Cycle parameter needed for direct bindings.

---

## 5. UBP Family — HMI agent's Cycle-7.0 design (CANONICAL post-2026-05-17 21:30)

Per `HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md` (filed in v9 comm tree per AGENT_CONTRACT cross-agent convention), the HMI agent authored **14 UBP screens** on `hmiDemoSCARA_ABCDE.ap20` HMI_1 via C# Openness builder. **TIA HMI Compile: 0E/0W**. This SUPERSEDES the original 4-screen MTP1000 1280×800 spec in Sections 1-4 above (which was never built — kept as historical reference only).

### 5.1 — Target hardware

- **Resolution:** 1024×600 (UBP MTP1000 10")
- **Layout pattern:** TopBar 60px + content 480px + BottomNav 60px = 600px
- **5-tab bottom nav:** Home / Auto / Manual / Diag / Config (Siemens-teal active-highlight via BackColor Range dyn on `ubpNavSection` internal Int tag)

### 5.2 — 14 screens authored

| Folder | Screen | Substance |
|---|---|---|
| `UBP/01_Layout` | `01_Layout_Ubp` | TopBar + swContent (Range-mapped 5-way) + swBottomNav (static embed) |
| `UBP/04_Components` | `BottomNav_Ubp` | 5-tab strip (1024×60) with Siemens-teal active-highlight |
| `UBP/02_Content` | `02_Home_Ubp` | Bilingual title-card placeholder |
| `UBP/02_Content` | `02_Auto_Ubp` | **ABCDE-bound** Auto control: cardProgress (5 IOFields) + cardAutoCtrl (4 buttons) — see Section 5.3 binding table |
| `UBP/02_Content` | `02_Manual_Ubp` | Manual host: Kin/Axis inner-tab strip + swManualTab Range-mapped (420×1024) |
| `UBP/02_Content` | `02_Manual_Kin_Ubp` | Kin: 4 status lamp placeholders + 3 axis rows X/Y/Z (Display label + ReadOnly IO bound to statTargetPos.{x,y,z}) + JOG±/active-axis placeholders + ENABLE TOGGLE→bo_Mode / STOP PULSE→bo_Stop |
| `UBP/02_Content` | `02_Manual_Axis_Ubp` | 2×2 J{1..4} quadrant grid (512×210 cells; each: Display label + ReadOnly IO bound to `J{j}_SCARA_Arm3D.ActualPosition` + JOG±/status widget placeholders) |
| `UBP/02_Content` | `02_Manual_Axis_Ubp_J1` | Per-axis deep-drill J1: 72px header + 112px position card (`J1.ActualPosition` + `J1.ActualVelocity`) + JOG/ENABLE/HOME/RESET placeholders + deadman hint footer |
| `UBP/02_Content` | `02_Manual_Axis_Ubp_J2` | Same template, j=2 |
| `UBP/02_Content` | `02_Manual_Axis_Ubp_J3` | Same template, j=3 |
| `UBP/02_Content` | `02_Manual_Axis_Ubp_J4` | Same template, j=4 |
| `UBP/02_Content` | `02_Diag_Ubp` | Bilingual title-card placeholder (Tier 3 future) |
| `UBP/02_Content` | `02_Config_Ubp` | Bilingual title-card placeholder |

### 5.3 — UBP family binding consumers (PLC tags consumed)

> **PARTLY SUPERSEDED by Section 7 (2026-05-21 refactor).** The four
> `instFB_AutoCtrl_ABCDE.statTargetPos.*` rows below are repointed — see Section 7.1.
> `i16_AutoStep` keeps its path but its value set changed — see Section 7.2.

| PLC tag | UBP widget(s) | R/W | Trigger | Notes |
|---|---|---|---|---|
| `GDB_MachineCmd.bo_Start` | `btnAutoStart` on `02_Auto_Ubp` | W | PULSE 250ms | Wang Shuo R_TRIG rising-edge in FB_AutoCtrl_ABCDE consumes; per HMI agent cycle-7.0 |
| `GDB_MachineCmd.bo_Stop` | `btnAutoStop` (Auto) + Kin manual STOP footer | W | PULSE 250ms + LEVEL | Dual binding for both Auto + Manual surfaces |
| `GDB_MachineCmd.bo_InitPath` | `btnAutoInitPath` (Auto card) | W | PULSE 250ms | One-time path init per cycle session |
| `GDB_MachineCmd.bo_Mode` | `btnAutoMode` (Auto) + Kin manual ENABLE footer | W | TOGGLE | Used as auto-mode AND manual-mode enable proxy (current design — V1 mutex by HMI convention) |
| `GDB_MachineCmd.i16_AutoStep` | `txtAutoStep` IOField on cardProgress | R | LEVEL | 0/10/20/30/40/50 |
| `instFB_AutoCtrl_ABCDE.statTargetPos.x` | `txtTargetX` IOField on cardProgress | R | LEVEL | currently-commanded TCP target X |
| `instFB_AutoCtrl_ABCDE.statTargetPos.y` | `txtTargetY` IOField | R | LEVEL | TCP target Y |
| `instFB_AutoCtrl_ABCDE.statTargetPos.z` | `txtTargetZ` IOField | R | LEVEL | TCP target Z (kin manual screen also reads as ReadOnly target display) |
| `instFB_AutoCtrl_ABCDE.statTargetPos.a` | `txtTargetA` IOField | R | LEVEL | wrist A |
| `J1_SCARA_Arm3D.ActualPosition` | `02_Manual_Axis_Ubp_J1` position card + 2×2 quadrant J1 IOField | R | LEVEL | TO_Axis direct via TIA S7 driver (HMI's preferred path) |
| `J2_SCARA_Arm3D.ActualPosition` | J2 equivalents | R | LEVEL | |
| `J3_SCARA_Arm3D.ActualPosition` | J3 equivalents | R | LEVEL | |
| `J4_SCARA_Arm3D.ActualPosition` | J4 equivalents | R | LEVEL | |
| `J1_SCARA_Arm3D.ActualVelocity` | per-axis deep-drill J1 Velocity row | R | LEVEL | HMI agent's defensive binding accepted by TIA Compile (2026-05-17 21:30) |
| `J2_SCARA_Arm3D.ActualVelocity` | J2 deep-drill Velocity | R | LEVEL | |
| `J3_SCARA_Arm3D.ActualVelocity` | J3 deep-drill Velocity | R | LEVEL | |
| `J4_SCARA_Arm3D.ActualVelocity` | J4 deep-drill Velocity | R | LEVEL | |

### 5.4 — HMI internal tags (Ubp_Local table — 3 Internal, no PLC binding)

| Tag | Type | Purpose |
|---|---|---|
| `ubpNavSection` | Int Internal | 5-tab bottom-nav selector (drives swContent ScreenWindow Range) |
| `ubpPopupIndex` | Int Internal | Modal popup index (reserved for future) |
| `ubpManualTab` | Int Internal | Manual inner-tab Kin/Axis selector (drives swManualTab Range) |

### 5.5 — HMI internal tags (Default tag table — 4 PLC-bound Bools)

Per HMI agent's `UbpLayoutHostBuilder.EnsureUbpTags()` + `UbpAutoBuilder` `EnsureHmiTags()`:

| HMI tag name | PLC path | Type | Purpose |
|---|---|---|---|
| `bo_Start` | `GDB_MachineCmd.bo_Start` | Bool | Used by btnAutoStart JS PULSE event |
| `bo_Stop` | `GDB_MachineCmd.bo_Stop` | Bool | Used by btnAutoStop JS PULSE event |
| `bo_Mode` | `GDB_MachineCmd.bo_Mode` | Bool | Used by btnAutoMode TOGGLE event |
| `bo_InitPath` | `GDB_MachineCmd.bo_InitPath` | Bool | Used by btnAutoInitPath JS PULSE event |

`i16_AutoStep` + `statTargetPos.*` + per-axis `Actual*` consumed via IOField direct PLC path bindings (no separate HMI tag entry needed — IOField widget reads PLC path directly).

### 5.6 — Cycle 7.2 deferred bindings (placeholders — STRIPPED waiting on PLC Phase G)

Per HMI agent's §3 cycle-7.2 manual-wiring follow-up, the following UBP widgets render as visual placeholders pending PLC delivery of `GDB_ManualCmd` + `GDB_ManualStatus` + `FB_ManualCtrl` (see `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md`):

- Per-axis ENABLE / HOME / RESET buttons (4 axes × 3 = 12)
- Per-axis JOG+ / JOG- buttons (4 axes × 2 = 8)
- Per-axis status lamps ready/homed/error (4 × 3 = 12)
- Kin status lamps enabled/ready/homed/error (4)
- Kin axis active-selector (1) + JOG+/JOG- (2) = 3 widgets

Total ~42 widgets pending Phase G unblock.

---

## 6. Phase C.0 + C.0b PLC diagnostic surface (NEW 2026-05-17 22:00 — PLC_DIAGNOSTIC_ONLY)

PLC agent extended `GDB_MCDData` + backported `FB_AxisCtrl` rev 1.2 from v9 during Phase C. These new tags are **PLC-side diagnostic mirrors NOT bound by HMI** — HMI continues to read TO_Axis direct via TIA's S7 driver per the canonical design. The new GDB members exist for:
- PLCSIM-Adv API monitoring (TO_Axis not exposed via API directly — `Read-Tag 'J1_SCARA_Arm3D.ActualPosition'` returns `Error -4 DoesNotExist`)
- Cross-check verification (smoke test reads explicit mirror; HMI reads TO direct; both should match)
- Future tooling parity (any agent / script can read joint actuals without TO_Axis driver quirks)

### 6.1 — `GDB_MCDData` Phase C.0 extension (NEW Static members, +8)

| PLC path | Type | Direction | Source assignment in `FB_MCDDataTransfer.scl` rev 0.2 | HMI binding |
|---|---|---|---|---|
| `GDB_MCDData.J1_ActualPosition` | LReal | R | `:= "J1_SCARA_Arm3D".ActualPosition;` | **NOT BOUND** (HMI binds TO_Axis direct) |
| `GDB_MCDData.J1_ActualVelocity` | LReal | R | `:= "J1_SCARA_Arm3D".ActualVelocity;` | NOT BOUND |
| `GDB_MCDData.J2_ActualPosition` | LReal | R | `:= "J2_SCARA_Arm3D".ActualPosition;` | NOT BOUND |
| `GDB_MCDData.J2_ActualVelocity` | LReal | R | `:= "J2_SCARA_Arm3D".ActualVelocity;` | NOT BOUND |
| `GDB_MCDData.J3_ActualPosition` | LReal | R | `:= "J3_SCARA_Arm3D".ActualPosition;` | NOT BOUND |
| `GDB_MCDData.J3_ActualVelocity` | LReal | R | `:= "J3_SCARA_Arm3D".ActualVelocity;` | NOT BOUND |
| `GDB_MCDData.J4_ActualPosition` | LReal | R | `:= "J4_SCARA_Arm3D".ActualPosition;` | NOT BOUND |
| `GDB_MCDData.J4_ActualVelocity` | LReal | R | `:= "J4_SCARA_Arm3D".ActualVelocity;` | NOT BOUND |

Existing `GDB_MCDData.{Position, Velocity}[1..4]` arrays (kinematic-group view sourced from `ScaraArm3D.AxesData.A[i]`) are kept for back-compat with NX MCD signal adapter consumers + legacy smoke test code.

### 6.2 — `FB_AxisCtrl` rev 1.2 backport (Phase C.0b)

Backported from v9 (commit pending). Adds defensive `MC_SetTool(ToolNumber:=1)` one-shot after `axesEnabled` goes TRUE — closes the historical UserFault root cause (without this, post-MRES `ScaraArm3D.ToolNumber=0` → `MC_MoveLinAbs` returns `motionFBStatus=0x8001` → TO_Kinematics raises UserFault).

| New tag | Type | Purpose |
|---|---|---|
| `instFB_AxisCtrl.statToolActivated` | Bool | R diagnostic; TRUE after MC_SetTool Done. Cleared by memory reset; re-fires on next cold start. |
| `instFB_AxisCtrl.instMC_SetTool.*` | MC_SETTOOL standard outputs | R diagnostic — Error/ErrorID/Done/Busy/Active/CommandAborted |

These are also PLC_DIAGNOSTIC_ONLY (not for HMI binding).

### 6.3 — **Important axis-mapping quirk discovered 2026-05-17 22:00**

PLCSIM-Adv API pre-flight revealed that **the TO_Axis direct view and the kinematic-group AxesData view use DIFFERENT axis ordering conventions**:

| Tag | TO_Axis direct view (correct for HMI) | Kinematic-group view (legacy NX MCD path) | Delta |
|---|---|---|---|
| J1 | `J1.ActualPosition` = -40.683 | `AxesData.A[1].Position` (`Position[1]`) = -40.686 | ≈ same ✓ |
| **J2** | `J2.ActualPosition` = **-899.984** | `AxesData.A[2].Position` (`Position[2]`) = **-160.074** | **SWAPPED with J3** |
| **J3** | `J3.ActualPosition` = **-160.074** | `AxesData.A[3].Position` (`Position[3]`) = **-899.984** | **SWAPPED with J2** |
| J4 | `J4.ActualPosition` = 77.989 | `AxesData.A[4].Position` (`Position[4]`) = 77.989 | ≈ same ✓ |

**Implication:**
- HMI's per-axis screens bound to `J{n}.ActualPosition` (TO_Axis direct) display the **correct per-joint values**
- Legacy code reading `GDB_MCDData.Position[i]` (e.g., previous smoke tests in v9 / pre-Phase-C ABCDE) gets J2 and J3 swapped — fine for NX MCD signal adapters (which may expect this kinematic-group ordering) but wrong for "what does HMI show for joint N"
- For HMI parity, ALWAYS use the explicit `GDB_MCDData.J{n}_ActualPosition` / `J{n}_ActualVelocity` (Phase C.0 mirror) — they match TO_Axis direct semantics exactly

This is documented because previous Phase D + F V8 smoke tests reported `GDB_MCDData.Position[3]=450` (which was actually J2's value, not J3's) — a benign reporting oddity at the time, now explained.

---

## 7. 2026-05-21 Architectural Refactor — binding deltas (HMI action list)

The layered-architecture refactor (plan `dazzling-squishing-sloth.md`) restructured the PLC:
process logic in OB1, axis/kinematics in OB30, both auto FBs rebuilt as Huashili-pattern CASE
state machines, manual jog moved onto `LKinCtrl_MC_JogFrame`. Binding impact below.

### 7.1 — Broken bindings — HMI must repoint

`FB_AutoCtrl_ABCDE` is retired; the production 5-point auto FB is **`FB_AutoCtrl_5Pts`**.

| Old PLC path | New PLC path (recommended) | Widgets |
|---|---|---|
| `instFB_AutoCtrl_ABCDE.statTargetPos.x` | `GDB_HMI_Status.target_x` | `txtTargetX` on `02_Auto_Ubp` |
| `instFB_AutoCtrl_ABCDE.statTargetPos.y` | `GDB_HMI_Status.target_y` | `txtTargetY` |
| `instFB_AutoCtrl_ABCDE.statTargetPos.z` | `GDB_HMI_Status.target_z` | `txtTargetZ` |
| `instFB_AutoCtrl_ABCDE.statTargetPos.a` | `GDB_HMI_Status.target_a` | `txtTargetA` |

**Bind the `GDB_HMI_Status` facade, not the iDB directly.** `FB_HMIStatusMirror` mirrors the
active cycle's target into `GDB_HMI_Status.target_{x,y,z,a}` — a stable read surface that
absorbs future FB renames. (Direct `instFB_AutoCtrl_5Pts.statTargetPos.*` also works but is
not rename-proof.)

### 7.2 — Value-semantics changes — same path, new meaning

| PLC path | Change |
|---|---|
| `GDB_MachineCmd.i16_AutoStep` | Now the Huashili CASE state — `0/10/20/30/50/100/110/200/230/800/900` (was `0/10/20/30/40/50`). Path unchanged; an IOField bound to it shows the new value set. |
| `GDB_PalletizingCmd.i16_PalletStep` | Now the CASE state (`0/10/.../900`), **not** the old `1..48` box-phase index. |
| `GDB_HMI_Status.currentStep` / `totalSteps` | `FB_HMIStatusMirror` V0.2 now writes `currentStep` as a progress COUNT — point index `1..5` (ABCDE) or boxes-placed `0..16` (palletizing) — with `totalSteps` `5` / `16`. Recommended for an "N of M" progress display. |

### 7.3 — Manual jog is now Cartesian (Phase 5)

Manual jog uses `LKinCtrl_MC_JogFrame` on the kinematics group in the **WCS (Cartesian)** frame
— it no longer jogs individual joints. The deferred jog buttons (§5.6) map: `bo_J1_Jog*` → TCP
**X**, `bo_J2_Jog*` → **Y**, `bo_J3_Jog*` → **Z**, `bo_J4_Jog*` → **A**. When the jog widgets
are wired, label them X / Y / Z / A, not J1..J4. The command paths
(`GDB_ManualCmd.bo_J{n}_Jog{Forward,Backward}`) and `GDB_ManualStatus.*` are unchanged.

### 7.4 — Unchanged — safe to keep

- `GDB_MachineCmd.{bo_Start, bo_Stop, bo_InitPath, bo_Mode, bo_ESTOP_LOCK}` — paths + semantics unchanged.
- `GDB_PalletizingCmd.*`, `GDB_ManualCmd.*`, `GDB_ManualStatus.*` — global command/status DBs, unchanged.
- `GDB_HMI_Status.*` — the facade read surface; shape unchanged. Preferred for ALL reads.
- TO tags — `J{n}_SCARA_Arm3D.{ActualPosition,ActualVelocity}`, `ScaraArm3D.Position[]` — unchanged.
- Phase 1 folder moves did NOT change any symbolic path.

---

## Refresh model

- **Sections 1-4** (original MTP1000 1280×800 4-screen spec): historical reference, superseded by Section 5. DO NOT edit further.
- **Section 5** (UBP family canonical): updated when HMI agent authors / modifies UBP screens (sync via HMI handoff cycle).
- **Section 6** (Phase C.0/C.0b diagnostic mirror): updated when PLC agent extends `FB_MCDDataTransfer` / `FB_AxisCtrl` / similar diagnostic publishers.
- **Section 7** (2026-05-21 refactor deltas): the authoritative change list for the layered-architecture refactor; the HMI agent re-authors the tag table + screens against it, then this section folds into Section 5 once the HMI rebuild is verified.
- Per AGENT_CONTRACT.md, this file is **PLC-agent sole writer** (HMI agent proposes new rows via HMI_HANDOFF §6; PM/PLC agent absorbs).
