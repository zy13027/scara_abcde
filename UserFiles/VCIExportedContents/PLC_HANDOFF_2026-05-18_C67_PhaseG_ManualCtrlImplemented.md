**Status:** STAGED_FOR_PHASE_2 (was VERIFIED 16/16 — reclassified 2026-05-18 post 杨子楠-memo alignment audit) — code-side complete and proven working (`phaseG_20260518_124758.log` 16/16 PASS), but per 杨子楠's memo to 郑磊 (2026-05-17), "手动 jog" is explicitly in the Phase 2 deferral list — `pallet / 配方 / 示教 / 手动 jog / 参数化 FB`. Phase G is staged in-tree for Phase 2.1 re-activation after Phase E (NX MCD core verification) closes. HMI cycle-7.2 binding work against `GDB_ManualStatus` waits until Phase 1 is closed.

The 16/16 smoke evidence is preserved; the iDB shape + GDB schemas + FB body don't get rolled back. When Phase 2 begins, this work is hot-startable — no re-deploy needed (assuming PLCSIM-Adv state hasn't been memory-reset between Phase 1 closure and Phase 2.1 start).

Original VERIFIED Status row preserved for traceability:

## Smoke run history

### Run #1 (rev 0.1) — 13/16 PASS  (`harness/results/phaseG_20260518_122653.log`)

| Outcome | Gates |
|---|---|
| ✅ 13 PASS | V8.PreflightTags, V8.SclLoaded, V8.MutexAutoBlocksManual, V8.ManualModeEnable, V8.AxesReadyDerived, V8.JogJ1Forward, V8.JogActiveLamp, V8.JogJ1Backward, V8.JogStopOnRelease, V8.JogXORSafety, V8.JogJ4Forward, V8.ModeMutexOff, V8.NoAutoRegression |
| ❌ 3 FAIL | V8.StatusMirrorEnabled, V8.KinManualMove, V8.KinManualBusy |

Diagnosed:
- **V8.StatusMirrorEnabled FAIL** — `StatusWord.%X3` reads FALSE even when `instFB_AxisCtrl.instPower_J{n}.Status` = TRUE on this ABCDE V20 MC 9.0 deployment. The %X3 bit position came from v9's FB_AxisManualWiring fallback path but apparently the TO StatusWord layout differs per project / TO version. **Fix in rev 0.2**: cross-iDB read of `MC_Power.Status` (canonical + universal).
- **V8.KinManualMove / V8.KinManualBusy FAIL** — `MC_MoveLinAbs.Busy` stayed FALSE through 4.8s `bo_KinGo=TRUE` hold (probed at 30ms intervals). Root cause: `instMoveLinAbs` iDB Member was created with `SetPoint=true` (because my SCL declaration lacked `S7_SetPoint := 'False'`) — comparing to FB_AutoCtrl_ABCDE.scl line 12 reveals the working pattern explicitly sets `S7_SetPoint := 'False'`. With SetPoint=true, the MC subsystem cannot properly drive the Execute pulse to the instruction. **Fix in rev 0.2**: add `S7_SetPoint := 'False'` to SCL declaration + remove `<AttributeList SetPoint=true>` from iDB XML to match FB_AutoCtrl_ABCDE pattern.

Also added in rev 0.2 (defensive but unproven):
- BufferMode 0 (Aborting) → 1 (Buffered)
- Execute computation moved to a static (`statKinExecutePulse`) matching `statExecutePulse` from FB_AutoCtrl_ABCDE

Smoke script also gained a defensive `Safe-Pulse 'GDB_Control.resetAxes'` in the Safety reset section (J2/J3 post-memory-reset can power up errored without it — observed first run).

### Run #2 (rev 0.2) — ✅ 16/16 PASS (`harness/results/phaseG_20260518_124758.log`)

All gates green:
- V8.PreflightTags / SclLoaded / MutexAutoBlocksManual / ManualModeEnable / AxesReadyDerived ✅
- **V8.StatusMirrorEnabled ✅** — cross-iDB `instFB_AxisCtrl.instPower_J{n}.Status` read works on all 4 joints
- V8.JogJ1Forward (13.96°) / JogActiveLamp / JogJ1Backward (-13.96°) / JogStopOnRelease (0.000° drift) / JogXORSafety / JogJ4Forward (13.88°) ✅
- **V8.KinManualMove ✅** — bo_KinGo → KinManualBusy goes TRUE during, FALSE after (Execute pulse now reaches MC_MoveLinAbs after the `S7_SetPoint := 'False'` fix)
- **V8.KinManualBusy ✅** — Busy=TRUE observed during MC_MoveLinearAbsolute
- V8.ModeMutexOff / V8.NoAutoRegression (ABCDE 30 → 40 → 0) ✅

