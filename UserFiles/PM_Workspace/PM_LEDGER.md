# PM Ledger — hmiDemoSCARA_ABCDE

Append-only history of PM agent activity for this project. Never edit historical rows; just add new ones underneath.

---

## 2026-05-17 — Session: Project bootstrap (Phase A.1 source authoring per approved plan)

| Cycle | Activity | Detail |
|---|---|---|
| init | project.bootstrap.start | Approved plan zazzy-mixing-hammock.md exited plan mode. Auto mode active. Began Phase A directory bootstrap + Phase B source authoring. |
| init | audit.prior_work | Found existing `hmiDemoSCARA_ABCDE/` with prior agent work using OLD plan (11-state pattern + LKinCtrl_MC_Group* wrappers). Conflicts with approved plan's 6-state + no-libraries decision. |
| init | conflict_resolution.user_question | AskUserQuestion: how to handle prior 11-state+LKinCtrl work? User chose "Backup + rewrite to match new plan (Recommended)". |
| init | backup.move | Moved 6 files to `.backup/2026-05-17/`: 100_OB/Main.scl, 500_AutoCtrl/FB_AutoCtrl_ABCDE.scl, 1100_TIA Lib/LKinCtrl_Blocks/LKinCtrl_AuxBlocks/{LKinCtrl_MC_GroupPower.scl, LKinCtrl_MC_GroupHome.scl, LKinCtrl_MC_GroupReset.scl}, PLC data types/LKinCtrl_Types/LKinCtrl_typeAuxFCDiagnostics.xml. Removed empty parent dirs (LKinCtrl_Blocks/, LKinCtrl_Types/, LKinCtrl_Tags/, 1100_TIA Lib/). |
| init | source.rewrite | Rewrote `FB_AutoCtrl_ABCDE.scl` v2.0: 6-state pattern (0/10/20/30/40/50, cycle wrap 50→10 per source spec §3.3+§3.5). Single multi-instance MC_MoveLinearAbsolute. Removed LKinCtrl-dependent permissives (axesEnabled/axesHomed). Permissive simplified per source spec §2.2: bo_Mode AND bo_ESTOP_LOCK AND step=0 AND sRTRIGStart.Q AND bo_PathInitialed. Commented Phase F blending alternative inline. |
| init | source.author.new | New `FB_AxisCtrl.scl` v1.0: replaces LKinCtrl wrappers with multi-instance MC_Power[4] + MC_Home[4] + system MC_GroupReset on kinematic group. Per-axis Mirror outputs (axesEnabled = AND of 4 Status, axesHomed = AND of 4 Done, axesError = OR of 9 errors). **Plan deviation noted in file header**: plan called for "Axis_Call FC" but MC_GroupPower/Home don't exist as system instructions → FB (not FC) is required for multi-instance hosting. |
| init | source.rewrite | Rewrote `Main.scl` v2.0: 3 REGION blocks calling instFB_AxisCtrl() + instFB_AutoCtrl_ABCDE() + instFB_MCDDataTransfer(). Removed inline LKinCtrl_MC_Group* calls. Per-scan MC count: 10 declared, 4-5 actively pulsing. |
| init | source.edit | GDB_MachineCmd.xml: updated i16_AutoStep Member comment to 6-state semantics (was 11-state). Both en-US + zh-CN texts. |
| init | source.clone | Cloned 2 files from v9 `600_HMI Comm/` → new project `600_HMI_Comm/`: FB_MCDDataTransfer.scl (publishes ScaraArm3D.AxesData.A[i].{Position,Velocity} to GDB_MCDData) + GDB_MCDData.xml ({Position,Velocity}[1..4] : LReal). |
| init | source.clone | Cloned 3 handoff templates from v9 PM_Workspace: HMI_HANDOFF_TEMPLATE.md, PLC_HANDOFF_TEMPLATE.md, PM_HANDOFF_TEMPLATE.md. Cloned AGENT_CONTRACT.md from v9 VCIExportedContents/. |
| init | doc.bootstrap | Authored SCOREBOARD_PLC.md + PM_LEDGER.md (this file) bootstrap rows. |

