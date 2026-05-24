# PLC_HANDOFF — 2026-05-21 — Architectural Refactor → HMI binding deltas

**Status:** PENDING_VERIFICATION — Phases 1–6 compiled clean (operator-confirmed); Phase 7 sim regression — ABCDE 5-point + 16-box palletizing both VERIFIED (2026-05-22 PLCSIM-Adv); Cartesian jog test still owed.

**From:** scara-PLC  **To:** scara-HMI
**Plan:** `C:\Users\Admin\.claude\plans\polished-wobbling-lagoon.md`
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

## 4. Verification status (Phase 7)

Phase 7 = full-system PLCSIM-Adv regression. **Partial** as of 2026-05-22:

- ✅ **ABCDE 5-point cycle VERIFIED.** `FB_AutoCtrl_5Pts` runs end-to-end — `statPointIdx`
  cycles 1→5 and wraps, the SCARA moves point to point, Stop returns the CASE to step 0.
  The P3 (OB30 motion owner) + P4 (CASE auto FB) refactor is proven for the ABCDE path.
- ✅ **Palletizing 16-box cycle VERIFIED (2026-05-22).** The V5.0 stall — `FB_AutoCtrl_Palletizing`
  aborted at cmd 6 (the pick→place transit) on the near-base kinematic singularity — was
  fixed in Module 0: the long transits are now `MC_MoveDirectAbsolute` PTP moves
  (`FB_AutoCtrl_Palletizing` V5.2, `FB_AxisCtrl` V2.4). PLCSIM-Adv ran all 16 boxes across
  4 layers clean. **No HMI binding changes** — `GDB_PalletizingCmd.*` paths are stable.
- ⬜ **Cartesian jog not yet sim-tested.** The P5 `LKinCtrl_MC_JogFrame` path compiles clean;
  the X/Y/Z/A TCP-jog check is still owed — the one remaining Phase 7 item.

`FB_AutoCtrl_ABCDE.scl` + `instFB_AutoCtrl_ABCDE.xml` — **deleted 2026-05-22** (Module 0
retirement step; the block was uncalled, `FB_AutoCtrl_5Pts` is the verified production FB).

## 5. Phase 2 heads-up — screens coming, no action this cycle

The refactor clears the way for **Phase 2** (MCD co-sim, fine palletizing, recipe, teach,
dual-pallet). Listed here for HMI planning only — **none of this is authored yet, no bindings
to change now**:

- **Recipe screen (Phase 2 §5)** — recipe-selection + field-edit. New DBs to bind later: a
  `UDT_Recipe`-typed recipe-table DB + `GDB_ActiveRecipe`.
- **Teach-point table screen (Phase 2 §7)** — teach-point capture/edit table. New DB:
  `GDB_TeachPoints`.
- **Dual-pallet status (Phase 2 §6)** — pallet-1 / pallet-2 active + full indicators.

Each lands with its own `PLC_HANDOFF_*.md` (exact paths) once the PLC side is authored.
Nothing to do until then.

## 6. Notes

- The new shared interfaces — `GDB_AxisCtrl.LKinCtrl.input.movelinear` (auto-cycle linear
  move) and `…input.jogframe` (Cartesian jog) — are nested structs of LReal / Bool / Int;
  no `UNSUPPORTED_PLC_DENYLIST` patterns introduced.
- Palletizing trade-off: the CASE pattern serializes moves (each waits for done), so the old
  `BufferMode 5` cross-command blending is gone — slightly longer cycle, accepted for the
  clean Huashili structure.