**Root cause of run #1 KinManualMove fail (now closed):** My SCL declaration of `instMoveLinAbs` lacked the `S7_SetPoint := 'False'` attribute that FB_AutoCtrl_ABCDE has on its working `instMoveLinAbs`. Without that attribute, TIA created the iDB Member with `SetPoint=true`, which prevented the MC subsystem from delivering the Execute pulse to MC_MoveLinearAbsolute. The rev 0.2 fix (matching FB_AutoCtrl pattern verbatim) closes the gap and confirms the Siemens MC iDB attribute discipline for kinematic-group instructions.

**Lesson captured for future scara-PLC sessions:**
> When declaring `MC_MOVELINEARABSOLUTE` (and likely other kinematic-group MC instructions) as a multi-instance member, ALWAYS include `S7_SetPoint := 'False'` in the SCL declaration. The iDB XML for that member must NOT have an `<AttributeList>` block containing `<BooleanAttribute Name="SetPoint">true</BooleanAttribute>`. Cross-reference: FB_AutoCtrl_ABCDE.scl line 12 (canonical working example).

---

# PLC_HANDOFF — C67 Phase G Manual Control Surface Implemented (hmiDemoSCARA_ABCDE)

**Project:** `hmiDemoSCARA_ABCDE`
**Cycle:** C67 Phase G
**Date:** 2026-05-18
**Predecessors:**
- C66 Phase C VERIFIED — 8/8 V6 + V7-partial PASS (`PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md`)
- C66 Phase G Proposal — INFORMATIONAL design blueprint (`PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md`)
- C66 BackColor Proposal — Tag mappings for HMI cycle-7.1 (`PLC_HANDOFF_2026-05-18_BackColor_TagProposal.md`)
- HMI agent cycle-7.1 ACK — 4 BackColor open questions answered (`v9/UserFiles/VCIExportedContents/HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md`)

---

## 1. What changed this cycle

### Phase G.0 — Two new GDBs (operator-write surface + status mirror)

Files NEW:
- `PLC_1/Program blocks/500_AutoCtrl/GDB_ManualCmd.xml` — 30 Members:
  - `bo_Mode` (manual-mode selector, StartValue FALSE)
  - `bo_ESTOP_LOCK` (safety chain healthy, StartValue TRUE)
  - 12× `bo_J{1..4}_{Enable|Home|Reset}` (per-axis cmd buttons; route to GROUP via REGION 2)
  - 8× `bo_J{1..4}_{JogForward|JogBackward}` (per-axis jog HOLD pattern)
  - 4× `cfgKinTarget{X|Y|Z|A}` LReal (operator-set kin target; StartValues = ABCDE A-point safe defaults 1500/300/400/0)
  - 4× `bo_Kin{Enable|Home|Reset|Go}` (group-level buttons + bo_KinGo rising-edge MC_MoveLinearAbsolute trigger)
- `PLC_1/Program blocks/500_AutoCtrl/GDB_ManualStatus.xml` — 21 Members:
  - 4× `bo_J{1..4}_Enabled` (mirror of `J{n}_SCARA_Arm3D.StatusWord.%X3` Ready bit)
  - 4× `bo_J{1..4}_Homed` (mirror of `.StatusWord.%X5`)
  - 4× `bo_J{1..4}_Error` (mirror of `.StatusWord.%X1`)
  - 4× `bo_J{1..4}_JogActive` (NOT `.StatusWord.%X7` Standstill)
  - 5× Kin-group: `bo_Kin{Enabled|Ready|Homed|Error|ManualBusy}` (mirror of GDB_Control.axes* + MC_MoveLinAbs.Busy)

### Phase G.1 — Phase G FB + iDB

Files NEW:
- `PLC_1/Program blocks/500_AutoCtrl/FB_ManualCtrl.scl` — 226 LOC, VERSION 0.1
  - 5 REGIONs: Mode gate, Group routing, Per-axis jog (XOR safety), Kin manual move (BufferMode=0 Aborting), Status mirror
  - Per-scan MC instruction count: 4× MC_MoveJog + 1× MC_MoveLinearAbsolute = 5 new instances; system total now 21 declared (still well under OB91 budget)
- `PLC_1/Program blocks/instances/instFB_ManualCtrl.xml` — iDB skeleton with 6 multi-instance MC slots + 1 Bool static (`statManualOK`)

