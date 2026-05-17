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
