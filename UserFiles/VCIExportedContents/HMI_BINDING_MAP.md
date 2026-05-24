# HMI_BINDING_MAP — hmiDemoSCARA_ABCDE

**Target device:** MTP1000 Unified Basic Panel 10" (6AV2123-3KB32-0AW0, 1280×800)
**5-control-per-screen cap** (Siemens docs; operator empirically confirms during authoring)
**HMI driver:** WinCC Unified Basic (NOT Comfort — no `ToggleTag` system function; use JS PULSE pattern via `HMIRuntime.Tags(...).Write()` + setTimeout 250ms)
**Last updated:** 2026-05-23 (Module F V1.2 — Teach mode VERIFIED, jog-gate bug fixed)
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

## 8. R6 — Auto-cycle Pause step (2026-05-22)

R6 (the last open item of the 2026-05-21 review refactor checklist) adds an auto-cycle
**Pause (暂停)** to both auto modes. Pause is a true mid-trajectory motion halt via
`MC_GroupInterrupt` — the SCARA stops where it is, axes stay **enabled and hold position** —
resumed via `MC_GroupContinue`. HMI impact below.

### 8.1 — New bindings — Pause buttons

| PLC path | Widget | R/W | Pattern | Notes |
|---|---|---|---|---|
| `GDB_MachineCmd.bo_Pause` | new `btnAutoPause` on the Auto / ABCDE surface | W Bool | PULSE 250 ms | Edge-triggered; pauses the ABCDE cycle (R_TRIG in `FB_AutoCtrl_5Pts` consumes). |
| `GDB_PalletizingCmd.bo_Pause` | new `btnPalletPause` on the palletizing surface | W Bool | PULSE 250 ms | Edge-triggered; pauses the palletizing cycle. |

Same JS PULSE pattern as `btnStart` / `btnStop`. **Resume needs no new binding** — it is the
existing `bo_Start` button (Start doubles as Resume while the cycle is paused).

### 8.2 — Value-semantics change — same path, new meaning

| PLC path | Change |
|---|---|
| `GDB_MachineCmd.i16_AutoStep` | Value set now also includes **`75`** (pause-hold state) — `0/10/20/30/50/75/100/110/200/230/800/900`. |
| `GDB_PalletizingCmd.i16_PalletStep` | Value set now also includes **`75`** (pause-hold state). |

An IOField bound to `i16_AutoStep` / `i16_PalletStep` should treat `75` as "paused" — `75` is
the recommended source for a Paused lamp / status text.

---

## 9. Module D — Recipe-driven box sizes (2026-05-23)

Module D adds a recipe layer to the palletizing cycle: WinCC Unified **Parameter Set Control
(PSC)** holds the recipe library on the HMI panel; the PLC keeps one active recipe in
`GDB_ActiveRecipe`; `FB_PatternAutoGen` (called in OB1 `Auto_Cycle` REGION before the
palletizing FB) validates the recipe, auto-fits a one-block grid from product + pallet base
dims, and writes `GDB_PalletizingCmd`'s 10 recipe-driven config members each scan.

### 9.1 — New PSC-bound recipe members (HMI writes via Parameter Set Control)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_ActiveRecipe.recipe.sName` | String[32] | W | Recipe name. HMI display + PSC parameter-set identity. |
| `GDB_ActiveRecipe.recipe.bo_Valid` | Bool | W | **Mandatory PSC handshake.** Write FALSE before transferring a parameter set; write TRUE only AFTER all other members have landed. `FB_PatternAutoGen` consumes the recipe only when TRUE — closes the mid-write race. |
| `GDB_ActiveRecipe.recipe.product.lr_Length` | LReal | W | Box length (mm). Drives pitchX (= Length + Gap). |
| `GDB_ActiveRecipe.recipe.product.lr_Width` | LReal | W | Box width (mm). Drives pitchY. |
| `GDB_ActiveRecipe.recipe.product.lr_Height` | LReal | W | Box height (mm). Copied to `GDB_PalletizingCmd.lr_BoxHeight` — layer Z spacing. |
| `GDB_ActiveRecipe.recipe.product.lr_Gap` | LReal | W | Clearance between boxes (mm). Set 0 for edge-to-edge. |
| `GDB_ActiveRecipe.recipe.pallet.lr_BaseLength` | LReal | W | Pallet base length (mm). Auto-fits `cols = (BaseLength + Gap) DIV (Length + Gap)`. |
| `GDB_ActiveRecipe.recipe.pallet.lr_BaseWidth` | LReal | W | Pallet base width (mm). Auto-fits `rows`. |
| `GDB_ActiveRecipe.recipe.pallet.i16_LayerCount` | Int | W | Stacked layers (tower mode — all layers use the same auto-gen grid). |
| `GDB_ActiveRecipe.recipe.dynamics.lr_Velocity` | LReal | W | Palletizing move velocity (mm/s). |
| `GDB_ActiveRecipe.recipe.dynamics.lr_Acceleration` | LReal | W | Palletizing move acceleration (mm/s²). |
| `GDB_ActiveRecipe.recipe.dynamics.lr_Deceleration` | LReal | W | Palletizing move deceleration (mm/s²). |
| `GDB_ActiveRecipe.recipe.dynamics.lr_Jerk` | LReal | W | Palletizing move jerk (mm/s³). |

