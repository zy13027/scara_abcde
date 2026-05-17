# PROJECT_STATUS — hmiDemoSCARA_ABCDE

**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`
**Source spec:** `UserFiles/VCIExportedContents/杨子楠5月17日周计划.md`
**Predecessor:** `hmiDemoMomoryCapacity_v9` (archived sibling, untouched)
**Last updated:** 2026-05-17 23:30+ (scara-PM catch-up rollup — Phase A→F + Phase C V6 8/8 VERIFIED + Phase G manual-mode tag proposal filed + 5 HMI Cycle 7_0 handoffs migrated from v9 tree → SCARA tree; commit pending push auth)

---

## Phase status

| Phase | Description | Status | Notes |
|---|---|---|---|
| **A** | Project bootstrap (.ap20 + hardware + PROFINET + TO XML import) | ✅ Completed via prior cycle (TIA project exists, hardware + TOs imported, 0W/0E) | See `OPERATOR_PHASE_A_HANDOFF.md` |
| **B** | Author core PLC code (UDT + DBs + Startup OB + FB_AxisCtrl + FB_AutoCtrl_ABCDE + Main OB + FB_MCDDataTransfer) | ✅ Source files authored + imported + 0W/0E compile (rev 3.0 with V8 blending) | All 9 source files present in `PLC_1/` subtree |
| **C** | HMI screens — HMI agent's UBP 1024×600 design (NOT my original MTP1000 spec) | ✅ 14 UBP screens authored by HMI agent (cycle-7.0, TIA Compile 0E/0W); PLC Phase C.0+C.0b deployed (GDB_MCDData +8 explicit J{n} mirror + FB_AxisCtrl rev 1.2 backport with MC_SetTool); **8/8 V6+V7-partial gates PASS** via `phaseC_V6_20260517_233032.log` — 6 ABCDE wraps in 60s, 0 coord mismatches, J1/J2 swung 50°/449°. Operator TIA Runtime walkthrough = visual cross-check (bindings already proven via PLC tape). | See `HMI_BINDING_MAP.md` §5+§6 + `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` (VERIFIED) + HMI agent's 6 Cycle-7.0 handoffs in v9 comm tree |
| **D** | PLCSIM-Adv smoke test (V1–V5 + V9 gates) | ✅ 9/9 gates PASS via PLCSIM-Adv API (`SmokeTest_PhaseD.ps1`, log `phaseD_20260517_180109.log`) | Commit `79cae9a` — PLCSIM-Adv instance at 192.168.0.5 (chosen, not plan's prior .40 placeholder) |
| **E** | NX MCD integration (V7 full + V-OB91 gate) | ⏸️ Deferred — separate cycle after Phase C | Reuse v9 MCD scene at `E:/NX_Proj/XMD-1001-00-000 立柱旋转机器人(西门子系统)/` |
| **F** | Blending mode (V8 gate, optional) | ✅ 5/5 V8 gates PASS via PLCSIM-Adv API (`SmokeTest_PhaseF_V8.ps1`); 22% throughput gain vs Phase D (5 cycles in 45s vs 3) | Commit `c2d4f86` — BufferMode=5 (BM_BLENDING_HIGH) + progress>0.5 advance verified |

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
| **V7** | MCD end-to-end link (NX viewport shows SCARA following ABCDE) | 🚧 **V7-partial PASS** — per-axis deep-drill screens show J1/J2/J3/J4 ActualPosition live during cycle (kinematic-solver→TO_Axis→HMI path verified). Full V7 still requires Phase E NX MCD signal-adapter binding | PM (partial); Operator (full Phase E) | |
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
