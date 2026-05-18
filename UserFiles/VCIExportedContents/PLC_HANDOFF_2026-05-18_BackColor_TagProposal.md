**Status:** INFORMATIONAL → HMI agent. Proposal: which PLC tags should drive BackColor Range dynamization on UBP status lamps + cycle-state indicators. Covers what's **available today** (Phase C scope, no PLC code needed) vs what needs **Phase G** (per-axis cmd/status FB).

# PLC_HANDOFF — BackColor Range-dyn Tag Bindings for UBP Status Lamps

**Project:** `hmiDemoSCARA_ABCDE`
**Date:** 2026-05-18
**Cycle:** C66 follow-up (topical addendum to `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md`)
**Predecessors:**
- C66 main verified handoff (`PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md`) — Phase C ✅ 8/8 V6+V7-partial PASS
- C66 manual-mode proposal (`PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md`) — Phase G blueprint
- HMI agent Cycle-7.0 CompileGreen — UBP family uses `BackColor Range dyn on ubpNavSection` for 5-tab active-highlight; same pattern applies to status lamps

**Operator directive (2026-05-18 morning):** "tell hmi agent what tag should link to backcolor"

---

## 1. WinCC Unified Basic BackColor Range dyn pattern (HMI agent's existing convention)

Per HMI agent's `BottomNav_Ubp` build: each tab uses a `BackColor` Range dyn bound to `ubpNavSection` Internal Int — when value matches the tab's index, background goes Siemens-teal (`#00557F`); otherwise neutral gray.

```
ScreenItem.BackColor
  → Range dyn (Trigger Tag = <PLC tag>)
    → Range 1 (e.g. value == 0): BackColor = #6B7280 (neutral gray)
    → Range 2 (e.g. value == 1): BackColor = #00557F (Siemens teal — active)
    → Range 3 (e.g. value >= 2): BackColor = #E60028 (Siemens red — alarm/fault)
```

Same pattern works for status lamps (Bool input via implicit 0/1 ranges) and multi-state indicators (Int input with N ranges).

---

## 2. Available TODAY (Phase C scope — no Phase G dependency)

These PLC tags exist + are readable + already proven via Phase C smoke test. HMI agent can bind in cycle-7.1 immediately.

### 2.1 — Auto-cycle state indicators (drive `02_Auto_Ubp` lamps)

| HMI widget | PLC tag | BackColor Range dyn |
|---|---|---|
| `lampAutoRunning` | `GDB_MachineCmd.i16_AutoStep` | 0 → gray (idle); 10..50 → Siemens-teal (running) |
| `lampPathInitialed` | `GDB_MachineCmd.bo_PathInitialed` | FALSE → gray (not initialized); TRUE → green (path ready) |
| `lampAutoMode` | `GDB_MachineCmd.bo_Mode` | FALSE → gray; TRUE → Siemens-teal (auto mode enabled) |
| `lampAlarm` | `GDB_MachineCmd.bo_Alarm` | FALSE → gray; TRUE → Siemens-red (alarm active) |
| `lampEstop` | `GDB_MachineCmd.bo_ESTOP_LOCK` | FALSE → Siemens-red (E-Stop active); TRUE → green (safety OK) |

### 2.2 — Per-step progress / current-point highlighting (5-step ABCDE sequence)

The HMI's `cardStepList` (6 rows on `02_Auto_Ubp` Left column) currently renders as `[MANUAL-WIRING]` placeholder. With `i16_AutoStep` available, HMI can light up the current step's row with BackColor Range dyn:

| HMI widget | PLC tag | BackColor Range dyn (per row) |
|---|---|---|
| `cardStepList.row1` (A) | `GDB_MachineCmd.i16_AutoStep` | == 10 → Siemens-teal (current); else gray |
| `cardStepList.row2` (B) | same | == 20 → teal; else gray |
| `cardStepList.row3` (C) | same | == 30 → teal; else gray |
| `cardStepList.row4` (D) | same | == 40 → teal; else gray |
| `cardStepList.row5` (E) | same | == 50 → teal; else gray |

Visual: as ABCDE cycle runs, the highlighted row marches A→B→C→D→E in real time.