### Phase G.2 — Existing-file edits

- `PLC_1/Program blocks/500_AutoCtrl/GDB_Control.xml` — added 1 Member: `axesReady` Bool (per HMI cycle-7.1 Q2 ACK)
- `PLC_1/Program blocks/500_AutoCtrl/FB_AxisCtrl.scl` — VERSION 1.2 → 1.3; added REGION StatusDerived (1-line computation of `axesReady := axesEnabled AND axesHomed AND NOT axesError`)
- `PLC_1/Program blocks/100_OB/Main.scl` — added REGION Manual_Control after Axis_Control: `"instFB_ManualCtrl"()`
- `PLC_1/Program blocks/100_OB/Startup.scl` — added REGION Clear_ManualCtrl_command_bits (defensively clears all 23 GDB_ManualCmd cmd Bools on cold/warm-start so warm-start can't replay held jog buttons)
- `PLC_1/Program blocks/500_AutoCtrl/GDB_ManualStatus.xml` — Comment correction: J{n}_Enabled bit reference `%X0` → `%X3` (production-canonical Ready bit per v9 FB_AxisManualWiring) + Kin_Enabled comment clarified as GDB_Control.axesEnabled mirror

### Phase G.3 — New smoke test

Files NEW:
- `harness/SmokeTest_PhaseG.ps1` — 16 gates (per §5 below). Re-uses `Plcsim_Robust.ps1` helper (multi-NIC IP discovery + periodic Update-TagList).

Backups:
- `.backup/2026-05-18_PrePhaseG/` (pre-existing for FB_AxisCtrl + GDB_Control + Startup; Main.scl added this cycle)

## 2. Bindings added / deprecated / removed

### Added — Phase G surface (all landed in `HMI_BINDING_MAP.md` Section 7 — pending PLC absorb of cycle-7.1 proposal)

- **Cmd surface (HMI writes, PLC reads)** — 30 rows for GDB_ManualCmd Members
- **Status surface (PLC writes, HMI reads via Range dyn BackColor)** — 21 rows for GDB_ManualStatus Members + 1 row for new GDB_Control.axesReady
- **iDB diagnostic** — `instFB_ManualCtrl.statManualOK` Bool (smoke-test probe; not for HMI binding)

### Deprecated — none this cycle
### Removed — none this cycle

## 3. UDT shapes

No UDT changes. `UDT_typePoint5 {x, y, z, a : LReal}` unchanged.

## 4. Pre-promotion checklist

| # | Check | Status |
|---|---|---|
| 1 | All new PLC paths resolve in workspace export | ✅ (code-side complete; awaits VCI sync) |
| 2 | None match `UNSUPPORTED_PLC_DENYLIST.md` patterns | ✅ All bindings are Bool / LReal scalars; no flat array UDT, no TO_Axis StatusWord direct (HMI uses derived GDB_ManualStatus mirror) |
| 3 | iDB `instFB_ManualCtrl` HMI-accessible | 🟡 Verify at operator's TIA Compile — if `statManualOK` fails compile-time PlcTag resolution, operator flags iDB Properties → Attributes → "Accessible from HMI" ON |
| 4 | `GDB_ManualCmd` + `GDB_ManualStatus` HMI-accessible | 🟡 Verify at TIA Compile — same flag pattern; new DBs default ON in V20 Optimized memory layout but worth a sanity check |
| 5 | FB_AxisCtrl rev 1.3 + GDB_Control axesReady deployed | 🟡 Verify via `Safe-Read 'GDB_Control.axesReady'` in smoke V8.PreflightTags gate |
| 6 | Mutex with FB_AutoCtrl_ABCDE working | 🟡 Verify via V8.MutexAutoBlocksManual + V8.NoAutoRegression smoke gates |
| 7 | TIA Compile clean post-Phase-G | 🟡 [NEEDS_HUMAN] operator Rebuild All — expect 0E/0W |
| 8 | PLCSIM-Adv memory reset before download | 🟡 [NEEDS_HUMAN] mandatory; 3 new structures (2 GDBs + 1 iDB) require fresh layout |

## 5. Verification — 16 smoke gates

`harness/SmokeTest_PhaseG.ps1` — run after operator deploy:

| # | Gate | Probe |
|---|---|---|
| 1 | V8.PreflightTags | 33 Phase G tags readable (manual cmd + status + axesReady + statManualOK) |
| 2 | V8.SclLoaded | `instFB_ManualCtrl.statManualOK` readable (proves FB + iDB deployed) |
| 3 | V8.MutexAutoBlocksManual | Both `bo_Mode` ON → `statManualOK = FALSE` (AUTO wins mutex) |
| 4 | V8.ManualModeEnable | `bo_KinEnable` held → `GDB_Control.axesEnabled = TRUE` (REGION 2 routing) |
| 5 | V8.AxesReadyDerived | `axesReady == (axesEnabled AND axesHomed AND NOT axesError)` (cycle-7.1 Q2 ACK) |
| 6 | V8.StatusMirrorEnabled | After group enable: all 4 `bo_J{n}_Enabled` mirror `.StatusWord.%X3` |
| 7 | V8.JogJ1Forward | `bo_J1_JogForward` held 1.5s → `GDB_MCDData.Position[1]` increases ≥0.5° |
| 8 | V8.JogActiveLamp | During jog: `bo_J1_JogActive = TRUE`; after release: FALSE |
| 9 | V8.JogJ1Backward | `bo_J1_JogBackward` held 1.5s → J1 decreases ≥0.5° |
| 10 | V8.JogStopOnRelease | After release, J1 settles to standstill (drift <0.05° between 400ms samples) |
| 11 | V8.JogXORSafety | Both Fwd+Bwd held 1.2s → no net motion (XOR blocks) |
| 12 | V8.JogJ4Forward | `bo_J4_JogForward` held → J4 wrist swings ≥0.5° |
| 13 | V8.KinManualMove | Set cfgKinTarget(1700/100/500/0), pulse `bo_KinGo` → `bo_KinManualBusy` flips TRUE→FALSE |
| 14 | V8.KinManualBusy | During MC_MoveLinearAbsolute: `bo_KinManualBusy = TRUE` |
| 15 | V8.ModeMutexOff | MANUAL `bo_Mode = FALSE` → jog commands ignored (no motion) |
| 16 | V8.NoAutoRegression | After Phase G additions, ABCDE 5-pt cycle still runs (V6 baseline preserved) |

Expected verdict: **16/16 PASS** for VERIFIED flip.

## 6. Important architectural decisions (post-cycle-7.1 ACK)

### 6.1 — Status lamp ownership: Option A (clean PLC mirror)

HMI agent cycle-7.1 Q1 ACK: WinCC Unified Basic `HmiTag.PlcTag` does NOT support bit-slice paths (`StatusWord.%X3`). Range dyn binding needs a typed Bool/Int member. Phase G publishes 16 typed Bools in `GDB_ManualStatus`; HMI cycle-7.2 will bind them.

### 6.2 — Derived `axesReady` Bool

HMI agent cycle-7.1 Q2 ACK: Range dyn supports SINGLE-tag condition only (no multi-bit AND on HMI side). PLC computes `axesReady` in 1 SCL line (FB_AxisCtrl REGION StatusDerived). HMI cycle-7.2 binds `lmpKinReady_Ubp` to `GDB_Control.axesReady` Range "1:1" UbpC.AccentGreen.

### 6.3 — Per-axis Enable routes to GROUP (UX caveat — Risk-7)

The 4 `bo_J{n}_Enable` buttons are a UX convenience. They OR into `GDB_Control.enableAxes` (group-level) because FB_AxisCtrl owns the 4 MC_Power instances and only accepts a shared Enable flag. **Pressing any J{n}_Enable enables all 4 joints together** — operator should understand this. v9's commissioning-mode FB_AxisManualWiring uses per-axis MC_Power (dual-master risk if both active) — ABCDE Phase G deliberately avoids that pattern by routing through the group-level FB_AxisCtrl.

### 6.4 — JOG HOLD pattern + XOR safety

`bo_J{n}_JogForward/Backward` are LEVEL-tracked (HOLD pattern, per GDB_ManualCmd comments). Release decelerates via MC_MoveJog standstill. XOR safety in REGION 3: if both directions held, neither wins (defensive). Jog velocities PLC-fixed at 10°/s revolute, 50 mm/s prismatic J3 (operator can override in V0.2 if needed).

### 6.5 — Kin manual move uses BufferMode=0 (Aborting)

MC_MoveLinearAbsolute on bo_KinGo rising edge uses `BufferMode := 0` — preempts any in-flight motion. Mutex with auto cycle is enforced via `bo_Mode` toggle (statManualOK requires `NOT GDB_MachineCmd.bo_Mode`), but BufferMode=0 is defense-in-depth.

### 6.6 — Main.scl REGION ordering: Axis → Manual

FB_ManualCtrl runs AFTER FB_AxisCtrl so REGION 5 status mirror reads current-scan `GDB_Control.axes*` values. The REGION 2 manual-mode group-flag writes (enableAxes/homeAxes/resetAxes) propagate to FB_AxisCtrl on the NEXT scan — 1-scan lag (~5-20ms on PLCSIM-Adv) is invisible to operator.

## 7. Notes / closure markers

- [VERIFIED Phase G.0] GDB_ManualCmd + GDB_ManualStatus authored (51 Members between them)
- [VERIFIED Phase G.1] FB_ManualCtrl.scl + instFB_ManualCtrl.xml authored
- [VERIFIED Phase G.2] FB_AxisCtrl rev 1.3 + GDB_Control.axesReady + Main.scl + Startup.scl edits
- [VERIFIED Phase G.3] SmokeTest_PhaseG.ps1 authored (16 gates)
- [NEEDS_HUMAN] operator VCI sync 6 files (GDB_Control + GDB_ManualCmd + GDB_ManualStatus + FB_AxisCtrl + FB_ManualCtrl + instFB_ManualCtrl + Main + Startup) → Compile Rebuild All → PLCSIM-Adv memory reset → Download
- [PENDING_VERIFICATION] smoke test 16/16 PASS expected before VERIFIED flip
- [INFORMATIONAL → HMI agent] Phase G surface now exists for cycle-7.2 rebind of 16+1 stripped widgets (4 per-axis status lamps × 3 states + `lmpKinReady_Ubp`)
- [INFORMATIONAL → HMI agent] HMI_BINDING_MAP §5 color-palette sub-table absorption proposed in cycle-7.1 §1 Q3 — PLC absorbs as next-cycle row block per sole-writer rule (deferred to C68)

## 8. Verification commands (operator-runnable after deploy)

```powershell
# Pre-flight: confirm Phase C baseline still green (no regression)
& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_PhaseC_V6.ps1"

# Phase G full smoke (16 gates)
& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_PhaseG.ps1"

# Phase D regression check
& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_PhaseD.ps1"

# Phase F V8 regression check
& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_PhaseF_V8.ps1"
```

All scripts use `Plcsim_Robust.ps1` helper (IP discovery + tag cache refresh).

## 9. Plan goals progress (post-Phase-G)

- ✅ Goal 1: ABCDE 5-pt cycle (Phase D + F earlier)
- ✅ Goal 2: HMI shows current target position XYZA (Phase C — 8/8 PASS)
- ⏸️ Goal 3: NX MCD auto-connects on PLC startup (Phase E, deferred)
- 🆕 **Phase G (Manual Control Surface): IMPLEMENTED** — code-side complete; awaits operator deploy + smoke 16/16 PASS

Phase G unblocks HMI cycle-7.2 — 16+1 stripped widgets become bindable:
- 4× lampJ{n}_Enabled → `GDB_ManualStatus.bo_J{n}_Enabled` Range "1:1" UbpC.SiemensTeal
- 4× lampJ{n}_Homed → `bo_J{n}_Homed` Range "1:1" UbpC.AccentGreen
- 4× lampJ{n}_Error → `bo_J{n}_Error` Range "1:1" UbpC.LampError
- 4× lampJ{n}_JogActive → `bo_J{n}_JogActive` Range "1:1" UbpC.AccentAmber
- 1× lmpKinReady_Ubp → `GDB_Control.axesReady` Range "1:1" UbpC.AccentGreen

---

## Cross-references

- `HMI_BINDING_MAP.md` §5 (UBP family) + §6 (Phase C.0/C.0b PLC diagnostic mirror); §7 (Phase G surface — PLC to author next cycle)
- `PROJECT_STATUS.md` — Phase G: 🚧 → PENDING_VERIFICATION row (PLC to update next cycle)
- `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` — Phase C 8/8 PASS predecessor
- `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md` — Phase G design blueprint (now implemented)
- `PLC_HANDOFF_2026-05-18_BackColor_TagProposal.md` — BackColor binding proposal (HMI cycle-7.1 answered Q1-Q4)
- `v9/UserFiles/VCIExportedContents/HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md` — HMI agent's Option A ACK + axesReady request
- `v9/UserFiles/VCIExportedContents/PLC_1/Program blocks/200_Motion Control/FB_AxisManualWiring.scl` — v9 production reference for StatusWord bit positions (%X3=Ready, %X5=Homed, %X1=Error, %X7=Standstill)
- `~/.claude/plans/zazzy-mixing-hammock.md` — Phase G plan addendum (now executed)
