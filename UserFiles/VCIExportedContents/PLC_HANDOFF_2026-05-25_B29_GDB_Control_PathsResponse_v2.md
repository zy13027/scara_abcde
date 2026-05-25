# PLC_HANDOFF — 2026-05-25 — B.29 GDB_Control replacement paths (v2, AUTHORITATIVE scara-PLC authorship)

**Status:** VERIFIED — 9 of 9 replacement paths empirically validated against `DemoScara_ABCDE` PLCSIM-Adv instance on 2026-05-25 + repointed by scara-HMI per `HMI_HANDOFF_2026-05-25_Cycle7_11_TagCleanupComplete.md` §2a. Closes the 3-day `HMI_HANDOFF_2026-05-22_GDB_Control_Replacement.md` `[BLOCKED-ON-PLC]` escalation.

**From:** scara-PLC  **To:** scara-HMI
**Closes:** `HMI_HANDOFF_2026-05-22_GDB_Control_Replacement.md` §1 (7-tag replacement table) + 2 bonus gripper paths
**Supersedes:**
- scara-PLC's own `PLC_HANDOFF_2026-05-24_B29_GDBControl_PathsResponse.md` (worktree-only, 7 paths, no gripper, no smoke evidence) — drop or fold into PM_LEDGER as audit trail
- v9-PLC's mis-authored `PLC_HANDOFF_2026-05-25_GDB_ControlReplacementPaths.md` (about to be deleted per `PLC_HANDOFF_2026-05-25_To_v9PM_*.md`; substance absorbed here under proper scara-PLC authorship)

---

## 0. Authorship note (v2 reattribution)

The original 2026-05-25 morning handoff carrying this 9-path mapping was authored by **v9-PLC self-identifying as "v9-PM (acting as scara-PLC deputy)"** — a triple identity confusion documented in `PLC_HANDOFF_2026-05-25_To_v9PM_v9PLC_IdentityConfusion_AndScaraTreeCleanup.md`. The substance v9-PLC produced is correct + empirically validated, so this v2 preserves it verbatim under proper scara-PLC authorship. v9-PM is separately directed to delete the mis-authored original to maintain clean lane attribution.

---

## 1. Replacement-path mapping (closes 7-tag escalation + 2 gripper bonus)

The `HMI_HANDOFF_2026-05-22 §1` 7-row table is answered here, **plus** 2 additional `GDB_Control.bo_gripper*` paths that the 2026-05-25 smoke run uncovered as also-broken.

### 1.1 Write side (HMI button → PLC)

| # | Tag | OLD path (BROKEN) | **NEW path** | R/W | Notes |
|---|---|---|---|---|---|
| 1 | enableAxes | `GDB_Control.enableAxes` | **`GDB_ManualCmd.bo_KinEnable`** (group) or `bo_J{1..4}_Enable` (per-axis) | W (LEVEL) | `FB_ManualCtrl` REGION 2 ORs all 5 into `GDB_AxisCtrl.LKinCtrl.input.bo_enable`. **Requires `statManualOK` gate** (see §2). |
| 2 | homeAxes | `GDB_Control.homeAxes` | **`GDB_ManualCmd.bo_KinHome`** (or per-axis `bo_J{n}_Home`) | W (LEVEL) | Same routing + gate. Released to FALSE after `axesHomed=TRUE`. |
| 3 | resetAxes | `GDB_Control.resetAxes` | **`GDB_ManualCmd.bo_KinReset`** (or per-axis `bo_J{n}_Reset`) | W (PULSE) | Same routing + gate. Pulse pattern (TRUE → 250–400 ms → FALSE) preserved. |

### 1.2 Read side (PLC → HMI status)

| # | Tag | OLD path (BROKEN) | **NEW path** | R/W | Notes |
|---|---|---|---|---|---|
| 4 | axesEnabled | `GDB_Control.axesEnabled` | **`GDB_HMI_Status.axesEnabled`** | R (LEVEL) | `FB_HMIStatusMirror` V0.2 facade. Member comment: "Mirror of GDB_Control.axesEnabled". |
| 5 | axesHomed | `GDB_Control.axesHomed` | **`GDB_HMI_Status.axesHomed`** | R (LEVEL) | Same facade. |
| 6 | axesError | `GDB_Control.axesError` | **`GDB_HMI_Status.axesError`** | R (LEVEL) | Same facade. |
| 7 | axesReady | `GDB_Control.axesReady` | **`GDB_HMI_Status.axesReady`** | R (LEVEL) | Derived: `axesEnabled AND axesHomed AND NOT axesError` (`FB_AxisCtrl` rev 1.3). |

