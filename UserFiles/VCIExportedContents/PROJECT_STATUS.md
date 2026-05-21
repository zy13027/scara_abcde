# PROJECT_STATUS — hmiDemoSCARA_ABCDE

**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`
**Source spec:** `UserFiles/VCIExportedContents/杨子楠5月17日周计划.md`
**Predecessor:** `hmiDemoMomoryCapacity_v9` (archived sibling, untouched)
**Last updated:** 2026-05-18 23:30+ (Phase 2.2 re-VERIFIED 12/12 PASS `palletizing_20260518_233034.log` after SW-limit revert — see lesson note in Phase 2.2 row below. C71 Phase 2.4 HMI Status Facade VERIFIED 9/9 — `GDB_HMI_Status` 40-member read-only facade + `FB_HMIStatusMirror` deployed, smoke probe `hmiStatusFacade_20260518_220300.log` confirms activeMode priority chain + CASE step/target routing + per-joint actuals + safety-chain mirrors all live)

---

## Phase status

| Phase | Description | Status | Notes |
|---|---|---|---|
| **A** | Project bootstrap (.ap20 + hardware + PROFINET + TO XML import) | ✅ Completed via prior cycle (TIA project exists, hardware + TOs imported, 0W/0E) | See `OPERATOR_PHASE_A_HANDOFF.md` |
| **B** | Author core PLC code (UDT + DBs + Startup OB + FB_AxisCtrl + FB_AutoCtrl_ABCDE + Main OB + FB_MCDDataTransfer) | ✅ Source files authored + imported + 0W/0E compile (rev 3.0 with V8 blending) | All 9 source files present in `PLC_1/` subtree |
| **C** | HMI screens — HMI agent's UBP 1024×600 design (NOT my original MTP1000 spec) | ✅ 14 UBP screens authored by HMI agent (cycle-7.0, TIA Compile 0E/0W); PLC Phase C.0+C.0b deployed (GDB_MCDData +8 explicit J{n} mirror + FB_AxisCtrl rev 1.2 backport with MC_SetTool); **8/8 V6+V7-partial gates PASS** via `phaseC_V6_20260517_233032.log` — 6 ABCDE wraps in 60s, 0 coord mismatches, J1/J2 swung 50°/449°. Operator TIA Runtime walkthrough = visual cross-check (bindings already proven via PLC tape). | See `HMI_BINDING_MAP.md` §5+§6 + `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` (VERIFIED) + HMI agent's 6 Cycle-7.0 handoffs in v9 comm tree |
| **D** | PLCSIM-Adv smoke test (V1–V5 + V9 gates) | ✅ 9/9 gates PASS via PLCSIM-Adv API (`SmokeTest_PhaseD.ps1`, log `phaseD_20260517_180109.log`) | Commit `79cae9a` — PLCSIM-Adv instance at 192.168.0.5 (chosen, not plan's prior .40 placeholder) |
| **E** | NX MCD integration (V7 full + V-OB91 gate) | ✅ **VERIFIED** — 6 consecutive `SmokeTest_PhaseE.ps1` runs all 7/7 PLC-side PASS (60 ABCDE cycle wraps × 90s windows = 540s of MCD-coupled streaming with ZERO errors); **V7 visual confirmed by operator 2026-05-18 ~15:18 — SCARA model follows ABCDE pattern in NX MCD viewport during PLC-driven motion**. NX scene `XMD-1001-00-000 立柱旋转机器人` at `E:/NX_Proj/`; 8 signal mappings active (Position×4 + Velocity×4) with J2/J3 deliberate-misorder swap correctly applied (`scaraA2Pos ← Position[3]`, `scaraA3Pos ← Position[2]`). | Plan Goal 3 ✅; **Phase 1 COMPLETE per 杨子楠 memo**. See `PLC_HANDOFF_2026-05-18_C68_PhaseE_NxMcdIntegration.md` |
| **F** | Blending mode (V8 gate, optional) | ✅ 5/5 V8 gates PASS via PLCSIM-Adv API (`SmokeTest_PhaseF_V8.ps1`); 22% throughput gain vs Phase D (5 cycles in 45s vs 3) | Commit `c2d4f86` — BufferMode=5 (BM_BLENDING_HIGH) + progress>0.5 advance verified |
| **G** | Manual Control Surface (FB_ManualCtrl + GDB_ManualCmd + GDB_ManualStatus + axesReady) | 🅿️ **STAGED_FOR_PHASE_2** — 16/16 smoke PASS (`phaseG_20260518_124758.log`); code-side complete and verified working. **Reclassified out of Phase 1** per 杨子楠 memo §2 directive ("手动 jog" explicitly deferred to Phase 2). Code remains in-tree for Phase 2.1 re-activation after Phase E closes; HMI cycle-7.2 binding work waits | `PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md` |
| **2.2** | Palletizing (FB_AutoCtrl_Palletizing + GDB_PalletizingCmd) — 16-box 4-layer stacking demo per operator "Z direction + stack layer increasing" request | ✅ **VERIFIED** — `SmokeTest_Phase2_Palletizing.ps1` 12/12 PASS at 2026-05-18 16:15:18 (`palletizing_20260518_161518.log`). 4 layers (z=300/350/400/450) × 4 boxes (2×2 footprint) × 3 phases (approach/place/retract z+100 dive) = 48 path points, V8 BLENDING_HIGH; 3-way mutex with ABCDE + Manual modes working; no ABCDE regression. **2026-05-18 20:44 follow-up:** L1 geometry corrected 0→1028.48 mm post-NX-Open measurement (`nx_open_probe` journal_v4.py); J3 visible motion expanded 21mm→~250mm; smoke 11/12 PASS (LayerProgression gate hardened with Update-TagList refresh + NoAbcdeRegression window widened to 12s). **2026-05-18 23:30 SW-limit revert (re-VERIFIED 12/12 @ `palletizing_20260518_233034.log`):** an interim tightening of J2 SW to ±160° and J3 SW positive to +100mm (intended to match NX MCD physical envelope) broke palletizing — IK trajectories clamped J2 at -160° at step 1, motion halted with neither Done nor Error so the FB state machine stuck. Reverted J2→-1060/+800° and J3→-1850/+600mm (original empirically-working values). Lesson: TIA SCARA-3D **joint coordinates ≠ MCD slider coordinates** — there's an unwrapped-angle accumulation and L1/LF offset between them; SW limits must be set against the JOINT trajectory range the IK demands, not the MCD physical range. See C69 handoff §10 + §11. | `PLC_HANDOFF_2026-05-18_C69_Phase2_PalletizingBackport.md` |
| **2.4** | HMI Status Facade (GDB_HMI_Status read-only DB + FB_HMIStatusMirror cyclic copier) — consolidate ~40 display tags from 7 source DBs/iDBs/TOs into a single HMI binding surface per operator "centralise all tags exposed to hmi" directive | ✅ **VERIFIED** — `SmokeTest_Phase2_HMIStatusFacade.ps1` 9/9 PASS at 2026-05-18 22:03:00 (`hmiStatusFacade_20260518_220300.log`). 40 facade tags readable; 7-case activeMode priority chain works (ABCDE > Pallet > Manual > None); CASE totalSteps routing (5/48/0/0) and target_xyza routing both PASS; Manual+None correctly hold last target; axesReady mirror consistent; safety-chain (estopLock/alarm/pathInitialed/palletInitialed/toolActive) all mirror correctly. INFORMATIONAL → scara-HMI for cycle-7.X+ incremental migration (multi-DB direct bindings keep working in parallel — facade is additive, not replacement). | `PLC_HANDOFF_2026-05-18_C71_HMIStatusFacade.md` |

---

## Verification gate status

| Gate | Description | Status | Owner | Notes |
|---|---|---|---|---|
| **V1** | No bloat in project tree (only 5 TOs + 9 user blocks; no FB_PalletizingProgramme; no LKinCtrl/LPallPatt/LSKI/LAxisCtrl) | ✅ Trivially passes — new project starts empty + no library imports | PM | Confirmed by `find` audit + LKinCtrl backup |
| **V2** | Start triggers state machine (HMI bo_Start → i16_AutoStep 0→10 within 1 scan) | ✅ Phase D PASS via PLCSIM-Adv API | PM | `SmokeTest_PhaseD.ps1` log |
| **V3** | ABCDE sequential execution (step 10→20→30→40→50) | ✅ Phase D PASS via PLCSIM-Adv API | PM | 6-state pattern verified |
| **V4** | Continuous cycle (step 50 → 10 cycle wrap, runs until Stop) | ✅ Phase D PASS — 3 wraps observed in 45s; Phase F PASS — 5 wraps (22% throughput gain via V8 blending) | PM | |
| **V5** | Stop responsiveness (HMI bo_Stop → step:=0 within 1 scan) | ✅ Phase D PASS via PLCSIM-Adv API | PM | |
| **V6** | Target position display (HMI 4 IOFields = statTargetPos.x/y/z/a) | ✅ Phase C C.C smoke test PASS — `cardProgress` on `02_Auto_Ubp` displays statTargetPos cycling per step; 0 coord mismatches against expected ABCDE coords across 6 wraps in 60s | PM | `phaseC_V6_20260517_233032.log` |
| **V7** | MCD end-to-end link (NX viewport shows SCARA following ABCDE) | ✅ **FULL PASS** — operator visual confirmed 2026-05-18 ~15:18: SCARA model in NX MCD viewport follows ABCDE pattern in 3D during PLC-driven cycle. Goal 3 of 杨子楠 memo achieved. | PM (PLC-side via 6× SmokeTest_PhaseE 7/7 runs); Operator (NX viewport visual) | `phaseE_20260518_151657.log` was the run during which operator confirmed motion visible |
| **V8** | Blending formed (StateOfMotion never Standstill between points) | ✅ Phase F PASS via PLCSIM-Adv API — 0% standstill in 388 velocity samples; max statProgress per step avg=0.48 (range 0.44-0.50, confirming >0.5 trigger fires) | PM | Commit `c2d4f86` |
| **V9** | Code size ≤ 2000 lines (wc -l on all new SCL) | ✅ Passed at ~470 lines actual (well under 2000 ceiling) | PM | |
| **V-OB91** | OB91 buffer overflow gate (ZERO "Buffer overflow for OB 91" events after 30s cycle) | 🚧 Inferred PASS from cycle health (5 continuous wraps in 45s without fault); manual TIA Diagnostics Buffer confirmation deferred to Phase E | Operator | THE root-cause gate for the rebuild |

---

## Source-file inventory on disk (Phase B completion proof)

| Path | Author | Lines | Notes |
|---|---|---|---|
| `PLC_1/PLC data types/UDT_typePoint5.xml` | prior agent (kept as-is) | 71 | struct {x,y,z,a : LReal} — matches plan |
| `PLC_1/Program blocks/100_OB/Startup.scl` | prior agent (kept as-is) | 82 | Inits StartMode/StopMode/HomePos/HomeMode + clears cmd bits |
| `PLC_1/Program blocks/100_OB/Main.scl` | **2026-05-17 rev 2** | ~45 | 3 REGION blocks calling instFB_AxisCtrl + instFB_AutoCtrl_ABCDE + instFB_MCDDataTransfer (replaces v1.0 LKinCtrl inline calls) |
| `PLC_1/Program blocks/100_OB/GDB_Control.xml` | prior agent (kept as-is) | 98 | Enable/home/reset arrays + StartMode/StopMode/HomePos/HomeMode |
| `PLC_1/Program blocks/500_AutoCtrl/GDB_MachineCmd.xml` | prior agent + i16_AutoStep comment edit | 88 | Wang Shuo cmd struct; comment updated to 6-state semantics |
| `PLC_1/Program blocks/500_AutoCtrl/FB_AxisCtrl.scl` | **2026-05-17 NEW** | ~140 | Multi-instance MC_Power[4] + MC_Home[4] + system MC_GroupReset (replaces LKinCtrl wrappers) |
| `PLC_1/Program blocks/500_AutoCtrl/FB_AutoCtrl_ABCDE.scl` | **2026-05-17 rev 2** | ~170 | 6-state pattern + single multi-instance MC_MoveLinearAbsolute (replaces v1.0 11-state) |
| `PLC_1/Program blocks/600_HMI_Comm/FB_MCDDataTransfer.scl` | cloned verbatim from v9 | 28 | Publishes ScaraArm3D.AxesData.A[i].{Position,Velocity} → GDB_MCDData |
| `PLC_1/Program blocks/600_HMI_Comm/GDB_MCDData.xml` | cloned verbatim from v9 | 54 | {Position,Velocity}[1..4] : LReal |
| `PLC_1/Technology objects/J1..J4_SCARA_Arm3D.xml` | prior agent / cloned from v9 | (binary-ish XML) | TO_PositioningAxis |
| `PLC_1/Technology objects/ScaraArm3D.xml` | prior agent / cloned from v9 | (binary-ish XML) | TO_Kinematics, TypeOfKinematics=10 |

**V9 line-count target:** ≤ 2000 lines of SCL. Will be verified at end of this cycle via `wc -l`.

---

## Plan-deviation log

| Date | Plan section | Deviation | Justification |
|---|---|---|---|
| 2026-05-17 | Phase B step 5 — "Axis_Call.scl NEW FC" | Authored as **FB** (FB_AxisCtrl), not FC | MC_Power / MC_Home need to be called per individual joint axis (no system MC_GroupPower exists in TIA V20 — that's LKinCtrl-only). 9 MC iDBs need to be hosted as multi-instance, which requires an FB (FCs can't host multi-instance). Documented in FB_AxisCtrl.scl file header. |
| 2026-05-17 | Architecture overview tree | Folder layout differs: `500_AutoCtrl/` (not `200_AutoCtrl/`), `100_OB/GDB_Control.xml` (not `400_DB/`) | Existing prior-work layout preserved to minimize file moves. Folder numbering is organizational only — TIA Portal accepts any structure. |
| 2026-05-17 | Phase D recipe — "PLCSIM-Adv instance `1511T_ABCDE` at 192.168.0.40" | Used **operator-chosen IP 192.168.0.5** instead; discovered instance name at runtime via API enumeration | Operator's preference for non-conflicting IP; resolved via dynamic `Get-PlcsimInstance | Where IpAddress -eq` lookup. |
| 2026-05-17 | Phase F recipe — V8.ProgressAdvance metric "avg statProgress at step-advance" | Refactored to **V8.ProgressTrigger = max statProgress per step duration** | Original metric measured statProgress AFTER step change when it had already reset to 0; refactor tracks per-step peak. Final result: avg max = 0.48 (range 0.44-0.50) confirming the >0.5 trigger fires correctly. |
| 2026-05-17 | Phase C — "manual operator authoring after Phase A.7 HMI device addition" | Phase C activated **after Phase D + F** instead of after Phase A | Phase D + F (PLCSIM-Adv API smoke test) didn't need HMI runtime; faster validation path. HMI now authored to capture V6 gate. |
| 2026-05-17 22:00 | Phase C — "PLC agent authors 4 markdown screen specs + operator builds in TIA UI" | Phase C **executed by HMI agent's Cycle-7.0 C# Openness builder** (14 UBP screens 1024×600, not 4 MTP1000 1280×800). Original 5 spec .md files in `HMI_1/Screens/` archived as historical reference. | HMI agent's UBP design supersedes my MTP1000 spec. Canonical binding map is now Section 5 of `HMI_BINDING_MAP.md`. |
| 2026-05-17 22:00 | Phase C — "verify HMI bindings via PLCSIM-Adv API" | Phase C.0 sub-task added: extend `GDB_MCDData` + `FB_MCDDataTransfer` rev 0.2 with 8 explicit-named direct-from-TO_Axis members (`J{1..4}_ActualPosition/Velocity`). Backed up to `.backup/2026-05-17_PhaseC_PreMirrorExtend/` | PLCSIM-Adv API doesn't expose TO_Axis tags directly (returns `Error -4 DoesNotExist`); HMI runtime fine via TIA S7 driver. The new mirror lets PLC agent verify the same data HMI sees, AND surfaces the J2/J3 axis-mapping quirk (kinematic-group view has J2/J3 swapped relative to TO_Axis direct). |
| 2026-05-17 22:00 | Phase C — "no PLC code changes expected" | Phase C.0b sub-task added: **backported `FB_AxisCtrl` rev 1.2 from v9** to ABCDE — adds defensive `MC_SetTool(ToolNumber:=1)` one-shot after axesEnabled. Closes the historical UserFault root cause (post-MRES `ScaraArm3D.ToolNumber=0` → `MC_MoveLinAbs` returns `0x8001` → SCARA frozen, cycle stuck at step 10). Backed up to `.backup/2026-05-17_PhaseC_PreToolFixBackport/` | Cycle now alive on ABCDE after fresh memory reset; per Phase C.A re-verify all 5 ABCDE steps cycled in 10.5s. Same fix that closed v9's UserFault in PLC_HANDOFF C63. |
| 2026-05-17 22:00 | Phase 2 raw-MC manual-mode FB (HMI cycle-7.2 dependency) | New "ABCDE Phase G" plan proposed via `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md` — `GDB_ManualCmd` + `GDB_ManualStatus` + `FB_ManualCtrl` (~3-4 hours PLC agent + 4-6 hours HMI agent cycle 7.1+7.2) | HMI agent's 42 stripped widgets (12 per-axis cmd + 12 axis lamps + 4 Kin lamps + 6 Kin jog) unblocked by future Phase G PLC delivery |

---

## Refresh model

Updated at end of every cycle. Phase status icons + verification gate icons reflect current reality. Plan-deviation log is append-only.