### 9.2 — Recipe status / echo (HMI reads, FB_PatternAutoGen writes)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_ActiveRecipe.bo_PatternValid` | Bool | R | Recipe passed validation and the computed grid is live in `GDB_PalletizingCmd`. HMI lamp. |
| `GDB_ActiveRecipe.bo_PatternError` | Bool | R | Recipe rejected (invalid, product bigger than pallet, or over the 22-box path ceiling). `GDB_PalletizingCmd` stays at safe defaults. HMI alarm. |
| `GDB_ActiveRecipe.i16_ComputedGridColsX` | Int | R | Auto-fitted cols X. HMI display. |
| `GDB_ActiveRecipe.i16_ComputedGridRowsY` | Int | R | Auto-fitted rows Y. HMI display. |
| `GDB_ActiveRecipe.i16_ComputedBoxCount` | Int | R | Total boxes = ColsX × RowsY × LayerCount. HMI display. |

### 9.3 — Value-semantics change — `GDB_PalletizingCmd` config members are now recipe-driven

The 10 Module-C config members on `GDB_PalletizingCmd` (`i16_LayerCount`, `i16_GridColsX`,
`i16_GridRowsY`, `lr_BoxPitchX`, `lr_BoxPitchY`, `lr_BoxHeight`, `lr_MoveVelocity`,
`lr_MoveAccel`, `lr_MoveDecel`, `lr_MoveJerk`) are now **sole-written by `FB_PatternAutoGen`
each scan from `GDB_ActiveRecipe.recipe`**. The HMI must not write them directly — write the
recipe instead, and `FB_PatternAutoGen` mirrors it into the config. The corresponding
`GDB_PalletizingCmd` member comments document this.

### 9.4 — Deferred (future module — out of Module D scope)

- **WebEditor** for custom (non-grid) per-box patterns — embedded in a Unified Web Control
  widget (no border / header), reading/writing a SEPARATE DB (e.g. `GDB_CustomPattern`) via
  the S7 Webserver API. Not in Module D. `GDB_ActiveRecipe` is symbolically reachable via
  the S7 Webserver API by default, so the WebEditor add-on architecture remains open.

---

## 10. Module E — Dual-pallet (WanErXin operator-driven + V3.0 review fixes, 2026-05-23)

Module E extends Module D to two pallets with **operator-driven switching** (the WanErXin
pattern — no auto-advance). `GDB_ActiveRecipe.recipe` (Module D singular) is **superseded
by `recipe1` + `recipe2`** — Section 9 paths are **deprecated**; rebind to Section 10 paths
below. PSC binds two parameter sets, one per pallet.

`FB_AutoCtrl_Palletizing` is still untouched — `FB_PatternAutoGen` now mediates pallet
selection + per-pallet validation + writes the active pallet's config into `GDB_PalletizingCmd`.

