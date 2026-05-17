# PLC Scoreboard — hmiDemoSCARA_ABCDE

**Project:** SCARA ABCDE 5-point auto cycle (minimal rebuild from hmiDemoMomoryCapacity_v9)
**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`
**Source spec:** `UserFiles/VCIExportedContents/杨子楠5月17日周计划.md` (cross-mounted reference)
**Last updated:** 2026-05-17
**Last action:** Phase A.1 (source authoring) — backed up prior 11-state+LKinCtrl work + authored 6-state FB_AutoCtrl_ABCDE + new FB_AxisCtrl per approved plan

---

## Status legend

| Icon | Meaning |
|---|---|
| 🆕 | New ask this session — not yet started |
| 🚧 | In progress |
| ✅ | Done (kept on board ≤ 5 cycles for context) |
| ⏸️ | Blocked / waiting on operator or other agent |
| 🔴 | Critical / failing |

---

## A. Manual-by-USER (TIA Portal UI operations, not Openness-scriptable)

| # | Task | Source / Status |
|---|---|---|
| A.1 | TIA Portal: File → New → TIA Project V20 named `hmiDemoSCARA_ABCDE` at `E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/` | 🆕 Plan Phase A.1 — see `OPERATOR_PHASE_A_HANDOFF.md` |
| A.2 | Add Device 1: PLC_1 = S7-1511T-1 PN at firmware V4.0 (fall back to V3.0 if V4.0 not in TIA V20 catalog) | 🆕 Plan Phase A.2 |
| A.3 | Add Device 2: HMI_1 = MTP1000 Unified Basic Panel 10" (6AV2123-3KB32-0AW0) | 🆕 Plan Phase A.3 |
| A.4 | PROFINET network: link PLC ↔ HMI | 🆕 Plan Phase A.4 |
| A.5 | Import 5 TO XMLs via TIA → Add Technology Object → "From existing XML": J1-J4_SCARA_Arm3D + ScaraArm3D from `UserFiles/VCIExportedContents/PLC_1/Technology objects/` | 🆕 Plan Phase A.5 — files staged + already on disk |
| A.6 | TIA Portal: import 6 SCL/XML source files into Program blocks via Openness or External Sources: Main.scl + Startup.scl + GDB_Control.xml + GDB_MachineCmd.xml + FB_AxisCtrl.scl + FB_AutoCtrl_ABCDE.scl + FB_MCDDataTransfer.scl + GDB_MCDData.xml + UDT_typePoint5.xml | 🆕 Plan Phase A/B integration |
| A.7 | TIA Portal: HMI screen authoring (4 screens per UBP 5-control cap) | 🆕 Plan Phase C — see `HMI_BINDING_MAP.md` |
| A.8 | TIA Portal: compile entire project → expect 0W/0E | 🆕 Plan Phase B.8 |
| A.9 | TIA Portal: download to NEW PLCSIM-Adv instance `1511T_ABCDE` at 192.168.0.40 | 🆕 Plan Phase D.1 |
| A.10 | Operator runtime smoke: V1–V7 + V9 (10 sub-tasks per plan Phase D) | 🆕 Plan Phase D |

## B. Claude-Code-PM-tasks (PM agent owned)

| # | Task | Source / Status |
|---|---|---|
| B.1 | Author + back up prior 11-state+LKinCtrl work + rewrite to 6-state+no-libraries per approved plan | ✅ 2026-05-17 |
| B.2 | Bootstrap PM_Workspace + PROJECT_STATUS.md + HMI_BINDING_MAP.md | 🚧 2026-05-17 (this cycle) |
| B.3 | Author OPERATOR_PHASE_A_HANDOFF.md describing TIA Portal manual UI steps for operator | 🆕 This cycle |
| B.4 | Git init + initial commit establishing baseline | 🆕 This cycle |
| B.5 | Once operator completes Phase A: write follow-up handoff confirming TO import + 0W/0E compile result | ⏸️ Blocked on operator A.1–A.8 |
| B.6 | Once operator completes Phase D smoke: write PROJECT_STATUS.md update with V1–V7+V9 results | ⏸️ Blocked on operator A.9–A.10 |

## Recently completed

| Date | Cycle | Handoff / Doc | Status |
|---|---|---|---|
| 2026-05-17 | Initial bootstrap | `OPERATOR_PHASE_A_HANDOFF.md` (planned this cycle) | 🚧 in progress |

---

## Refresh model

Bump the **Last updated** + **Last action** lines on every cycle. Move newly-completed items into Recently completed table (top row), mark with ✅ in their original section (keep visible for ≤ 5 cycles). New asks surface as 🆕 in section A or B.

---

## File-mediated coordination notes

This project has **no HMI agent counterpart** (single-process project — HMI authored manually on small UBP screens per plan Phase C). Handoff convention from v9 PM_Workspace still applies for any future cross-agent work.

If a sibling HMI agent ever spawns (e.g., separate project file for HMI source-of-truth), follow `plc-hmi-handoff-cycle` skill conventions.
