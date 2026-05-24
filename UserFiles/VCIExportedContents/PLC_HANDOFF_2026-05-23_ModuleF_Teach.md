# PLC_HANDOFF — 2026-05-23 — Module F V1.2: Teach mode (operator-driven jog + capture + replay, with joint-angle capture, jog-gate fix)

**Status:** VERIFIED (V1.2, 2026-05-23) — V1.2 patch deployed and smoke-tested green
on PLCSIM-Adv instance `DemoScara_ABCDE`: **24/24 PASS** post-V1.2 (no regression vs.
the V1.1 baseline; V1.2 fixed the FB_TeachCtrl jog-overwrite bug that broke manual jog
when Module F was deployed). All 11 smoke sections pass: preamble, TCP mirror, 4-way
mode mutex, V1.1 capture [TCP + joints], verify, single clear, multi-capture, replay
[walked slots 1→5→10 with bo_ReplayDone latching], stop mid-replay, ClearAll, restore.
Smoke script: `C:\Users\Admin\AppData\Local\Temp\scara_smoke_moduleF.ps1`.

The fix is one-FB scope (`FB_TeachCtrl.scl` REGION Cartesian_Jog wrapped in
`IF #statTeachOK THEN`); the smoke uses direct-motion bypass and so doesn't directly
exercise the jogframe path — manual operator validation of the V1.2 fix is the HMI
agent's, by jogging in manual mode after Module F is deployed (must work; would fail
silently under V1.0/V1.1).

`GDB_TeachPoints` + `GDB_TeachCmd` new in `750_Teach\`; `FB_TeachCtrl` V1.2 with 5
REGIONs: Mode_Gate, Cartesian_Jog (V1.2 fix), Operator_Actions, Replay_FSM,
Compute_PointCount; `FB_AxisCtrl` extended with `MirrorTCP` REGION to populate
`output.actualposition` from `ScaraArm3D.TcpInWcs.{x,y,z,a,b,c}.Position`; `Main.scl`
V3.3 with new `Teach_Cycle` REGION.

**V1.2 fix detail.** V1.0/V1.1 wrote 8 jogframe bits unconditionally each scan as
`#statTeachOK AND ...`. Since FB_TeachCtrl runs AFTER FB_ManualCtrl in OB1, FB_TeachCtrl's
FALSE writes (when teach off) overwrote FB_ManualCtrl's TRUE writes, silently breaking
manual jog whenever Module F was deployed. V1.2 wraps the 8 writes (plus the 4
hard-FALSE B/C-axis writes) in `IF #statTeachOK THEN ... END_IF`. When teach is off,
FB_TeachCtrl leaves jogframe alone; when teach is on, manual is mutex-blocked so
FB_TeachCtrl's writes are uncontested. No symmetric fix needed for FB_ManualCtrl
(FB_ManualCtrl runs first; its writes get overlaid by the later teach-mode writer in
teach mode, which is the intended behavior).

**V1.1 amendment (same-day, 2026-05-23)** — capture path extended to record BOTH
Cartesian TCP AND joint angles per the Chinese Phase 2 spec §7.1 (`捕获脉冲 → 当前 TCP/关节
写点表`). Replay still Cartesian-linear; joint-space PTP replay deferred. See §1.5
below for details.

**Remaining followup (pre-existing FB_ManualCtrl quirk, NOT introduced by Module F):**
`FB_ManualCtrl.Group_Enable_Home_Reset` auto-disables the axis when `statManualOK` is
TRUE and no enable button is held. This trips during HMI mode-switch races (e.g.
transitioning from manual to teach while no enable button is held). The smoke works
around this by using direct motion (bypass FB_ManualCtrl); for production HMI use,
FB_ManualCtrl should only write `input.bo_enable` when a button transitions or use a
latched "enable pending" state. Out of Module F scope.

**From:** scara-PLC  **To:** scara-HMI
**Plan:** `C:\Users\Admin\.claude\plans\replicated-forging-flamingo.md` (SCARA Phase 2 Module F)
**Authoritative binding contract:** `HMI_BINDING_MAP.md` Section 11

---

## 1. What Module F adds

A **4th mutex mode** — operator-driven teach. Operator enters teach mode, jogs the SCARA
TCP to wherever they want, captures the current pose into one of 16 slots, repeats, then
plays back the captured sequence. Coexists with the existing three modes (ABCDE auto,
palletizing, manual) via the same mutex pattern (`bo_Mode AND NOT other_modes`).

