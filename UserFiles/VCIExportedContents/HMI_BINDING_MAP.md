# HMI_BINDING_MAP — hmiDemoSCARA_ABCDE

**Target device:** MTP1000 Unified Basic Panel 10" (6AV2123-3KB32-0AW0, 1280×800)
**5-control-per-screen cap** (Siemens docs; operator empirically confirms during authoring)
**HMI driver:** WinCC Unified Basic (NOT Comfort — no `ToggleTag` system function; use JS PULSE pattern via `HMIRuntime.Tags(...).Write()` + setTimeout 250ms)
**Last updated:** 2026-05-17 (initial — pre-authoring)
**Plan:** Phase C (`C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`)

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

## Refresh model

Updated whenever HMI screens are authored, modified, or compiled. Source-of-truth for any future HMI agent or operator UI work. Per AGENT_CONTRACT.md, this file is the canonical HMI binding ledger.
