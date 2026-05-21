**Status:** PENDING_VERIFICATION → operator (NX suction-cup fix + VCI-sync runbook) + scara-HMI (ABCDE re-test ACK + cycle-7.7 tag map). **TIA target:** `hmiDemoSCARA_ABCDE.ap20`. **Predecessors:** `PLC_HANDOFF_2026-05-19_FullSimulationFitOut_BoxOrchestratedPalletizing.md` (V3.0 design) + `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_ConveyorAndSensors.md` (5 GDB_MCDData Members) + `HMI_HANDOFF_2026-05-19_Cycle7_6_IssueA_Closed_PlcReTestReady.md` (scara-HMI re-test trigger).

# PLC Handoff 2026-05-21 — Palletizing V4 buffered-path executor + suction-cup capture blocker (NX-side) + ABCDE/HMI auto-control verified

PM bookkeeping catch-up for the 2026-05-20→21 scara-PLC work (no handoff since 2026-05-19). Three threads: **(A)** palletizing FB rewritten V3.0 → V4.2 buffered-path; **(B)** suction-cup capture is broken — an NX-side blocker, the demo's one open fault; **(C)** the ABCDE "Auto" cycle + HMI co-sim drive path verified.

## §1 — Thread A: Palletizing FB → V4.2 buffered-path executor

The V3.0 design from `_FullSimulationFitOut_` (inline 6-phase-per-box state machine) was superseded by a **buffered-path architecture**:

| File | Change |
|---|---|
| `500_AutoCtrl/FB_AutoCtrl_Palletizing.scl` | Rewritten V3.0 → **V4.2**. REGION 1 = command-list builder (pre-computes the full pick→place command sequence into a path DB); REGION 4 = buffered-path executor (steps the list, one `MC_MoveLinearAbsolute` per scan). V4.1 dropped the infeed segment. |
| `500_AutoCtrl/GDB_PalletizingPath.xml` | **NEW** GDB — holds the built command list. |
| `PLC data types/UDT_PathCmd` | **NEW** UDT — one path-command record (target pose + cmd type). |
| `500_AutoCtrl/FB_ConveyorCtrl.scl` + `instances/instFB_ConveyorCtrl.xml` | **NEW** FB — drives `GDB_MCDData.BeltVelocity`. OB1 call added to `100_OB/Main.scl`. |
| `500_AutoCtrl/GDB_PalletizingCmd.xml` | Pick coords corrected — see §2. |

All six new/modified block files confirmed present on disk. Smoke (`harness/SmokeTest_PalletizeOrchestrated_V3.ps1`) **reported 16/16** cycle-completion in phantom and real mode — `statBoxesPlaced` reaches 16, `bo_PalletDone` = TRUE, no `16#80B2` / OB91 overflow / FAULT. The earlier `16#80B2` (BufferMode invalid) was fixed: BufferMode 0→1 on the 4 `MC_MoveLinearAbsolute` calls.

⚠️ **"16/16" is a cycle-counter pass, NOT a working demo** — see §2.

## §2 — Thread B: Suction-cup capture FAILS — NX-side blocker `[NEEDS_HUMAN]`

The palletizing cycle runs the full pick→place path and counts 16 boxes, but **the SCARA pantomimes** — the `Suction_Cup_Gripper` never attaches `rbContainer_1`, so no carton is physically picked or stacked.

- **PLC side verified correct** — cross-checked against the Siemens LSKI reference (`LSKI_V4_1_0_GettingStarted_TiaPrj_V20/Vci`): the Grip/Release/HasGripped triple matches LSKI's `saScara` pattern; `sScaraGrip ← GDB_Control.bo_gripperGrip` and `sScaraRelease ← GDB_Control.bo_gripperRelease` are mapped (green in MCD Signal Mapping).
- **Break is NX-internal** — `sScaraGrip` reaches NX but the gripper behavior does not attach the box. Confirmed empirically: with the cup in contact and grip TRUE, the grab still fails.
- **Pick coords corrected** in `GDB_PalletizingCmd.xml`: `lr_PickX` 1170.44 → **1269.07**, `lr_PickZ` → **−919.86** (box-COM-derived: COM 1269.07 / −468.28 / −973.61, box top = −919.86). `lr_PickY` ≈ −468 unchanged.
- **`GDB_MCDData.ScaraHasGrippedObj`** (Bool, MCD→PLC) added — grip-success feedback for the NX gripper's `sScaraHasGrippedObj` output. Structural DB change → **MRES required** on next download.

Fix plan: `~/.claude/plans/dazzling-squishing-sloth.md` — replicate LSKI's working SCARA gripper attach in the NX scene. **NX-side; operator / NX agent owns it.** Until it lands, the palletizing demo is not functional.

## §3 — Thread B.2: Pointless tool-path / J1 modulo whip `[NEEDS_HUMAN re-test]`

Joint traces showed J1 (base rotation, a modulo axis) whipping ~184° through the 360°/0° wrap on every pick→place (J1 travelled ~270° for a ~95° net move; the J4 wrist mirrored it). Root cause: pick and place sit in opposite quadrants, forcing the modulo wrap.

