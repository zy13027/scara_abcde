# PLC_HANDOFF — 2026-05-22 — R6 Auto-cycle Pause step

**Status:** VERIFIED — R6 (auto-cycle Pause step) compiled + downloaded; PLCSIM-Adv smoke 2026-05-22 PASSED: Pause halts mid-move (step 75, axes enabled, joints frozen — 0.000 drift), resume continues the cycle (23 ABCDE point-transitions clean, no fault).

**From:** scara-PLC  **To:** scara-HMI
**Plan:** `C:\Users\Admin\.claude\plans\polished-wobbling-lagoon.md` — R6 section
**Authoritative binding contract:** `HMI_BINDING_MAP.md` Section 8

---

## 1. What R6 is

R6 — the last open item of the 2026-05-21 TIA review refactor checklist (R1–R6) — adds an
**auto-cycle Pause (暂停)** to both auto modes (ABCDE 5-point and palletizing). Pause is a
true mid-trajectory motion halt: the SCARA stops where it is, the axes stay **enabled and
hold position**, and the cycle **resumes the same move** from that point. Mechanism:
`MC_GroupInterrupt` (halt) / `MC_GroupContinue` (resume) on the kinematics group, owned by
`FB_AxisCtrl` (OB30). Structured Huashili-style — a `REGION Pause` + CASE step `75`.

## 2. HMI action — two new Pause buttons

| PLC path | Suggested widget | R/W | Pattern |
|---|---|---|---|
| `GDB_MachineCmd.bo_Pause` | `btnAutoPause` — Auto / ABCDE surface | W Bool | PULSE 250 ms |
| `GDB_PalletizingCmd.bo_Pause` | `btnPalletPause` — palletizing surface | W Bool | PULSE 250 ms |

- Both are **edge-triggered** (momentary) — use the same JS PULSE pattern as `btnStart` /
  `btnStop` (write TRUE, then FALSE after 250 ms).
- **Resume is the existing Start button** — no new binding. While the cycle is paused,
  pressing Start resumes it from the halt point.

## 3. Value-semantics change

`GDB_MachineCmd.i16_AutoStep` and `GDB_PalletizingCmd.i16_PalletStep` — the value set now
includes **`75`** (the pause-hold state). An IOField bound to either should read `75` as
"paused"; `75` is the recommended source for a Paused lamp / status text. No path change.

## 4. Unchanged

Every other binding is unchanged. `bo_Start` / `bo_Stop` / `bo_Mode` / `bo_ESTOP_LOCK` —
paths + semantics unchanged. Stop and E-Stop **override** Pause: a paused cycle still aborts
on Stop / E-Stop.

## 5. Status

`VERIFIED` (2026-05-22). The R6 PLC code (9 files — `FB_AxisCtrl` + iDB, both auto FBs + their
iDBs, the two command DBs, `UDT_typeKinCtrl`) compiled clean and downloaded; the PLCSIM-Adv
pause/resume smoke PASSED:

- Pause mid-move → `i16_AutoStep` = `75`, `bo_enabled` stays TRUE, the joints freeze (0.000
  drift over the hold) — a true mid-trajectory halt with the axes servo-holding position.
- Resume (Start) → leaves `75`, returns to the interrupted step; the cycle then ran on
  cleanly — 23 ABCDE point-transitions, no fault, no abort.

No HMI binding changed — the `bo_Pause` paths and the `75` value are stable. The HMI can
author the two Pause buttons against `HMI_BINDING_MAP.md` Section 8.
