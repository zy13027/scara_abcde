# PLC_HANDOFF — 2026-05-21 — Architectural Refactor → HMI binding deltas

**Status:** PENDING_VERIFICATION — Phases 1–6 authored + compile clean per phase (operator-confirmed); Phase 7 end-to-end sim regression still owed.

**From:** scara-PLC  **To:** scara-HMI
**Plan:** `C:\Users\Admin\.claude\plans\dazzling-squishing-sloth.md`
**Authoritative contract:** `HMI_BINDING_MAP.md` Section 7 (binding-delta list)

---

## 1. What changed

The `hmiDemoSCARA_ABCDE` PLC was restructured onto the Huashili layered architecture, per the
2026-05-21 TIA programming review. Six phases, each compiled clean (0 errors) before the next:

- **P1 — Layered folders.** `200_HMI_Comm` / `300_Alarm_IO` / `500_AutoCtrl` / `600_AxisCtrl`
  / `700_Palletizing`. Folder/group moves only — **no symbolic-path change**, no HMI impact.
- **P2 — DB consolidation.** `GDB_Control` (DB#3) retired; all axis I/O consolidated into
  `GDB_AxisCtrl` (DB#101).
- **P3 — Axis/kinematics layer in OB30.** `FB_AxisCtrl` rebuilt on the LKinCtrl library +
  new `FB_Init` (homing). Both run in **OB30** (CyclicInterrupt_10ms, 10 ms) — all Motion
  Control is now in OB30, decoupled from the OB1 process logic.
- **P4 — CASE auto FBs.** Both auto FBs rebuilt as Huashili-pattern CASE state machines:
  `FB_AutoCtrl_ABCDE` → **`FB_AutoCtrl_5Pts`** (renamed); `FB_AutoCtrl_Palletizing` rebuilt
  in place (V5.0). They command motion only by writing `GDB_AxisCtrl` — **zero MC in OB1**.
- **P5 — Cartesian jog.** Manual jog moved from per-joint `MC_MoveJog` to
  `LKinCtrl_MC_JogFrame` (WCS Cartesian frame), run from `FB_AxisCtrl` in OB30.
- **P6 — This handoff** + `HMI_BINDING_MAP.md` Section 7 + `FB_HMIStatusMirror` V0.2 repoint.

## 2. HMI binding deltas

Full detail is in `HMI_BINDING_MAP.md` **Section 7** — that section is authoritative; this is
the summary.

### 2.1 — Repoint (broken bindings)

`FB_AutoCtrl_ABCDE` is retired. The 4 target IOFields on `02_Auto_Ubp`:

| Old path | New path (recommended) |
|---|---|
| `instFB_AutoCtrl_ABCDE.statTargetPos.x` | `GDB_HMI_Status.target_x` |
| `instFB_AutoCtrl_ABCDE.statTargetPos.y` | `GDB_HMI_Status.target_y` |
| `instFB_AutoCtrl_ABCDE.statTargetPos.z` | `GDB_HMI_Status.target_z` |
| `instFB_AutoCtrl_ABCDE.statTargetPos.a` | `GDB_HMI_Status.target_a` |

Bind the **`GDB_HMI_Status` facade**, not the iDB directly — `FB_HMIStatusMirror` absorbs
future FB renames so the HMI never breaks on a PLC refactor again.

### 2.2 — Value-semantics changes (same path, new meaning)

- `GDB_MachineCmd.i16_AutoStep` — now the CASE state `0/10/20/30/50/100/110/200/230/800/900`
  (was `0/10/20/30/40/50`).
- `GDB_PalletizingCmd.i16_PalletStep` — now the CASE state (`0/10/.../900`), not the old
  `1..48` box-phase index.
- `GDB_HMI_Status.currentStep` / `totalSteps` — `FB_HMIStatusMirror` V0.2 now feeds a
  progress count: point index `1..5` (ABCDE) or boxes-placed `0..16` (palletizing), with
  `totalSteps` `5` / `16`. Recommended for an "N of M" progress display.

### 2.3 — Manual jog is now Cartesian

Jog is WCS Cartesian frame jog of the TCP. `bo_J{1..4}_Jog{Forward,Backward}` map to TCP
**X / Y / Z / A**. The command paths and `GDB_ManualStatus.*` are unchanged; only the jog
**meaning** changed. When the deferred jog widgets (`HMI_BINDING_MAP.md` §5.6) are wired,
label them X / Y / Z / A.

### 2.4 — Unchanged — safe to keep

`GDB_MachineCmd.{bo_Start,bo_Stop,bo_InitPath,bo_Mode,bo_ESTOP_LOCK}`, all of
`GDB_PalletizingCmd.*` / `GDB_ManualCmd.*` / `GDB_ManualStatus.*`, the `GDB_HMI_Status.*`
facade shape, and every TO tag (`J{n}_SCARA_Arm3D.*`, `ScaraArm3D.Position[]`).

## 3. HMI action list

1. Repoint the 4 `02_Auto_Ubp` target IOFields → `GDB_HMI_Status.target_{x,y,z,a}`.
2. Re-author the HMI tag table: drop / repoint any tag pointing at `instFB_AutoCtrl_ABCDE.*`.
3. Note the changed value sets of `i16_AutoStep` / `i16_PalletStep` if shown raw; prefer the
   `GDB_HMI_Status.currentStep` progress count.
4. When wiring the deferred manual-jog widgets, label them X / Y / Z / A (Cartesian).
5. Going forward: route ALL reads through the `GDB_HMI_Status` facade — it is rename-proof.

## 4. Not done yet (PLC side)

- **Phase 7** — full-system regression: ABCDE 5-point + 16-box palletizing + NX MCD co-sim,
  end-to-end. The PLC compiles clean per phase; the integrated sim run is still owed.
- `FB_AutoCtrl_ABCDE.scl` + `instFB_AutoCtrl_ABCDE` remain in the project (uncalled) until
  `FB_AutoCtrl_5Pts` is sim-verified, then they are deleted.

## 5. Notes

- The new shared interfaces — `GDB_AxisCtrl.LKinCtrl.input.movelinear` (auto-cycle linear
  move) and `…input.jogframe` (Cartesian jog) — are nested structs of LReal / Bool / Int;
  no `UNSUPPORTED_PLC_DENYLIST` patterns introduced.
- Palletizing trade-off: the CASE pattern serializes moves (each waits for done), so the old
  `BufferMode 5` cross-command blending is gone — slightly longer cycle, accepted for the
  clean Huashili structure.