Operator-applied TO-config fix: **J1 modulo disabled** + SW position limits set — J1 ±160°, J2 −1820/+600 mm, J3 ±134°. **Re-test still owed** — a one-box real-mode trace (`harness/Trace_OneBox.ps1 -Real`) will confirm J1 no longer whips and that J3 (±134°) / J2 (−1820 mm) do not fault on the pick descent.

## §4 — Thread C: ABCDE "Auto" cycle + HMI co-sim drive — VERIFIED `[INFO]`

Operator asked whether the HMI can drive the ABCDE auto cycle in MCD co-sim. Confirmed YES — and clarified for scara-HMI's cycle-7.7 header-strip work:

- The **Auto** tab drives `FB_AutoCtrl_ABCDE` — pure 5-waypoint motion (a square at Z=400 mm, no gripper). It is independent of the **Pallet** tab (`FB_AutoCtrl_Palletizing`); the suction-cup blocker (§2) does **not** affect the ABCDE cycle.
- HMI and MCD are independent clients of the same PLCSIM-Adv PLC — no co-sim conflict.

**`GDB_MachineCmd` command-bit semantics** (for HMI button + lamp authoring):

| Tag | Trigger | Status tag the HMI reads back |
|---|---|---|
| `bo_InitPath` | **rising-edge** (R_TRIG) | `bo_PathInitialed` → PATH READY lamp |
| `bo_Start` | **rising-edge** (R_TRIG) | `i16_AutoStep <> 0` → RUNNING (no dedicated Bool) |
| `bo_Stop` | **rising-edge** (R_TRIG) | `i16_AutoStep = 0` → idle (no dedicated Bool) |
| `bo_Mode` | **level** permissive | `bo_Mode` itself → AUTO MODE lamp |

⇒ HMI: Start / Stop / InitPath want momentary (push) buttons; Mode wants a maintained toggle. Start/Stop have **no dedicated status Bool** — the RUNNING lamp must be an `i16_AutoStep` comparison. If scara-HMI prefers a clean 1:1 `bo_Running` lamp tag, that is a 1-member `GDB_MachineCmd` add (structural → MRES). No code change was made this session — §4 is investigation/Q&A only.

## §5 — scara-HMI Cycle 7.6 re-test trigger — STATUS

`HMI_HANDOFF_2026-05-19_Cycle7_6_IssueA_Closed_PlcReTestReady.md` §5 asked scara-PLC to run the ABCDE 5/5 smoke (observe `ioautoStep` 0→10→…→50→10 numeric + `iotgtX/Y/Z/A` live LReal) to flip cycle-7.6 PENDING_VERIFICATION → VERIFIED.

**Not run this session** — operator priority was the palletizing suction-cup blocker. The §5 re-test is **carried forward** `[NEEDS_scaraPLC]`. Nothing here contradicts Issue A's IOField/TagDynamization fix; it simply has not been runtime-confirmed yet.

## §6 — Operator runbook (owed before any re-test)

1. NX: fix the `Suction_Cup_Gripper` attach (§2) + add the `sScaraHasGrippedObj` → `GDB_MCDData.ScaraHasGrippedObj` mapping.
2. VCI-sync `FB_AutoCtrl_Palletizing.scl` + `GDB_PalletizingPath.xml` + `FB_ConveyorCtrl.scl` + `UDT_PathCmd` + `GDB_PalletizingCmd.xml` + `GDB_MCDData.xml` + the iDBs + `Main.scl` → TIA Compile (expect 0E/0W).
3. PLCSIM-Adv `DemoScara_ABCDE` → **MRES** (structural DB changes) → Download.
4. Confirm J1 modulo disabled in the TO editor (§3).
5. Re-test: `Trace_OneBox.ps1 -Real` (one box) → then `SmokeTest_PalletizeOrchestrated_V3.ps1 -RealMode` (16 box).

## §7 — Closure markers

- `[NEEDS_HUMAN]` NX `Suction_Cup_Gripper` attach fix — **the demo blocker** (§2)
- `[NEEDS_HUMAN]` operator VCI-sync + MRES + download runbook (§6)
- `[NEEDS_HUMAN]` operator confirm J1 modulo disabled + one-box re-test (§3)
- `[NEEDS_scaraPLC]` ABCDE 5/5 smoke per scara-HMI Cycle 7.6 §5 — carry-forward (§5)
- `[INFO]` ABCDE/HMI edge-vs-level + button→status-tag map for scara-HMI cycle-7.7 header strip (§4)
- `[GAP]` catch-up #3 backlog (~30 untracked files incl. this thread) still uncommitted; SCARA repo has no git remote — operator owes a remote URL + per-push auth before catch-up #3 can land. Count-evidence per AGENT_CONTRACT §5.4 (`git diff --stat`, smoke-log paths) owed at commit time.

## §8 — Cross-references

- `~/.claude/plans/dazzling-squishing-sloth.md` — the suction-cup + tool-path fix plan
- `PLC_HANDOFF_2026-05-19_FullSimulationFitOut_BoxOrchestratedPalletizing.md` — superseded V3.0 design
- `FB_AutoCtrl_ABCDE.scl` + `GDB_MachineCmd.xml` — §4 source of truth
- LSKI reference: `E:\TIA_V20_Demo_Proj\LSKI_V4_1_0_GettingStarted_TiaPrj_V20\Vci`

End of PLC Handoff 2026-05-21.