**V3.0 (same-day, 2026-05-23)** — a critical review of the WanErXin source surfaced 3
bugs the V2.0 inherited or introduced: (a) full-bit was attributed to the **current**
`i16_ActivePalletIdx`, so mid-cycle operator swaps mis-attributed `bo_PalletDone`; (b) no
way to reset `bo_PalletNFull` without going via the other pallet (forced operator to "fake
swap" after a physical refill on the same station); (c) no aggregate "both full" status.
V3.0 fixes all three — see Section 10.6.

### 10.1 — PSC-bound recipes (HMI writes via Parameter Set Control, one set per pallet)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_ActiveRecipe.recipe1.sName` | String[32] | W | Pallet 1 (LEFT) recipe name. |
| `GDB_ActiveRecipe.recipe1.bo_Valid` | Bool | W | **PSC handshake** — FALSE before transfer, TRUE after. Pallet 1. |
| `GDB_ActiveRecipe.recipe1.product.lr_Length / lr_Width / lr_Height / lr_Gap` | LReal | W | Pallet 1 box dims + gap. |
| `GDB_ActiveRecipe.recipe1.pallet.lr_BaseLength / lr_BaseWidth / i16_LayerCount` | LReal / LReal / Int | W | Pallet 1 base dims + stack layers. |
| `GDB_ActiveRecipe.recipe1.dynamics.lr_Velocity / lr_Acceleration / lr_Deceleration / lr_Jerk` | LReal | W | Pallet 1 move dynamics. |
| `GDB_ActiveRecipe.recipe2.sName` | String[32] | W | Pallet 2 (RIGHT) recipe name. |
| `GDB_ActiveRecipe.recipe2.bo_Valid` | Bool | W | PSC handshake for pallet 2. |
| `GDB_ActiveRecipe.recipe2.product.*` / `.pallet.*` / `.dynamics.*` | as above | W | Pallet 2 mirror of recipe1. |

The HMI authors **two** Parameter Set Controls (one per pallet) or one PSC with per-pallet
parameter-set groups — vendor-specific UX choice. Each PSC writes its pallet's recipe via
the `bo_Valid` handshake (FALSE → write members → TRUE).

### 10.2 — Pallet selection (HMI maintained-button operator flags)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_ActiveRecipe.bo_ExecutePallet1` | Bool | W | **Maintained** "select pallet 1" button (WanErXin `执行左边`). Hold TRUE while pallet 1 is the active target. |
| `GDB_ActiveRecipe.bo_ExecutePallet2` | Bool | W | **Maintained** "select pallet 2" button. |
| `GDB_ActiveRecipe.i16_ActivePalletIdx` | Int | R | FB status: 1 = pallet 1 active, 2 = pallet 2 active, 0 = idle (neither pressed, both pressed [stalemate], or active-side full). |

**Mutex rules** (enforced in `FB_PatternAutoGen`):
- Both flags FALSE → idle (idx 0).
- Both flags TRUE → idle (stalemate; HMI should prevent this UX-side).
- One flag TRUE AND that side not full → that pallet active.
- One flag TRUE AND that side full → idle (operator must press the OTHER side to swap).

### 10.3 — Per-pallet status (FB writes; HMI reads)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_ActiveRecipe.bo_PatternValid1` / `bo_PatternValid2` | Bool | R | Per-pallet recipe validation status (independent of whether the pallet is active). Lamps. |
| `GDB_ActiveRecipe.bo_PatternError1` / `bo_PatternError2` | Bool | R | Per-pallet alarm. |
| `GDB_ActiveRecipe.i16_ComputedGridColsX1` / `_X2` | Int | R | Per-pallet auto-fitted cols. |
| `GDB_ActiveRecipe.i16_ComputedGridRowsY1` / `_Y2` | Int | R | Per-pallet auto-fitted rows. |
| `GDB_ActiveRecipe.i16_ComputedBoxCount1` / `_BoxCount2` | Int | R | Per-pallet total boxes. |
| `GDB_ActiveRecipe.bo_Pallet1Full` | Bool | R | Latched when GDB_PalletizingCmd.bo_PalletDone is TRUE while the **in-flight cycle's** pallet (`statCyclePalletIdx`, snapshotted at bo_InitPallet rising edge — V3.0) is 1. Auto-clears when operator switches to pallet 2 (presses Pallet 2 button while Pallet 1 button is released). Also clears while `bo_AckPallet1Full` is held TRUE (V3.0). |
| `GDB_ActiveRecipe.bo_Pallet2Full` | Bool | R | Mirror of bo_Pallet1Full for pallet 2. |

**V3.0 attribution fix:** the full-bit latch uses the cycle-start snapshot, not the live
`i16_ActivePalletIdx`. This means mid-cycle operator swaps cannot mis-attribute the
`bo_PalletDone` event — the pallet that was building when `bo_InitPallet` fired is the
pallet that gets its full bit latched, regardless of where the operator's flags are when
the cycle completes.

A `bo_BothPalletsFull` aggregate is now provided in V3.0 (see 10.6) — there is still no
`bo_AllPalletsDone` semantic distinction (the WanErXin model treats the two pallets as
independent demand-driven slots; "session done" is HMI-side if needed).

### 10.4 — Section 9 (Module D singular `recipe.*`) is DEPRECATED

The Module D paths `GDB_ActiveRecipe.recipe.*` / `bo_PatternValid` / `bo_PatternError` /
`i16_ComputedGridColsX` / `RowsY` / `BoxCount` no longer exist — they were renamed and
duplicated for dual-pallet. Map of old → new (use this for HMI re-bind):

| Section 9 (Module D, gone) | Section 10 (Module E) |
|---|---|
| `recipe.*` | `recipe1.*` (pallet 1) + `recipe2.*` (pallet 2) |
| `bo_PatternValid` | `bo_PatternValid1` + `bo_PatternValid2` |
| `bo_PatternError` | `bo_PatternError1` + `bo_PatternError2` |
| `i16_ComputedGridColsX` | `i16_ComputedGridColsX1` + `_X2` |
| `i16_ComputedGridRowsY` | `i16_ComputedGridRowsY1` + `_Y2` |
| `i16_ComputedBoxCount` | `i16_ComputedBoxCount1` + `_BoxCount2` |

### 10.5 — Unchanged

- `GDB_PalletizingCmd` config members (Section 9.3) — still sole-written by
  `FB_PatternAutoGen` each scan; HMI still must NOT write them directly. The only change is
  *which* pallet's recipe drives the write at any given moment (determined by
  `i16_ActivePalletIdx`).
