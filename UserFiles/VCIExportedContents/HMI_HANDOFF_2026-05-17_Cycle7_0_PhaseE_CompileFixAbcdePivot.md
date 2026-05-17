**Status:** PENDING_VERIFICATION

# HMI → PLC Handoff — 2026-05-17 (Cycle-7.0 Phase E compile-fix: UBP builders pivoted from v10 LKinCtrl tag namespace → ABCDE Phase 1 canonical bindings; 111 TIA HMI Compile errors expected to drop to ~0)

> **Predecessor:** [HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_FireSuccess.md](HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_FireSuccess.md) (Phase E source-side fire SUCCESS; project saved with all UBP screens authored). That fire surfaced 111 TIA HMI Compile errors on 8:04:20 PM when operator clicked Compile in TIA, all of the form `The object HMITag with the name "mc_kin_*" / "mc_axis_J{n}_*" was not found`.
>
> **Root cause** (operator-clarified): UBP builders authored bindings against v10 LKinCtrl-derived motion-control tag namespace (`mc_kin_*` + `mc_axis_J{n}_*`), but `hmiDemoSCARA_ABCDE.ap20` is a fresh Phase 1 project that bans third-party libraries per **C61 §1 directive from 郑老板 (GMC, 2026-05-17)**: "不用任何第三方库 (LKinCtrl / LPallPatt / LSKI / LAxisCtrl / 等)".
>
> **Operator directive that triggered this fix**: "do not need the old hmi tag you should read hand off and tag mapping of abcde project" → pivot UBP builders to consume the ABCDE Phase 1 canonical PLC contract surface (`GDB_MachineCmd.bo_*` / `i16_AutoStep` / `instFB_AutoCtrl_ABCDE.statTargetPos.*` / `ScaraArm3D.Position[*]` / `J{n}_SCARA_Arm3D.ActualPosition`) per `hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/HMI_BINDING_MAP.md`.
>
> **First attempt rejected** (recorded for learning): initially extended `UbpLayoutHostBuilder.EnsureUbpTags()` with `EnsureMotionControlTags()` to bootstrap the 90+ v10 `mc_kin_*` + `mc_axis_J{n}_*` tags on SCARA_ABCDE HMI_1 (treating "tag missing" as "tag not yet authored"). Operator immediately corrected: "do not need the old hmi tag" — the tags shouldn't EXIST per Phase 1 library ban, not just be missing. The correct fix is to USE THE ABCDE NAMESPACE, not seed the v10 namespace on a project that bans it. Misguided edit reverted.

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-17 ~21:30 (Phase E compile-fix pivot) |
| Triggered by | TIA HMI Compile output: 111 errors at 8:04:20 PM operator click; root cause v10 LKinCtrl tag references not present on Phase 1 ABCDE project |
| Tag pivot direction | v10 LKinCtrl namespace (`mc_kin_*` / `mc_axis_J{n}_*`) → Phase 1 ABCDE namespace (`GDB_MachineCmd.*` + `instFB_AutoCtrl_ABCDE.statTargetPos.*` + `ScaraArm3D.Position[*]` + `J{n}_SCARA_Arm3D.ActualPosition`) |
| Source delivered | 1 NEW file + 3 EDITED files (3 builders + 1 revert) |
| Build verdict | 2 builds — #1 surfaced CS8600 nullable-default warning on `string switch _ => null` pattern; fix landed (`_ => string.Empty`); #2: **0 Warning(s) / 0 Error(s)** in 1.09s |
| Phase E re-fire | ⏳ AWAITING OPERATOR AUTHORIZATION |
| Phase F final | 🟡 Pending operator re-Compile in TIA after re-fire → expect 0 errors (or <10 if `J{n}_SCARA_Arm3D.ActualVelocity` TO attr isn't HMI-exposed) |
| Status | **PENDING_VERIFICATION** (compile-fix source delivered; re-fire + re-compile remain) |

---

## 1. Audit findings

_(N/A — compile-fix source landed only; no fire executed yet against `hmiDemoSCARA_ABCDE.ap20`.)_

## 2. Tags authored / deprecated

**Tag namespace pivot** (informational — no PLC tag asks, all bindings consume PLC-side tags already published):

| Pivoted from (v10 LKinCtrl, ABSENT on ABCDE) | Pivoted to (ABCDE Phase 1 canonical) | Source rationale |
|---|---|---|
| `mc_kin_cmdEnable` (INVERT) | `GDB_MachineCmd.bo_Mode` (TOGGLE) | Kin footer ENABLE: PLC Mode flag (LEVEL) replaces v10 Kin enable INVERT |
| `mc_kin_cmdStop` (INVERT) | `GDB_MachineCmd.bo_Stop` (PULSE 250ms) | Kin footer STOP: ABCDE FB R_TRIG consumes PULSE rising-edge |
| `mc_kin_cfgTargetX/Y/Z` (R/W LReal) | `instFB_AutoCtrl_ABCDE.statTargetPos.x/y/z` (ReadOnly LReal) | Kin axis rows X/Y/Z target IO: ABCDE FB exposes current path target snapshot |
| `mc_kin_cfgJogAxis` / `cmdJogForward/Backward` | _stripped_ (no Phase 1 jog equivalent) | Kin axis rows JOG-/JOG+: no Phase 1 manual jog FB; widgets render no-op |
| `mc_kin_statusEnabled/Ready/Homed/Error` | _stripped_ (no Phase 1 status mirror) | Kin status banner lamps: render static idle |
| `mc_axis_J{n}_status_ActualPosition` | `J{n}_SCARA_Arm3D.ActualPosition` (TO_Axis attr) | Per-axis actual position: TO_Axis standard attribute per ABCDE HMI_BINDING_MAP §"Actual_Joints_Screen" |
| `mc_axis_J{n}_status_ActualVel` | `J{n}_SCARA_Arm3D.ActualVelocity` (TO_Axis attr, defensive) | Per-axis actual velocity: TO_Axis standard attribute; if Compile rejects, operator strips manually |
| `mc_axis_J{n}_cmd_Enable/Home/Reset/JogForward/JogBackward` | _stripped_ (no Phase 1 per-axis cmd equivalent) | Per-axis ENABLE/HOME/RESET/JOG buttons: no Phase 1 raw-MC per-joint enable mirror; widgets render no-op |
| `mc_axis_J{n}_status_ready/homed/error` | _stripped_ (no Phase 1 status mirror) | Per-axis status mini-lamps: render static idle |
| `bo_Start` (NEW Auto card binding) | `GDB_MachineCmd.bo_Start` (PULSE 250ms) | btnAutoStart: ABCDE R_TRIG rising-edge consumption |
| `bo_Stop` (NEW Auto card binding) | `GDB_MachineCmd.bo_Stop` (PULSE 250ms) | btnAutoStop: same |
| `bo_InitPath` (NEW Auto card binding) | `GDB_MachineCmd.bo_InitPath` (PULSE 250ms) | btnAutoInitPath: one-time path init |
| `bo_Mode` (NEW Auto card binding) | `GDB_MachineCmd.bo_Mode` (TOGGLE) | btnAutoMode: LEVEL flag (operator can rebind to 2-state Switch widget) |
| `i16_AutoStep` (NEW IOField R) | `GDB_MachineCmd.i16_AutoStep` (Int R) | cardProgress: current step display (0/10/20/30/40/50) |
| `statTargetPos.x/y/z/a` (4 NEW IOField R) | `instFB_AutoCtrl_ABCDE.statTargetPos.{x,y,z,a}` (LReal R × 4) | cardProgress: current commanded target XYZA |

**Proposal to PLC agent**: optional new row in HMI_BINDING_MAP.md crediting UBP family as binding consumer of `GDB_MachineCmd.*` + `instFB_AutoCtrl_ABCDE.statTargetPos.*` + `J{n}_SCARA_Arm3D.ActualPosition`. Per HMI_BINDING_MAP.md sole-writer rule (PLC), HMI proposes here in §2; PLC absorbs in next cycle.

## 3. Manual-wiring follow-ups

| Item | Surface | Wiring directive |
|---|---|---|
| Phase 2 raw-MC manual-mode FB | Operator action when Phase 1 ACK + Phase 2 starts | Rebind 12 per-axis cmd buttons (J{1..4} × {Enable, Home, Reset}) + 8 per-axis status lamps (J{1..4} × {ready, homed, error}) + 4 Kin status lamps + 3 Kin axis JOG rows once raw-MC OB124 manual FB exposes per-joint command + status tags |
| `J{n}_SCARA_Arm3D.ActualVelocity` defensive binding | Operator action on TIA Compile after re-fire | If TIA HMI Compile rejects this TO attribute (TO_Axis may not expose it on HMI directly), strip the 4 binding lines in TIA Property Inspector OR cycle-7.1 source-strips them |
| 4-button vertical stack on Auto right column | Operator action if visual cramped | btnAutoMode is the new 4th button (added between Reset removal). If layout looks cramped, operator can reduce btnH or move btnAutoMode to top-bar |

## 4. Screen authoring summary

**Source delta** (~250 LOC across 4 files):

| File | Action | LOC | Substance |
|---|---|---|---|
| `Builders/Ubp/AbcdePhase1Tags.cs` | **NEW** | ~95 | Canonical Phase 1 ABCDE tag namespace (15 consts + `AxisActualPosition(j)` / `AxisActualVelocity(j)` helpers + `BuildPulseJs(tag)` / `BuildToggleJs(tag)` JS-generator helpers) |
| `Builders/Ubp/UbpLayoutHostBuilder.cs` | REVERT | -110 | Removed misguided EnsureMotionControlTags() that would have bootstrapped 90+ v10 tags (banned per C61 §1 library directive) |
| `Builders/Ubp/UbpAutoBuilder.cs` | EDIT | ~80 | Right column rewired: cardProgress now hosts 5 live IOFields (i16_AutoStep + 4 statTargetPos); cardAutoCtrl now hosts 4 wired buttons (Start/Stop PULSE + InitPath PULSE + Mode TOGGLE); new BuildIoKvRow helper for label+IO pairs |
| `Builders/Ubp/UbpManualBuilder.cs` | EDIT | ~150 | All MotionControlTags.* refs replaced — Kin banner lamps stripped (4×), Kin axis row IO rebound to statTargetPos (3×) + JOG/active-axis lamps stripped (3×3), Kin footer rebound (Mode/Stop), Axis 2×2 quadrant Actual rebound to J{n}_SCARA_Arm3D.ActualPosition (4×) + JOG/status stripped (4×5), per-axis screens header lamps stripped (4×3), per-axis Position card rebound to J{n}_SCARA_Arm3D.Actual{Position,Velocity} (4×2), per-axis JOG row stripped (4×2), per-axis ENABLE/HOME/RESET stripped (4×3) |

## 5. Compile results

| Build | Source | Result | Notes |
|---|---|---|---|
| 1 | After all 4 source edits | 0E / 1W | CS8600 on `string statTargetTag = axisLabel switch { _ => null }` — nullable literal in non-nullable assignment |
| 2 | After fix (`_ => string.Empty` + `string.IsNullOrEmpty` check) | **0W / 0E** ✅ | Time elapsed 1.09s. Compile-fix source delivers clean. |

## 6. Issues escalated for PLC agent

_None new this cycle._ Continuing:
- [INFORMATIONAL → PLC] Cycle-7.0 UBP family now correctly binds to Phase 1 ABCDE canonical PLC contract surface (`GDB_MachineCmd.*` + `instFB_AutoCtrl_ABCDE.statTargetPos.*` + TO_Axis attributes). Optional ack via HMI_BINDING_MAP.md §1 row crediting UBP family as binding consumer.

## 7. Verification commands (Phase E re-fire)

```bash
cd /e/VS_Code_Proj/TiaUnifiedAuto
dotnet run --no-build -- --only=ubp-all
# Expected: attached to already-open project (pid for hmiDemoSCARA_ABCDE)
#           UbpLayoutHostBuilder + UbpAutoBuilder + UbpManualBuilder all fire
#           ALL [ABCDE-P1] console lines visible (bo_Start PULSE / bo_Stop PULSE / bo_InitPath PULSE / bo_Mode TOGGLE / i16_AutoStep IO / 4 statTargetPos IO / J{n}_SCARA_Arm3D.ActualPosition IO × 4)
#           Per-axis ENABLE/HOME/RESET/JOG widgets render WITHOUT [EVENT] script lines (stripped)
#           Per-axis status lamps + Kin status lamps render WITHOUT [DYN] BackColor lines (stripped)
#           [UBP] Project saved.

# Then operator opens TIA Portal → HMI_1 → right-click → Compile (or Ctrl+B)
# Expected: 111 errors → 0 errors (or near-0)
#   - 4 potential errors if J{n}_SCARA_Arm3D.ActualVelocity isn't HMI-exposed
#     (TO_Axis exposes Position but Velocity may be CamSwitch-side only)
#   - Operator strips manually in TIA Property Inspector if these surface,
#     OR cycle-7.1 source-strips them next session
```

## 8. Notes for the PLC agent

- **Source compile-fix delivers clean (0W/0E in 1.09s)** — ready to re-fire against `hmiDemoSCARA_ABCDE.ap20`. Awaiting operator authorization for the re-fire (Bash tool's auto-mode classifier guards re-fires against shared infrastructure).
- **Re-fire owed**: `dotnet run --no-build -- --only=ubp-all`. The fire re-authors all UBP screens with the new ABCDE-aligned bindings (idempotent overwrite — existing widgets keep position + dimensions; only `_adapter.Bind*` script bodies + tag refs swap).
- **Operator re-Compile owed**: after re-fire, operator clicks Compile (Ctrl+B or right-click PLC_1 → Software Rebuild All) in TIA Portal. Expected: 111 errors → 0 (or ≤4 if `J{n}_SCARA_Arm3D.ActualVelocity` isn't HMI-exposed; defensive binding, strip-on-fail per §3).
- **Cycle-6.19 ENABLE INVERT pattern**: retained in widget naming (`btnAxSecEnable_Ubp_J{j}`) but bindings stripped because Phase 1 has no per-axis `cmd_Enable` tag mirror. Phase 2 candidate to re-author the INVERT JS once raw-MC manual-mode FB exposes per-joint enable on a HMI tag.
- **Surface decoupling preserved**: HMI surface (UBP big-font + Siemens-teal + 1024×600 + full Auto+Manual layout) is unchanged from prior Phase A+B+C+D delivery; only tag bindings pivoted. The Manual surface is currently visually-rich-but-functionally-minimal (Position display works; jog/enable/home/reset render as visual placeholders pending Phase 2).
- **Closure markers**: `[NEEDS_OPERATOR]` re-fire authorization + TIA re-Compile; `[INFORMATIONAL → PLC]` cycle-7.0 now correctly consumes Phase 1 ABCDE canonical bindings (optional HMI_BINDING_MAP.md row credit).

---

End of Phase E compile-fix handoff. Awaiting operator re-fire authorization + TIA re-Compile to flip cycle-7.0 PENDING_VERIFICATION → VERIFIED.