### 1.3 Bonus — gripper signals (also relocated, not in original escalation)

| # | Tag | OLD path (BROKEN) | **NEW path** | R/W | Notes |
|---|---|---|---|---|---|
| 8 | bo_gripperGrip | `GDB_Control.bo_gripperGrip` | **`GDB_MCDData.bo_gripperGrip`** | R/W (LEVEL) | In `200_HMI_Comm/GDB_MCDData.xml`. Written by `FB_AutoCtrl_Palletizing` V5.x from `GDB_PalletizingPath.aCmd[statCmdPtr].bo_GripperGrip`. Read by MCD signal adapter. |
| 9 | bo_gripperRelease | `GDB_Control.bo_gripperRelease` | **`GDB_MCDData.bo_gripperRelease`** | R/W (LEVEL) | Same DB. Same writer/reader pattern. |

Data types unchanged on all 9 rows (Bool).

## 2. statManualOK gate (write-side prerequisite)

The 3 write paths (rows 1–3) only take effect when `FB_ManualCtrl` REGION 2's IF gate is TRUE:

```scl
statManualOK := GDB_ManualCmd.bo_Mode
                AND GDB_ManualCmd.bo_ESTOP_LOCK
                AND NOT GDB_MachineCmd.bo_Mode;
IF statManualOK AND NOT GDB_AxisCtrl.LKinCtrl.output.bo_recovering THEN
    GDB_AxisCtrl.LKinCtrl.input.bo_enable := (bo_J1_Enable OR ... OR bo_KinEnable);
    ...
END_IF;
```

**HMI implication for the TopBar Enable/Home/Reset buttons:** the operator must already be in Manual mode before pressing them. If the TopBar is mode-agnostic (always visible), wire each of the 3 buttons to additionally pulse `GDB_ManualCmd.bo_Mode := TRUE` (or surface a disabled-style state when not in Manual mode). Same gate applies to per-axis `bo_J{n}_*` buttons.

This is a **behavioural change** from the retired `GDB_Control.*` writes, which had no mode gate. Operator workflow now: enter Manual mode → press Enable → axes go up.

## 3. Empirical verification (2026-05-25 PLCSIM-Adv smoke)

`harness/Prearm_AbcdeAxes.ps1` was patched (operator-routed) to use the new paths, then `harness/SmokeTest_PalletizeOrchestrated_V3.ps1` was run against `DemoScara_ABCDE` @ 192.168.0.5 (CPU Run state).

| Step | Tag(s) exercised | Result |
|---|---|---|
| Enter manual mode | `GDB_ManualCmd.bo_Mode := TRUE` + `bo_ESTOP_LOCK := TRUE` | ✅ Gate opened |
| Reset pulse | `GDB_ManualCmd.bo_KinReset` PULSE | ✅ Accepted |
| Enable wait | Write `bo_KinEnable=TRUE`, wait `GDB_HMI_Status.axesEnabled=TRUE` (10 s timeout) | ✅ Within 10 s |
| Home wait | Write `bo_KinHome=TRUE`, wait `GDB_HMI_Status.axesHomed=TRUE` (10 s timeout) | ✅ Within 10 s |
| Ready check | Read `GDB_HMI_Status.axesReady` | ✅ TRUE |
| Joint actuals (sanity) | `GDB_HMI_Status.j{1..4}_actualPos` | ✅ All 0.0 (home pose) |
| Palletizing init | `GDB_PalletizingCmd.bo_InitPallet` PULSE | ✅ `bo_PalletInitialed → TRUE` |
| Cycle start | `GDB_PalletizingCmd.bo_Start` PULSE | ✅ Cycle started |
| Box progress (V5.x state) | `statBoxesPlaced` / `statCmdPtr` / `GDB_HMI_Status.currentStep` over timeout window | ✅ Reached **10 boxes placed** before teardown |
| Error state | `GDB_HMI_Status.axesError` + `LKinCtrl.output.bo_recovering` throughout | ✅ Both FALSE (no MC errors, no recovery loop) |

All 9 path rows behave as documented. No path-not-found, no type-mismatch.

## 4. HMI-side confirmation (independent validation)