(Following entries to be appended as this cycle continues — PROJECT_STATUS.md, HMI_BINDING_MAP.md, OPERATOR_PHASE_A_HANDOFF.md, git init.)

---

## 2026-05-17 — Session: PM tracker catch-up after ~10-hour gap (Phase A→F + Phase C HMI Verified + HMI Cycle 7_0 migration)

| Time | Event | Detail |
|---|---|---|
| | audit.role_clarification | User clarified: I am `scara-PM` agent for `hmiDemoSCARA_ABCDE`. v9 PM duties detached. Two parallel projects each with independent 3-agent teams (scara-PM/PLC/HMI vs v9-PM/PLC/HMI). Operator interfaces with both. |
| | audit.tracker_stale | Bootstrap row (above) abandoned mid-list at "(Following entries to be appended)". Actual disk state ~10 hours ahead: 3 commits + Phase D 9/9 + Phase F V8 5/5 + Phase C deployed + Phase C V6 8/8 + HMI Cycle 7_0 source-compile-green + 2 NEW C66-prefix PLC handoffs landed. |
| | files.move | Moved 5 HMI Cycle 7_0 Phase A-E handoffs from `v9/UserFiles/VCIExportedContents/` → `SCARA_ABCDE/UserFiles/VCIExportedContents/` per user direction. TIA target was always SCARA — handoffs landed in v9 tree as historical cross-post (AGENT_CONTRACT §4.4 "v9 = canonical comm tree" convention). Now correctly co-located with their subject project. |
| | absorb.phase_a | OPERATOR_PHASE_A_HANDOFF executed end-to-end by operator: TIA project + PLC_1 (1511T) + HMI_1 (MTP1000 UBP 1024×600) + PROFINET + 5 TO XMLs imported. Confirmed by commit `79cae9a` ("Fix VCI import errors: invalid MC_GROUPRESET + Position[i] syntax + DB# collisions + missing iDBs"). |
| | absorb.phase_b | Integration compile 0W/0E confirmed via commit history. All 9 source files in `PLC_1/` (UDT + 2 GDBs + Startup + Main + FB_AxisCtrl + FB_AutoCtrl_ABCDE + FB_MCDDataTransfer + GDB_MCDData). |
| | absorb.phase_c | HMI screens spec'd in `HMI_1/Screens/*.md` (5 specs: 00_README + Home + Target + Actual_Pos + Actual_Joints) for manual operator authoring. Plus HMI agent's Cycle 7_0 (14 UBP screens authored programmatically — separate path). PLC_HANDOFF_2026-05-17_PhaseC_HMIScreens.md (18:34) drafted by scara-PLC agent. |
| | absorb.phase_d | Phase D 9/9 PASS via PLCSIM-Adv API (commit `d20319a`, log `phaseD_20260517_180109.log`). All V1-V5 + V-OB91-Inferred gates verified. |
| | absorb.phase_f_v8 | Phase F V8 5/5 PASS (commit `c2d4f86`, log `phaseF_V8_20260517_182059.log`). BufferMode=5 + progress>0.5 advance verified. 22% throughput gain vs Phase D. |
| | absorb.phase_c0_mcd_mirror | Phase C.0 GDB_MCDData extension: 8 explicit J{n}_ActualPosition/Velocity members added (FB_MCDDataTransfer rev 0.1→0.2). Closes PLCSIM-Adv API gap (TO_Axis not exposed via API). Backup at `.backup/2026-05-17_PhaseC_PreMirrorExtend/`. |
| | absorb.phase_c0b_tool_fix | Phase C.0b FB_AxisCtrl rev 1.1→1.2 backport from v9 (MC_SetTool defensive activation closes UserFault root cause: ToolNumber=0 post-MRES → motionFBStatus 0x8001). statToolActivated Bool added. Backup at `.backup/2026-05-17_PhaseC_PreToolFixBackport/`. |
| | absorb.phase_c_verified | Phase C V6 8/8 PASS via SmokeTest_PhaseC_V6.ps1 (log `phaseC_V6_20260517_233032.log`). 6 ABCDE wraps in 60s, 0 coord mismatches, J1/J2 swung 50°/449°. **Plan Goal 2 (HMI shows target XYZA) DONE**. |
| | absorb.hmi_cycle7_0 | HMI agent's Cycle 7_0 Phase A→E source-side compile-green: 111→14→0 TIA HMI Compile errors. 14 UBP screens (Layout + 5-tab nav + Auto + Manual + 4 per-axis deep-drill + Diag/Config placeholders) + 7 HMI tags (3 internal `Ubp_*` + 4 PLC-bound Bool). Phase F runtime smoke = only remaining HMI-side gate. |
| | absorb.phase_g_proposal | scara-PLC drafted PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md (INFORMATIONAL): proposes GDB_ManualCmd + GDB_ManualStatus + FB_ManualCtrl for cycle-7.2 unblock. 6 open questions for HMI agent. Blocks HMI cycle-7.1/7.2 rebinds until ACK + Phase G ships. |
| | architecture.j2_j3_swap | Discovered + documented in C66 PhaseC_HMI_Verified §6.1: `J{n}.ActualPosition` (TO_Axis direct, HMI binding) vs `ScaraArm3D.AxesData.A[i].Position` (kinematic-group view, GDB_MCDData mirror) — J2 ↔ Position[3], J3 ↔ Position[2] (swap). Resolution: explicit `J{n}_ActualPosition` mirror is canonical for HMI parity; legacy `Position[i]` array kept for NX MCD signal adapter back-compat. |
| | architecture.userfault_universal | UserFault root cause (MC_SetTool / ToolNumber=0) is universal across v9 + SCARA — same defensive activation needed both projects post-MRES. Original Phase D + F V8 at `c2d4f86` passed by luck (ToolNumber active from prior session). C.0b backport closes this loose end. |
| | architecture.cold_start_sequence | Cold-start must be: Reset → Enable → HomeMode=7 (set actual to HomePos) → InitPath → Start. Skipping Home leaves joints at MRES-garbage (J1=-40, J2=-900, J3=-160, J4=78) → IK solver can't path-plan → cycle stalls at step 10 even with Tool[1] active. Documented in C66 PhaseC §6.3. |
| | scoreboard.refresh | Updated SCOREBOARD_PLC: bumped "Last updated" + "Last action" to 2026-05-17 catch-up narrative. A.1-A.9 → ✅; A.10 → 🚧 (D + F V8 + Phase C V6 = 3 partial); B.1-B.5 ✅; B.6 → 🚧 (D + F V8 + Phase C V6 partial; full V-suite still owed). Removed §6 "no HMI agent counterpart" stale note. |
| | project_status.refresh | PROJECT_STATUS.md already updated by scara-PLC agent through Phase C (lines 14-36 reflect reality); PM bumps "Last updated" line 6 + adds plan-deviation row for HMI Cycle 7_0 migration. |
| | handoff.write | Authored `PM_HANDOFF_2026-05-17_PhaseAtoF_Catchup.md` on PM_Workspace (status VERIFIED — Phase D + F V8 + C V6 all verified + Cycle 7_0 compile-green). |
| | git.commit | Single commit on master absorbing: 2 NEW C66-prefix scara-PLC handoffs + OPERATOR_PHASE_C_HANDOFF + PLC_HANDOFF Phase C + 5 moved HMI Cycle 7_0 handoffs + HMI_1/ folder + 4 modified SCL/XML + HMI_BINDING_MAP + PROJECT_STATUS + harness/Plcsim_Robust + SmokeTest_PhaseC_V6 + harness/results logs + .backup/ dirs + PM tracker (SCOREBOARD + LEDGER + new handoff). |
| | git.push | PAUSED for user authorization per AGENT_CONTRACT.md §4.3 (PM-as-sole-pusher; explicit per-push user auth required). |
| | next.gates | HMI Cycle 7_0 Phase F runtime smoke (operator); SCARA V7 full MCD link (Phase E deferred); manual-mode tag proposal HMI ACK (cycle-7.2 unblock); operator daily handoff to 郑老板 about Goal 2 ✅ achievement. |
| | next.session | scara-PLC: await HMI ACK of manual-mode tag proposal, then Phase G author. scara-HMI: Phase F runtime smoke + cycle-7.2 manual-mode rebind after Phase G. scara-PM: log Phase G + cycle-7.2 outcomes when landed. |

---