- Palletizing cycle command bits (`bo_InitPallet`, `bo_Start`, `bo_Stop`, `bo_Pause`,
  `bo_Mode`, etc.) — unchanged.

### 10.6 — V3.0 WanErXin-review additions (same-day, 2026-05-23)

Three new GDB bits surfaced from the V3.0 fixes — author HMI controls for them:

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_ActiveRecipe.bo_AckPallet1Full` | Bool | W | **Maintained** "reset pallet 1 full alarm" button (HMI authors next to the pallet 1 Full lamp). While TRUE, `FB_PatternAutoGen` forces `bo_Pallet1Full := FALSE` each scan. Use this when operator physically empties + replaces pallet 1 on the same station and wants to re-arm without first having to swap to pallet 2. Operator must **release** the Ack button before the next cycle's `bo_PalletDone` can re-latch the full bit. |
| `GDB_ActiveRecipe.bo_AckPallet2Full` | Bool | W | Mirror of `bo_AckPallet1Full` — operator reset for pallet 2. |
| `GDB_ActiveRecipe.bo_BothPalletsFull` | Bool | R | FB-computed aggregate = `bo_Pallet1Full AND bo_Pallet2Full`. Use as a single status lamp / alarm condition on the HMI ("both pallets need unloading"). Read-only — `FB_PatternAutoGen` is sole writer. |

UX guidance:
- The per-pallet Ack button sits next to that pallet's Full alarm lamp. It is **maintained**
  (operator holds while pressing, releases before re-arming). A momentary HMI button works
  too if the HMI layer pulses it via JS (250 ms), but maintained matches the WanErXin idiom
  of the Execute buttons.
- The WanErXin swap-clear path **still works** — `Ack` is the additional convenience path,
  not a replacement. Both paths clear the full bit; either gesture is operator-valid.
- `bo_BothPalletsFull` is a derived bit — no HMI write. Use as a colour/blink driver on a
  Both-Full panel-level alarm.

---

## 11. Module F — Teach mode (operator-driven jog + capture + replay, V1.2 VERIFIED 2026-05-23)

Module F adds the **4th mutex mode** — `GDB_TeachCmd.bo_Mode` — parallel to ABCDE
(`GDB_MachineCmd.bo_Mode`, transitional), Palletizing (`GDB_PalletizingCmd.bo_Mode`), and
Manual (`GDB_ManualCmd.bo_Mode`). HMI should radio-button them so exactly one is active.

**V1.2 (same-day, 2026-05-23):** smoke-surfaced jog-gate fix in `FB_TeachCtrl` REGION
Cartesian_Jog. V1.0/V1.1 wrote 8 jogframe bits unconditionally each scan; since
FB_TeachCtrl runs AFTER FB_ManualCtrl in OB1, those writes silently overwrote
FB_ManualCtrl's TRUE jog bits to FALSE, breaking operator manual jog whenever Module F
was deployed. V1.2 wraps the writes in `IF #statTeachOK THEN ... END_IF` — when teach
is off, FB_TeachCtrl leaves `jogframe.*` alone; when teach is on, manual is mutex-blocked
so FB_TeachCtrl owns jog uncontested. No HMI binding changes from this fix.