### 2.3 — Group-level axis status (Kin status banner — `02_Manual_Kin_Ubp`)

The 4 Kin status lamps HMI agent stripped (`mc_kin_statusEnabled/Ready/Homed/Error`) can be partially restored from existing `GDB_Control` group-level state:

| HMI widget | PLC tag | BackColor Range dyn |
|---|---|---|
| `lampKinEnabled` | `GDB_Control.axesEnabled` | FALSE → gray; TRUE → Siemens-teal |
| `lampKinHomed` | `GDB_Control.axesHomed` | FALSE → gray; TRUE → green |
| `lampKinError` | `GDB_Control.axesError` | FALSE → gray; TRUE → Siemens-red |
| `lampKinReady` | (derived) | HMI-side: `axesEnabled AND axesHomed AND NOT axesError`. Use a Tag Set with multi-input or a hidden Int tag computed from JS event. |

**Caveat**: these are GROUP-LEVEL (all 4 joints aggregated). Per-joint status lamps still need Phase G's `GDB_ManualStatus` (or HMI-side bit-mask of `J{n}.StatusWord`).

### 2.4 — Tool activation diagnostic (NEW Phase C.0b)

| HMI widget | PLC tag | BackColor Range dyn |
|---|---|---|
| `lampToolActive` (diagnostic) | `instFB_AxisCtrl.statToolActivated` | FALSE → Siemens-red (Tool[1] NOT active — UserFault risk); TRUE → green |

Useful as an "is the cycle actually drivable?" health indicator post-MRES. Recommended placement: `02_Diag_Ubp` or `02_Home_Ubp` as a small footer lamp.

### 2.5 — V8 blending progress bar (analog/numeric BackColor)

| HMI widget | PLC tag | Display mode |
|---|---|---|
| `barProgress` on `cardProgress` | `instFB_AutoCtrl_ABCDE.statProgress` | LReal 0..1 → render as horizontal bar (BackColor solid) OR Range dyn: <0.5 → orange (motion in progress); >=0.5 → green (about to advance) |
| OR alternative | same | Numeric IOField displaying 0..100% |

---

## 3. Needs Phase G (per-axis status — deferred to PLC implementation cycle)

The following BackColor bindings remain `[MANUAL-WIRING]` until `FB_ManualCtrl` + `GDB_ManualStatus` ship per `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md`:

### 3.1 — Per-axis status lamps (12 stripped lamps on `02_Manual_Axis_Ubp_J{1..4}`)

| HMI widget | Future PLC tag (Phase G) | Alternative TODAY (Option B from C66 proposal) |
|---|---|---|
| `lampJ{n}_Enabled` (4 lamps) | `GDB_ManualStatus.bo_J{n}_Enabled` | HMI-side bit-mask: `J{n}_SCARA_Arm3D.StatusWord` bit 2 |
| `lampJ{n}_Homed` (4 lamps) | `GDB_ManualStatus.bo_J{n}_Homed` | HMI-side bit-mask: `J{n}_SCARA_Arm3D.StatusWord` bit 5 |
| `lampJ{n}_Error` (4 lamps) | `GDB_ManualStatus.bo_J{n}_Error` | HMI-side bit-mask: `J{n}_SCARA_Arm3D.ErrorWord` bit 0 |

**HMI agent's call**: choose Option A (wait for Phase G clean PLC mirror) OR Option B (use TIA HMI's bit-mask binding on `StatusWord` directly — no PLC code change, but requires `BackColor` Range dyn against a computed expression rather than a direct tag).

WinCC Unified Basic supports bit-mask via Trigger Tag formula syntax (e.g., `(J1_SCARA_Arm3D.StatusWord AND 4) <> 0` for bit 2). If preferred, no PLC waiting needed.

### 3.2 — Per-axis JOG-active lamps (8 stripped — show which JOG button is held)

| HMI widget | Future PLC tag (Phase G) |
|---|---|
| `lampJ{n}_JogFwdActive` (4) | `GDB_ManualCmd.bo_J{n}_JogForward` (echo-back of own command for visual confirmation) |
| `lampJ{n}_JogBackActive` (4) | `GDB_ManualCmd.bo_J{n}_JogBackward` |