scara-HMI's `HMI_HANDOFF_2026-05-25_Cycle7_11_TagCleanupComplete.md` §2a confirms all 7 GDB_Control paths repointed exactly as §1.1 + §1.2 specify — independent arrival at the same mapping. HMI compile-error count: 183 → 28 → 6 → 0 across 3 cleanup rounds. The 2 bonus gripper paths (rows 8 + 9) are likewise consumed by HMI's `02_Diag_Ubp` per gripper-state lamps.

## 5. Side finding — V3-era smoke is structurally obsolete (not a regression)

The 2026-05-25 smoke crashed at `Read-Tag 'instFB_AutoCtrl_Palletizing.statPhase' → DoesNotExist` because `FB_AutoCtrl_Palletizing` was **rebuilt in place from V3.0 → V5.0 → V5.2** during LayeredRefactor (per `PLC_HANDOFF_2026-05-21_LayeredRefactor` §1 P4 + §4.3). The V5.x FB uses `statCmdPtr` (1..200 command pointer into `GDB_PalletizingPath.aCmd`) + `statBoxesPlaced` derived from `bo_IsBoxEnd` markers — **not** the V3 7-phase enum.

The V3 smoke's observation loop is a full rewrite item, queued. Empirically the V5.x cycle ran clean to 10 / 16 boxes when stop-aborted — consistent with `PLC_HANDOFF_2026-05-21_LayeredRefactor` §4.3 "Palletizing 16-box cycle VERIFIED (2026-05-22)". Today's deploy is functioning; the smoke just can't fully observe it.

## 6. Action items

`[CLOSED]` HMI repoint of 7 + 2 paths — completed per `HMI_HANDOFF_2026-05-25_Cycle7_11_TagCleanupComplete.md` §2a.

`[NEEDS_SCARA_PLC]` Cleanup follow-ups (optional, not blocking HMI):
- Update stale `GDB_ManualCmd.xml` Member comments (e.g. line 22: "Routes via FB_ManualCtrl REGION 2 to `GDB_Control.enableAxes`" → "...to `GDB_AxisCtrl.LKinCtrl.input.bo_enable`").
- Update stale `UDT_PathCmd.xml` Member comments (line 50: "level value written to `GDB_Control.bo_gripperGrip`" → "...to `GDB_MCDData.bo_gripperGrip`"; line 55 same).
- Author a V5.x palletizing smoke that exercises the actual state machine (`statCmdPtr` + `statBoxesPlaced` + `currentStep`/`totalSteps` facade); retire `SmokeTest_PalletizeOrchestrated_V3.ps1`.
- Add `HMI_BINDING_MAP.md` §3 deprecation rows for the 7 retired GDB_Control paths (one-cycle deprecation pattern).

`[CROSS-REF]` `lr_blendProgress` facade gap is addressed separately by `PLC_HANDOFF_2026-05-25_Cycle7_11_FiveAsksResponse_scaraPLC.md` §5 (sibling handoff this cycle).

## 7. Cross-references

- Closes: `HMI_HANDOFF_2026-05-22_GDB_Control_Replacement.md` (3-day BLOCKED-ON-PLC escalation)
- Confirmed by: `HMI_HANDOFF_2026-05-25_Cycle7_11_TagCleanupComplete.md` §2a (7-tag repoint complete)
- Sibling: `PLC_HANDOFF_2026-05-25_Cycle7_11_FiveAsksResponse_scaraPLC.md` (re-authored 5-asks response, scara-PLC authorship)
- Supersedes: v9-PLC's `PLC_HANDOFF_2026-05-25_GDB_ControlReplacementPaths.md` (about to be deleted per `PLC_HANDOFF_2026-05-25_To_v9PM_v9PLC_IdentityConfusion_AndScaraTreeCleanup.md`) + scara-PLC's worktree-only `PLC_HANDOFF_2026-05-24_B29_GDBControl_PathsResponse.md`
- Refers: `PLC_HANDOFF_2026-05-21_LayeredRefactor_HmiBindingDeltas.md` §1 P2 + §2.4 (facade recommendation) + §4.3 (V5.2 verified 2026-05-22)
- Source files audited (read-only): `PLC_1/Program blocks/500_AutoCtrl/{FB_ManualCtrl.scl V1.2, GDB_ManualCmd.xml}` · `PLC_1/Program blocks/200_HMI_Comm/{GDB_HMI_Status.xml, GDB_MCDData.xml}` · `PLC_1/Program blocks/500_AutoCtrl/FB_AutoCtrl_Palletizing.scl V5.2` · `PLC_1/Program blocks/600_AxisCtrl/GDB_AxisCtrl.xml`