**V1.1 (same-day, 2026-05-23):** Capture now records BOTH Cartesian TCP AND joint angles
per Phase 2 Chinese spec §7.1 (`捕获脉冲 → 当前 TCP/关节 写点表`). One bo_Capture pulse fills
both `aPoints[idx]` (Cartesian) and `aJointAngles[idx, 1..4]` (J1/J2/J3/J4). Replay
still walks `aPoints` via Cartesian linear (V1.0 behavior preserved); joint-space PTP
replay using `aJointAngles` is reserved for a future extension.

In teach mode the operator jogs the SCARA with the existing manual-mode jog buttons,
captures the live TCP into one of 16 slots (`GDB_TeachPoints.aPoints[1..16]`), and then
plays the captured sequence back. The taught points reuse `LKinCtrl_typePoint` (Siemens-
canonical 6-DoF UDT, position[0..5]), with the 4-DoF SCARA populating [0..3] and zeroing
[4..5]. `FB_TeachCtrl` writes to the same shared `GDB_AxisCtrl.LKinCtrl.input.movelinear`
register the other mode FBs use; `FB_AxisCtrl` (OB30) runs the motion. The HMI also gains
a PLC-side mirror of live TCP at `GDB_AxisCtrl.LKinCtrl.output.actualposition.{x,y,z,a}`
(new in Module F — populated by `FB_AxisCtrl` REGION `MirrorTCP` from
`ScaraArm3D.Position[1..4]`).

### 11.1 — Mode toggle + safety (HMI W)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_TeachCmd.bo_Mode` | Bool | W | Teach mode toggle (4th mutex mode). HMI: radio-group with the other three mode toggles. Default FALSE. |
| `GDB_TeachCmd.bo_ESTOP_LOCK` | Bool | W | Safety latch (mirrors the GDB_PalletizingCmd / GDB_ManualCmd convention). Default TRUE post-startup. |

### 11.2 — Per-slot operator commands (HMI PULSE)

All four are **edge-detected by FB_TeachCtrl** — HMI must pulse them (TRUE then FALSE
within ~250 ms via JS, same pattern as `btnStart` / `btnInitPath`).

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_TeachCmd.i16_SlotIdx` | Int | W | Which slot (1..16) the per-slot operations target. HMI: IOField + spinner, or a selectable row in the teach-table view. Default 1. |
| `GDB_TeachCmd.bo_Capture` | Bool | W | PULSE: snapshot the live TCP into `aPoints[i16_SlotIdx]` and set `abCaptured[idx] := TRUE`. Operator's main teach action. |
| `GDB_TeachCmd.bo_Verify` | Bool | W | PULSE: move the robot to `aPoints[i16_SlotIdx]` (linear move at `lr_ReplayVel`). Validates the slot points where intended. |
| `GDB_TeachCmd.bo_Clear` | Bool | W | PULSE: clear `aPoints[i16_SlotIdx]` (zero the position fields) and `abCaptured[idx] := FALSE`. |
| `GDB_TeachCmd.bo_ClearAll` | Bool | W | PULSE: clear all 16 slots in one pass. |

### 11.3 — Replay (HMI PULSE + dynamics)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_TeachCmd.bo_StartReplay` | Bool | W | PULSE: start once-through replay of captured slots in index order. Skips uncaptured slots. Latches `bo_ReplayDone` at end. |
| `GDB_TeachCmd.bo_StopReplay` | Bool | W | PULSE: abort replay immediately; current move aborts via the MC layer. |
| `GDB_TeachCmd.lr_ReplayVel` | LReal | W | Replay-move velocity (mm/s). Default 200.0 — matches FB_ManualCtrl safe-jog dynamics. |

