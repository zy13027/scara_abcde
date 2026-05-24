# HMI Handoff to PLC Agent — 2026-05-22 — GDB_Control Replacement Paths

**Status:** BLOCKED-ON-PLC — 7 HMI tags bound to retired GDB_Control (DB#3) are broken at runtime.

**From:** scara-HMI  **To:** scara-PLC
**Triggered by:** Operator visual confirmation in TIA Portal — Ubp_PLC tag table shows pink/broken PLC paths for `GDB_Control.*` bindings.

---

## 1. GDB_Control confirmed retired — replacement paths needed `[BLOCKED-ON-PLC]`

This escalates **§6.1 from HMI_HANDOFF_2026-05-22_Cycle7_9**, now confirmed broken by operator inspection of the Ubp_PLC tag table in TIA Portal.

`GDB_Control` (DB#3) is gone. PLC_HANDOFF_2026-05-21_LayeredRefactor §1 P2 states "all axis I/O consolidated into `GDB_AxisCtrl` (DB#101)" but does NOT list the 7 replacement paths.

**HMI needs the new PLC path for each row below** — same table format as HMI_BINDING_MAP.md Section 1:

| # | HMI tag name | Old PLC path (BROKEN) | New PLC path (PLEASE FILL) | R/W | Widget(s) affected |
|---|---|---|---|---|---|
| 1 | `enableAxes` | `GDB_Control.enableAxes` | **?** | W (PULSE) | `btnAxesEnable` (TopBar) |
| 2 | `homeAxes` | `GDB_Control.homeAxes` | **?** | W (PULSE) | `btnAxesHome` (TopBar) |
| 3 | `resetAxes` | `GDB_Control.resetAxes` | **?** | W (PULSE) | `btnAxesReset` (TopBar) |
| 4 | `axesEnabled` | `GDB_Control.axesEnabled` | **?** | R (LEVEL) | `lampAxesEnabled` (TopBar), `lmpKinEnabled_Ubp` (Kin banner), `btnAxesEnable` BackColor dyn |
| 5 | `axesHomed` | `GDB_Control.axesHomed` | **?** | R (LEVEL) | `lampAxesHomed` (TopBar), `lmpKinHomed_Ubp` (Kin banner) |
| 6 | `axesError` | `GDB_Control.axesError` | **?** | R (LEVEL) | `lampAxesError` (TopBar), `lmpKinError_Ubp` (Kin banner) |
| 7 | `axesReady` | `GDB_Control.axesReady` | **?** | R (LEVEL) | `lampAxesReady` (TopBar), `lmpKinReady_Ubp` (Kin banner) |

**Priority: HIGH.** These 7 tags are the operator's axes Enable/Home/Reset buttons + 4 status lamps — the core commissioning + safety surface. Without them, the operator cannot enable or home axes from the HMI.

**Expected PLC response format:** Fill the "New PLC path" column (e.g. `GDB_AxisCtrl.enableAxes`) and confirm data types are unchanged (Bool). HMI will repoint the Ubp_PLC tag table immediately upon receipt.

---

## 2. R6 PauseStep acknowledged — §6.3 CLOSED ✅

Read `PLC_HANDOFF_2026-05-22_R6_PauseStep.md` (VERIFIED).

| Item | Status |
|---|---|
| `GDB_MachineCmd.bo_Pause` (W Bool, PULSE 250ms) | ✅ Accepted — will wire `btnAutoPause` on `02_Auto_Ubp` |
| `GDB_PalletizingCmd.bo_Pause` (W Bool, PULSE 250ms) | ✅ Accepted — will wire `btnPalletPause` on `02_Pallet_Ubp` |
| Paused status = `i16_AutoStep == 75` | ✅ Acknowledged — BackColor dyn on Pause button: amber when step == 75 |
| Resume = existing Start button | ✅ Acknowledged — no new binding needed |

**HMI next action:** Uncomment `EnsureHmiTags` bootstrap for `bo_Pause`, wire click + BackColor dyn. `bo_Paused` (proposed in §6.3) is NOT needed — step value `75` serves as the paused indicator instead. Simpler.

---

## 3. Remaining open items (status unchanged)

| Ref | Item | Status |
|---|---|---|
| §6.1 | GDB_Control 7-tag replacement | **`[BLOCKED-ON-PLC]`** — this handoff |
| §6.2 | `blendProgress` facade gap | `[BLOCKED-ON-PLC]` — still needs PLC response |
| §6.3 | `bo_Pause` implementation | **✅ CLOSED** — R6 delivered |

---

_End of HMI_HANDOFF_2026-05-22_GDB_Control_Replacement.md_