Module F also fixes a latent gap: `GDB_AxisCtrl.LKinCtrl.output.actualposition` was
declared but never written. `FB_AxisCtrl` now mirrors live TCP from
`ScaraArm3D.TcpInWcs.{x,y,z,a,b,c}.Position` (the Siemens-canonical TO_Kinematics member
for TCP-in-WCS, `TO_Struct_Kinematics_StatusKinematicsFrameWithDynamics`, V9.0 — same
access pattern `LKinCtrl_MC_JogFrame` uses internally) into that struct every OB30
scan — feeds FB_TeachCtrl capture and any future diagnostic that needs PLC-side
symbolic TCP access.

`FB_AutoCtrl_Palletizing` / `FB_PatternAutoGen` / `FB_AutoCtrl_5Pts` / `FB_ManualCtrl`
are **unchanged**. Module F only extends FB_AxisCtrl (8-line MirrorTCP REGION) and adds
new files.

## 1.5 V1.1 amendment — joint-angle capture (Phase 2 §7.1 "TCP/关节")

The Phase 2 Chinese spec line 99 says: `捕获脉冲 → 当前 TCP/关节 写点表` ("capture pulse →
current **TCP / joint** write to point table"). V1.0 captured TCP only — a valid reading
of the ambiguous `/` (typically "or" in Chinese tech docs) but not the maximal
interpretation. V1.1 captures **both**, so the spec is satisfied unambiguously.

| Change | What V1.0 had | What V1.1 adds |
|---|---|---|
| `GDB_TeachPoints` shape | `aPoints[1..16] of LKinCtrl_typePoint` only | + `aJointAngles : Array[1..16, 1..4] of LReal` (2D array — J1/J2/J3/J4 per slot; S7-1500T disallows nested Array-of-Array in interface declarations, same convention LKinCtrl_FrameTransTool's rotation matrices use) |
| `FB_TeachCtrl` Capture | Wrote TCP only | Also writes joint angles from `"ScaraArm3D".AxesData.A[1..4].Position` -- same source `FB_MCDDataTransfer` uses |
| `FB_TeachCtrl` Clear / ClearAll | Zeroed `aPoints` only | Also zeros `aJointAngles` |
| `FB_TeachCtrl` Capture also fills `aPoints.position[4]` / `[5]` | Were hard-zeroed | Now populated from `actualposition.b/c` (TO solver fills based on joint posture) |
| Replay path | Cartesian linear via `aPoints` | **Unchanged** — Cartesian linear (V1.0 behavior preserved). Joint-space PTP replay using `aJointAngles` is reserved for a future extension (per-slot `bo_IsPTP` flag would route into the existing `movelinear.bo_isPTP` route). |

**Why archival-only joint replay for now:** The shared `movelinear` interface accepts
`bo_isPTP := TRUE` which routes through `MC_MoveDirectAbsolute` (joint-space), but the
target is still Cartesian (the kinematics solver derives the joint motion). Truly
joint-space teach-replay (operator hand-jogs to a singular pose, replays with the same
joint configuration regardless of IK ambiguity) would need a separate motion path. Out
of scope for V1.1; joints are captured for archival + future use.

**HMI implication:** add an optional "joints" view on the teach-table screen — operators
who want to inspect joint posture per slot can see it; operators who only care about
Cartesian don't need to look.

## 2. Data shape — reuses LKinCtrl_typePoint, no new UDT

Module F intentionally **reuses the Siemens-canonical `LKinCtrl_typePoint`** UDT
(`PLC data types\LKinCtrl_Types\LKinCtrl_typePoint.xml`) for each teach slot — that
gives operator singularity hints (`linkConstellation` + `turnJoint`) for free, even
though the 4-DoF SCARA doesn't strictly need them today. No new UDT.

New DBs at `Program blocks\750_Teach\`:

- `GDB_TeachPoints` (DB 26, Retain): `aPoints[1..16] of LKinCtrl_typePoint` (Cartesian),
  `aJointAngles : Array[1..16, 1..4] of LReal` (V1.1 2D array — joint angles J1-J4 per
  slot, accessed as `aJointAngles[slot, joint]`),
  `abCaptured[1..16] of Bool`, `i16_PointCount : Int` (FB-computed).
- `GDB_TeachCmd` (DB 27): operator commands (`bo_Mode`, `bo_ESTOP_LOCK`, `i16_SlotIdx`,
  edge-pulsed `bo_Capture` / `bo_Verify` / `bo_Clear` / `bo_ClearAll` /
  `bo_StartReplay` / `bo_StopReplay`, `lr_ReplayVel`) + FB status echoes
  (`i16_TeachStep`, `i16_ReplayIdx`, `bo_ReplayDone`).
- `instFB_TeachCtrl` (DB 28): instance for `FB_TeachCtrl` (7× R_TRIG + statTeachOK).

## 3. HMI action — author teach screen + 4-way mode radio + capture/verify/replay UI

### 3.1 Mode toggle

The four mode bits (`GDB_MachineCmd.bo_Mode`, `GDB_PalletizingCmd.bo_Mode`,
`GDB_ManualCmd.bo_Mode`, `GDB_TeachCmd.bo_Mode`) should be a **single-selection radio**
on the HMI — operator can only have one TRUE at a time. PLC defensively enforces
mutex internally; HMI radio prevents the operator from creating temporary stalemates.

### 3.2 Teach screen

A new UBP screen (~5 controls budget; multi-screen / paged if needed):

- **Slot table** (4 of 16 slots visible at a time, with paging up/down): per row, show
  `aPoints[i].position[0..3]` (X/Y/Z/A) and `abCaptured[i]` (filled vs empty icon).
- **Slot selector** IOField bound to `GDB_TeachCmd.i16_SlotIdx` (1..16).
- **Capture button** — JS PULSE pattern (`Write true` → `setTimeout 250ms → Write
  false`) on `GDB_TeachCmd.bo_Capture`.
- **Verify button** — same PULSE pattern on `bo_Verify`. Robot moves to the slot at
  `lr_ReplayVel`.
- **Clear / Clear All buttons** — PULSE on `bo_Clear` / `bo_ClearAll`.
- **Replay controls**: Start (PULSE `bo_StartReplay`), Stop (PULSE `bo_StopReplay`),
  velocity IOField (`lr_ReplayVel`), status IOFields (`i16_ReplayIdx`,
  `i16_PointCount`, `bo_ReplayDone` lamp).
- **Live TCP display**: 4 IOFields bound to `GDB_AxisCtrl.LKinCtrl.output.actualposition.
  {x,y,z,a}` (new in Module F). Operator sees the live TCP they're about to capture.

### 3.3 Jog buttons are SHARED

The same HMI jog buttons (`GDB_ManualCmd.bo_J{1..4}_JogForward/Backward`) drive the
robot in both manual and teach mode. `FB_TeachCtrl` REGION `Cartesian_Jog` copies the
manual jog wiring with the teach-mode gate substituted. **No new jog tags.** If the HMI
prefers a dedicated teach screen, mirror or link the existing manual-screen jog buttons
into the teach screen.

### 3.4 Update `HMI_BINDING_MAP.md`

Section 11 has been added with the full Module F binding tables (Sub-sections 11.1
through 11.8). HMI agent rebuilds the tag table + teach screen against it.

## 4. Mutex / completion semantics (precise)

`FB_TeachCtrl` each scan:

1. **Mode_Gate**: `statTeachOK := bo_Mode AND bo_ESTOP_LOCK AND NOT GDB_MachineCmd.bo_Mode
   AND NOT GDB_PalletizingCmd.bo_Mode AND NOT GDB_ManualCmd.bo_Mode`. On mode exit
   (gate falls), reset `i16_TeachStep := 0`, `i16_ReplayIdx := 0`, `bo_execute := FALSE`.
   Also run all 7× R_TRIG edge detectors (they must see edges in real-time to not miss
   pulses).
2. **Cartesian_Jog**: 8 jog bits (X+/X-/Y+/Y-/Z+/Z-/A+/A-) ANDed with `statTeachOK` and
   the corresponding `GDB_ManualCmd.bo_J{n}_Jog{Forward,Backward}` HMI buttons. XOR
   safety (both pressed → neither wins). B/C held FALSE (4-DoF).
3. **Operator_Actions**:
   - Capture (edge + gate + idx in range): copies `output.actualposition.{x,y,z,a}` →
     `aPoints[idx].position[0..3]`, zeros [4..5], sets `coordSystem := 0` (WCS), sets
     `abCaptured[idx] := TRUE`, flashes `i16_TeachStep := 10` for one scan.
   - Verify (edge + gate + idx in range + abCaptured[idx]=TRUE): writes slot to
     `movelinear.targetposition`, dynamics from `lr_ReplayVel` + 2000 accel/decel +
     20000 jerk, pulses `bo_execute`, sets `i16_TeachStep := 20`. Move-done edge
     clears `bo_execute` and `i16_TeachStep`.
   - Clear (edge + gate + idx in range): zeros slot fields, `abCaptured[idx] := FALSE`.
   - ClearAll (edge + gate): loops 1..16 clearing all.
4. **Replay_FSM**:
   - StartReplay edge (in idle, `i16_PointCount > 0`): clear `bo_ReplayDone`, set
     `i16_ReplayIdx := 0`, transition to state 100.
   - State 100 (LOAD_NEXT): scan forward from `idx+1` for next `abCaptured=TRUE` slot.
     If none found → state 200. Otherwise → state 110.
   - State 110 (WRITE_TARGET): copy slot to `movelinear.targetposition`, pulse
     `bo_execute`, → state 120.
   - State 120 (WAIT_DONE): on move-done edge, clear `bo_execute`, → state 100 (load
     next).
   - State 200 (DONE): latch `bo_ReplayDone := TRUE`, `i16_ReplayIdx := 0`,
     → state 0 (idle).
   - StopReplay edge from states 100/110/120: clear `bo_execute`, `i16_TeachStep := 0`,
     `i16_ReplayIdx := 0`. Move aborts via MC layer's `bo_commandaborted`.
5. **Compute_PointCount**: `i16_PointCount := COUNT of TRUE in abCaptured[1..16]`.
   Always runs (NOT gated) so HMI status display tracks even when teach mode is off.

## 5. What is NOT in Module F (deferred)

- **Per-point velocity / dwell / gripper actions** — single `lr_ReplayVel` for all moves.
- **Joint-space teach** — `coordSystem := 0` (WCS) only; `LKinCtrl_typePoint`'s OCS
  variants unused.
- **Save / load teach files** — Retain memory only (survives power cycle but not
  destructive download). HMI-side "save to SD" via PSC is a followup.
- **PSC handshake** — points are PLC-internal writes (no race), no `bo_Valid` gate.
- **Singularity hints** — `linkConstellation` left at default `16#FFFF_FFFF` (let
  solver choose), `turnJoint[..]` at 0. If a teach point lands in a singularity-
  sensitive pose and replay fails, operator-configurable hints become the followup.
- **Mode radio enforcement** — HMI client-side; PLC defensively gates regardless.
- **NX-MCD co-sim of taught replay** — Module G concern.

## 6. Verification

1. **Operator deploy:** VCI-sync → compile → MRES → download. MRES recommended — new
   DBs added (`GDB_TeachPoints`, `GDB_TeachCmd`, `instFB_TeachCtrl`) and `FB_AxisCtrl`
   shape changed (new REGION). `LKinCtrl_typePoint` UDT unchanged, so existing taught
   data from any prior session is bit-compatible at the UDT level (though there's
   no prior session — Module F is new).
2. **PLCSIM-Adv smoke** (instance `DemoScara_ABCDE`, script
   `C:\Users\Admin\AppData\Local\Temp\scara_smoke_moduleF.ps1` — to be authored):
   - **A. Preamble** — axis enable + home.
   - **B. TCP mirror** — confirm `GDB_AxisCtrl.LKinCtrl.output.actualposition.{x,y,z,a}`
     tracks `ScaraArm3D.Position[1..4]` after homing.
   - **C. Mutex enforcement** — set all 4 modes TRUE simultaneously → confirm
     `statTeachOK` FALSE. Clear competing → confirm TRUE.
   - **D. Capture (V1.1)** — jog (or write LKinCtrl.input.movelinear directly via manual
     mode) to known TCP; switch to teach mode; `i16_SlotIdx := 3`; pulse `bo_Capture`;
     confirm `aPoints[3].position[0..3]` matches live TCP, `aJointAngles[3, 1..4]`
     matches the live joint angles (`ScaraArm3D.AxesData.A[1..4].Position`),
     `abCaptured[3] = TRUE`, `i16_PointCount = 1`.
   - **E. Verify** — pulse `bo_Verify`; confirm `movelinear.targetposition` set to
     slot 3, `bo_execute` pulses, move completes via `bo_done`.
   - **F. Clear single** — pulse `bo_Clear` → slot 3 zeroed, `abCaptured[3] = FALSE`.
   - **G. Multi-capture** — capture 3 distinct slots (e.g. 1, 5, 10); confirm
     `i16_PointCount = 3`.
   - **H. Replay** — pulse `bo_StartReplay`; confirm `i16_ReplayIdx` advances
     1 → 5 → 10 → 0; `bo_ReplayDone` latches TRUE.
   - **I. Stop mid-replay** — pulse `bo_StopReplay` mid-way; confirm
     `i16_ReplayIdx := 0`, `bo_execute := FALSE`.
   - **J. ClearAll** — capture some slots, pulse `bo_ClearAll`, confirm all clear.
   - **K. Restore** — clear teach mode, restore default operator state.
3. **HMI-side teach screen authoring** — scara-HMI's, after this handoff.

## 7. Forward-looking — ABCDE deletion cleanup

Per operator directive, `GDB_MachineCmd.bo_Mode` (ABCDE auto) is a transitional demo
slated for future removal. Module F's `statTeachOK` includes `NOT GDB_MachineCmd.bo_Mode`
for symmetry with the existing three mode FBs; when ABCDE is deleted, the same one-term
strip applies to `FB_TeachCtrl`, `FB_ManualCtrl`, and `FB_AutoCtrl_Palletizing` (plus
removing `instFB_AutoCtrl_5Pts()` from `Main.scl`). Module F does not introduce any new
dependencies on ABCDE — only the symmetric mutex term, which becomes a no-op when ABCDE
goes away.