### 11.4 — FB status / echoes (HMI R)

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_TeachCmd.i16_TeachStep` | Int | R | Current FSM step (0=idle, 10=capture-flash, 20=verify-in-flight, 30=clear-flash, 100/110/120=replay-in-flight, 200=replay-done-flash, 800=fault). HMI status text. |
| `GDB_TeachCmd.i16_ReplayIdx` | Int | R | Slot currently being executed during replay (1..16, 0 when idle). HMI: highlight the active row in the teach-table. |
| `GDB_TeachCmd.bo_ReplayDone` | Bool | R | Latched TRUE on replay completion. Cleared on next StartReplay. HMI lamp. |
| `GDB_TeachPoints.i16_PointCount` | Int | R | Count of captured slots (0..16). HMI status: "N / 16 captured". |
| `GDB_TeachPoints.aPoints[i].name` | WString | R | Per-slot name (HMI-writable later if Module F adds a "rename" button; the FB does not touch this). |
| `GDB_TeachPoints.aPoints[i].position[0..5]` | LReal | R | Per-slot Cartesian position (WCS). [0]=X, [1]=Y, [2]=Z, [3]=A wrist. [4]/[5] = B/C (populated from TO; SCARA solver fills based on joint posture). HMI: display [0..3] per row in the teach-table view. |
| `GDB_TeachPoints.aJointAngles[i, 1..4]` | LReal | R | V1.1: per-slot joint angles J1/J2/J3/J4 captured at the same scan as `aPoints[i]`. **2D array** (`Array[1..16, 1..4]`) — comma-indexed access, e.g. `aJointAngles[3, 1]` = slot 3's J1. J1/J2/J4 in degrees, J3 in mm (prismatic Z). HMI optional: secondary "joints" view of the teach table for operators who want to inspect joint posture per slot. Archival today (Cartesian replay uses `aPoints`); a future joint-space PTP replay would consume this. |
| `GDB_TeachPoints.abCaptured[i]` | Bool | R | Per-slot "this slot is taught" flag (one flag covers BOTH aPoints[i] and aJointAngles[i] — V1.1). HMI: row icon (filled vs. empty). |

### 11.5 — Live TCP mirror (Module F latent-gap fix)

`FB_AxisCtrl` REGION `MirrorTCP` (new) populates these every OB30 scan (10 ms) from
`ScaraArm3D.TcpInWcs.{x,y,z,a,b,c}.Position` — the Siemens-canonical TO_Kinematics
member for TCP-in-WCS (`TO_Struct_Kinematics_StatusKinematicsFrameWithDynamics`, V9.0).
The HMI's existing `Actual_Pos_Screen` reads the TCP directly via the S7 driver — this
PLC-side mirror is for FB_TeachCtrl capture and any future diagnostic that needs
symbolic TCP access.

| PLC path | Type | R/W | Notes |
|---|---|---|---|
| `GDB_AxisCtrl.LKinCtrl.output.actualposition.x` | LReal | R | Live TCP X (mm) in WCS. Source `ScaraArm3D.TcpInWcs.x.Position`. |
| `GDB_AxisCtrl.LKinCtrl.output.actualposition.y` | LReal | R | Live TCP Y (mm). Source `ScaraArm3D.TcpInWcs.y.Position`. |
| `GDB_AxisCtrl.LKinCtrl.output.actualposition.z` | LReal | R | Live TCP Z (mm). Source `ScaraArm3D.TcpInWcs.z.Position`. |
| `GDB_AxisCtrl.LKinCtrl.output.actualposition.a` | LReal | R | Live TCP wrist A (deg). Source `ScaraArm3D.TcpInWcs.a.Position`. |

### 11.6 — Jog buttons are SHARED with Manual mode

`FB_TeachCtrl` REGION `Cartesian_Jog` copies the wiring from `FB_ManualCtrl` verbatim,
so the same HMI jog buttons (`GDB_ManualCmd.bo_J1_JogForward` etc.) drive the robot in
**both** manual and teach mode. The two FBs are mutually exclusive via their mode gates,
so they never both write the `jogframe` register on the same scan. No new jog tags.

HMI consideration: when the operator is on the teach screen, the jog buttons should be
**visible and active** — operator jogs, then captures. If the HMI prefers a dedicated
teach screen, mirror or link the existing manual-screen jog buttons there.

### 11.7 — UX guidance

- **Mode radio-button**: the four mode toggles (ABCDE / Palletizing / Manual / Teach)
  should be a single-selection radio so the operator can only have one active at a time.
  The HMI can enforce this client-side; PLC's `FB_TeachCtrl` (and the other mode FBs)
  defensively gate on `NOT other_modes` regardless.
- **Capture choreography**: operator enters teach mode → jogs to desired TCP → sets
  `i16_SlotIdx := N` → pulses `bo_Capture` → repeats. The `i16_TeachStep` flashes to 10
  briefly (one scan) for visual feedback that the capture landed.
- **Verify**: a "Go to slot" button per row, pulsing `bo_Verify` after setting
  `i16_SlotIdx`. The robot moves there at `lr_ReplayVel`. Display the captured pose vs.
  the live TCP to confirm.
- **Replay**: a single "Play taught sequence" button pulses `bo_StartReplay`. The robot
  moves through captured slots 1 → 16 in order (skipping `abCaptured = FALSE` slots).
  HMI highlights the current slot via `i16_ReplayIdx`. On finish, `bo_ReplayDone` lamp
  lights. Operator can pulse `bo_StopReplay` to abort.

### 11.8 — What is intentionally NOT in Module F (deferred)

- **Per-point velocity / dwell / gripper actions** — a single shared `lr_ReplayVel` for
  all moves. Per-point dynamics would be a Module F-prime extension.
- **Joint-space teach** — Module F captures in WCS only (`coordSystem := 0`).
- **PSC handshake for teach points** — points live in Retain memory directly. No
  HMI-side "save teach to panel / load from panel" yet. If added later, follows the
  Module D `bo_Valid` PSC handshake pattern.
- **Singularity hints** (`linkConstellation`, `turnJoint`) — left at UDT defaults
  (`16#FFFF_FFFF` / 0). Operator-configurable hints are a followup if a teach point
  lands in a singularity-sensitive pose.

