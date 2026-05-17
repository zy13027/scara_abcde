# PROJECT_STATUS — hmiDemoSCARA_ABCDE

**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`
**Source spec:** `UserFiles/VCIExportedContents/杨子楠5月17日周计划.md`
**Predecessor:** `hmiDemoMomoryCapacity_v9` (archived sibling, untouched)
**Last updated:** 2026-05-17 (initial)

---

## Phase status

| Phase | Description | Status | Notes |
|---|---|---|---|
| **A** | Project bootstrap (.ap20 + hardware + PROFINET + TO XML import) | 🚧 Source files staged on disk; TIA Portal manual UI steps pending operator | See `OPERATOR_PHASE_A_HANDOFF.md` |
| **B** | Author core PLC code (UDT + DBs + Startup OB + FB_AxisCtrl + FB_AutoCtrl_ABCDE + Main OB + FB_MCDDataTransfer) | ✅ Source files authored to disk; awaiting Openness import + 0W/0E compile | All 9 source files present in `PLC_1/` subtree |
| **C** | HMI screens (4 screens per UBP 5-control cap) | ⏸️ Blocked on Phase A.7 (HMI device addition) | See `HMI_BINDING_MAP.md` |
| **D** | PLCSIM-Adv smoke test (V1–V7 + V9 gates) | ⏸️ Blocked on Phase A–C completion | New PLCSIM-Adv instance `1511T_ABCDE` at 192.168.0.40 |
| **E** | NX MCD integration (V7 full + V-OB91 gate) | ⏸️ Deferred — separate cycle after Phase D | Reuse v9 MCD scene at `E:/NX_Proj/XMD-1001-00-000 立柱旋转机器人(西门子系统)/` |
| **F** | Blending mode (V8 gate, optional) | ⏸️ Deferred — separate cycle after Phase E | Source spec §3.6 — replaces .Done-trigger with progress>50% + BufferMode=BLENDING_HIGH |

---

## Verification gate status

| Gate | Description | Status | Owner | Notes |
|---|---|---|---|---|
| **V1** | No bloat in project tree (only 5 TOs + 9 user blocks; no FB_PalletizingProgramme; no LKinCtrl/LPallPatt/LSKI/LAxisCtrl) | ✅ Trivially passes — new project starts empty + no library imports | PM | Confirmed by `find` audit + LKinCtrl backup |
| **V2** | Start triggers state machine (HMI bo_Start → i16_AutoStep 0→10 within 1 scan) | ⏸️ Blocked on Phase D.5 | Operator | |
| **V3** | ABCDE sequential execution (step 10→20→30→40→50 on .Done) | ⏸️ Blocked on Phase D.6+D.7 | Operator | 6-state pattern; no intermediate "arrived" states |
| **V4** | Continuous cycle (step 50 → 10 cycle wrap, runs until Stop) | ⏸️ Blocked on Phase D.6 (≥ 3 cycles observed) | Operator | |
| **V5** | Stop responsiveness (HMI bo_Stop → step:=0 within 1 scan) | ⏸️ Blocked on Phase D.9 | Operator | |
| **V6** | Target position display (HMI 4 IOFields = statTargetPos.x/y/z/a) | ⏸️ Blocked on Phase C HMI authoring + Phase D | Operator | |
| **V7** | MCD end-to-end link (NX viewport shows SCARA following ABCDE) | ⏸️ Blocked on Phase E | Operator | |
| **V8** | Blending formed (StateOfMotion never Standstill between points) | ⏸️ Blocked on Phase F (optional) | Operator | Source spec §3.6; V8 is the "advanced" gate |
| **V9** | Code size ≤ 2000 lines (wc -l on all new SCL) | 🚧 Will run after Phase B file authoring complete this cycle | PM | Expected ~200-300 lines actual |
| **V-OB91** | OB91 buffer overflow gate (ZERO "Buffer overflow for OB 91" events after 30s cycle) | ⏸️ Blocked on Phase E | Operator | THE root-cause gate for the rebuild |

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

---

## Refresh model

Updated at end of every cycle. Phase status icons + verification gate icons reflect current reality. Plan-deviation log is append-only.