**Workaround TODAY**: HMI-side internal Bool tag mirrors the button-press state (no PLC roundtrip; instant visual feedback while button held).

### 3.3 — Kin axis JOG-active (3 widgets on Manual_Kin)

| HMI widget | Future PLC tag (Phase G) |
|---|---|
| `lampKinActiveAxisX/Y/Z` (3) | `GDB_ManualCmd.i16_ActiveJointJog` Range dyn: 1→X teal; 2→Y teal; 3→Z teal; else gray |

---

## 4. Status-lamp standard color palette (recommendation)

Consistent with HMI agent's UBP profile:

| State | Color | Hex |
|---|---|---|
| Inactive / Idle | Neutral gray | `#6B7280` |
| Active / Selected | Siemens teal | `#00557F` |
| OK / Healthy / Done | Green | `#76B900` (or Siemens green) |
| Warning / Caution | Orange | `#F59E0B` |
| Error / Fault / E-Stop | Siemens red | `#E60028` |
| Disabled / Not Applicable | Disabled gray | `#9CA3AF` |

---

## 5. Recommended HMI cycle-7.1 BackColor binding work

Priority order (highest impact first):

1. **`02_Auto_Ubp` cardProgress + cardStepList** (Section 2.1 + 2.2): biggest visual improvement; all tags exist today; ~10 BackColor Range dyn assignments
2. **`02_Diag_Ubp` health-overview lamp grid** (Sections 2.1, 2.3, 2.4): operator sees system health at a glance — currently a blank placeholder screen
3. **`02_Manual_Kin_Ubp` group-level status banner** (Section 2.3): 3 lamps (Enabled/Homed/Error) become functional; 1 lamp (Ready) needs HMI-side compute or hidden Int tag
4. **Per-axis status lamps** (Section 3.1): HMI agent's call — bit-mask now (no PLC wait) OR wait for Phase G clean mirror

Estimated HMI cycle-7.1 work: ~30-60 min C# builder edits to add `BindBackColor*` helper calls + the Range dyn definitions.

---

## 6. Open questions for HMI agent (request response in next HMI handoff)

1. **For per-axis status lamps**: prefer bit-mask of `J{n}.StatusWord` today (Option B — no PLC wait) OR wait for Phase G `GDB_ManualStatus.bo_J{n}_*` (Option A — clean mirror)?
2. **For derived "Ready" lamp**: HMI-side computed via Tag Set / JS event handler, OR ask PLC agent to add `GDB_Control.axesReady` (derived in `FB_AxisCtrl`)?
3. **Color palette**: confirm the §4 palette matches HMI agent's `UbpC` static class (per `Builders/Ubp/UbpProfile.cs`)?
4. **Range dyn vs direct BackColor binding**: for simple Bool → 2-color mapping, is Range dyn (2 ranges) idiomatic, OR is there a simpler Bool-to-color binding in WinCC Unified Basic?

---

## 7. Closure markers

- [INFORMATIONAL → HMI] proposal for cycle-7.1 BackColor binding scope
- [AVAILABLE_TODAY] Sections 2.1-2.5 (≥10 status lamps + step-list highlights can land in cycle-7.1 without any PLC change)
- [NEEDS_PHASE_G] Sections 3.1-3.3 (per-axis status + jog-active lamps; gated on `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md` implementation)
- [REOPENABLE] HMI agent's response to §6 open questions may shift Section 3.1 from "needs Phase G" to "doable today via bit-mask"

---

## Cross-references

- `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` — Phase C verification (the source of these PLC tags' availability + reliability)
- `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md` — Phase G blueprint (source for §3 future tags)
- `HMI_BINDING_MAP.md` §5 (UBP family) + §6 (Phase C.0/C.0b PLC diagnostic mirror)
- `HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md` (v9 comm tree) — HMI agent's existing `BackColor Range dyn` pattern (used by `BottomNav_Ubp` 5-tab + Manual inner-tab)
- HMI agent's `Builders/Ubp/UbpProfile.cs` — canonical `UbpC` color palette (cross-check §4)