---

## Refresh model

- **Sections 1-4** (original MTP1000 1280×800 4-screen spec): historical reference, superseded by Section 5. DO NOT edit further.
- **Section 5** (UBP family canonical): updated when HMI agent authors / modifies UBP screens (sync via HMI handoff cycle).
- **Section 6** (Phase C.0/C.0b diagnostic mirror): updated when PLC agent extends `FB_MCDDataTransfer` / `FB_AxisCtrl` / similar diagnostic publishers.
- **Section 7** (2026-05-21 refactor deltas): the authoritative change list for the layered-architecture refactor; the HMI agent re-authors the tag table + screens against it, then this section folds into Section 5 once the HMI rebuild is verified.
- **Section 8** (R6 Pause step): new auto-cycle Pause bindings; the HMI agent authors the two Pause buttons + the step-75 handling, then this folds into Section 5.
- **Section 9** (Module D recipe + PSC): **DEPRECATED by Section 10** — Module D's singular `recipe.*` was renamed to `recipe1.*` and a second `recipe2.*` was added for dual-pallet. Rebind to Section 10 paths.
- **Section 10** (Module E dual-pallet): two PSC parameter sets (one per pallet) bound to `recipe1.*` / `recipe2.*`; two maintained "execute pallet N" buttons; per-pallet status + full-alarm lamps. Operator-driven switch (WanErXin pattern, no auto-advance). HMI agent authors two PSCs + the two-button switch UI + per-pallet alarm lamps, then this folds into Section 5.
- **Section 11** (Module F V1.2 teach mode, VERIFIED 2026-05-23): new 4th mutex mode + teach screen (16-slot table + Capture/Verify/Clear/ClearAll + Replay Start/Stop/Vel + status echoes). PLC side smoke-tested 24/24 PASS. HMI agent authors the teach screen and the 4-way mode radio (Module F V1.2 PLC binding contract is stable), then this folds into Section 5.
- Per AGENT_CONTRACT.md, this file is **PLC-agent sole writer** (HMI agent proposes new rows via HMI_HANDOFF §6; PM/PLC agent absorbs).
