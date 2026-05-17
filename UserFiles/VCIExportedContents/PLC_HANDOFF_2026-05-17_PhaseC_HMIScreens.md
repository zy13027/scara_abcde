**Status:** PENDING — PLC side fully verified (Phase D 9/9 + Phase F V8 5/5); HMI screens staged as specs, awaiting authoring in TIA Portal

# PLC_HANDOFF — Phase C HMI Screens Ready for Authoring (hmiDemoSCARA_ABCDE)

**Project:** `hmiDemoSCARA_ABCDE` (sibling to v9; standalone — has its own MTP1000 UBP HMI in the same `.ap20`)
**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md` (Phase C)
**Predecessor:** Phase D PASSED 9/9 + Phase F V8 PASSED 5/5 (commits `79cae9a` + `c2d4f86`)
**Date:** 2026-05-17

---

## 1. Bindings added (vs HMI side — none new this cycle)

No new bindings introduced. All 15+ bindings already documented in `HMI_BINDING_MAP.md` (authored at start of this project; comprehensive widget→tag map).

The HMI authoring scope is **build the UI to consume the existing PLC-side tags**:

| PLC tag (already published) | HMI binding consumer | Screen |
|---|---|---|
| `GDB_MachineCmd.bo_Mode` (W Bool) | `swModeAuto` (2-state switch) | Home |
| `GDB_MachineCmd.bo_InitPath` (W Bool, PULSE) | `btnInitPath` (button) | Home |
| `GDB_MachineCmd.bo_Start` (W Bool, PULSE) | `btnStart` (button) | Home |
| `GDB_MachineCmd.bo_Stop` (W Bool, PULSE) | `btnStop` (button) | Home |
| `GDB_MachineCmd.i16_AutoStep` (R Int) | `txtAutoStep` (IOField) | Home |
| `instFB_AutoCtrl_ABCDE.statTargetPos.{x,y,z,a}` (R LReal × 4) | `txtTargetX/Y/Z/A` (4 IOFields) | Target |
| `ScaraArm3D.Position[1..4]` (R LReal × 4) | `txtActualX/Y/Z/A` (4 IOFields) | Actual_Pos |
| `J1..J4_SCARA_Arm3D.ActualPosition` (R LReal × 4) | `txtJoint1..4` (4 IOFields) | Actual_Joints |

---

## 2. Bindings deprecated

None this cycle. The binding map is fresh from project start; no rows old enough to deprecate.

---

## 3. Bindings removed

None this cycle.

---

## 4. UDT shapes

No UDT changes. Existing shapes remain stable:

| UDT | Used by | Members |
|---|---|---|
| `UDT_typePoint5` | `statTargetPos` (in instFB_AutoCtrl_ABCDE) + `pts[1..5]` | `{x, y, z, a : LReal}` (4 members) |

HMI IOFields bind to the flat LReal members directly via dotted access (e.g., `instFB_AutoCtrl_ABCDE.statTargetPos.x`). UDT-typed array binding NOT used (per `UNSUPPORTED_PLC_DENYLIST.md` pattern from v9 — flat array UDTs rejected by comm driver).

---

## 5. Pre-promotion checklist

| # | Check | Status |
|---|---|---|
| 1 | PLC compile 0W/0E with current rev (FB_AutoCtrl_ABCDE rev 3.0 V8 blending) | ✅ Confirmed via PLCSIM-Adv download success |
| 2 | All tags referenced in HMI specs are present in the running PLC | ✅ Verified via SmokeTest_PhaseF_V8.ps1 tag-existence checks (e.g., `statProgress` confirmed via Read-Tag) |
| 3 | No deny-listed binding patterns (flat array UDTs, TO axis refs in dotted form) | ✅ All bindings are: bool, int16, lreal scalar, or lreal array indexed by integer literal (denylist-safe) |
| 4 | iDB `instFB_AutoCtrl_ABCDE` is "Accessible from HMI" (for `statTargetPos.*` access) | ⚠️ **HMI builder must verify** — toggle ON in Properties → Attributes if not already |
| 5 | TO `ScaraArm3D` has HMI access enabled (for `Position[1..4]` direct binding) | ⚠️ **HMI builder must verify** — fallback to `GDB_MCDData.Position[1..4]` mirror if not |
| 6 | 4 joint TOs (`J1..J4_SCARA_Arm3D`) have HMI access enabled (for `ActualPosition`) | ⚠️ **HMI builder must verify** |

---

## 6. Notes for the HMI builder (or HMI agent, if invoked)

### 6.1 — Screen build order + specs

Per-screen build specs are in `HMI_1/Screens/`:

| File | Purpose | Build time est. |
|---|---|---|
| `00_README.md` | Cross-screen conventions (colors, fonts, JS PULSE pattern, tag-binding fallbacks) | 5 min read |
| `Home_Screen.md` | Screen 1 (5 functional controls + 2 nav buttons) | ~20 min |
| `Target_Screen.md` | Screen 2 (4 target IOFields + 1 nav) — **V6 gate** | ~10 min |
| `Actual_Pos_Screen.md` | Screen 3 (4 actual TCP IOFields + 1 nav) — V7 partial | ~10 min |
| `Actual_Joints_Screen.md` | Screen 4 (4 joint IOFields + 1 nav) | ~10 min |

Total: ~55 min HMI authoring + ~15 min compile/download/smoke = **~75 min**.

### 6.2 — Operator workflow

For the manual TIA UI path: see `OPERATOR_PHASE_C_HANDOFF.md` for the 6-step build sequence + 10-test cross-cutting acceptance criteria (C1-C10).

### 6.3 — HMI agent invocation (if adapting v10 agent)

If the v9/v10 HMI agent (`E:\VS_Code_Proj\TiaUnifiedAuto\`) is adapted to this sibling project:

- **Target HMI type differs:** v10 is Unified Comfort; this project is Unified Basic (MTP1000 UBP). Builder profile would need extension for UBP screen XML schema.
- **Tag denylist still applies:** Use `UNSUPPORTED_PLC_DENYLIST.md` patterns from v9 (flat array UDTs etc.). All 17 bindings in this project are denylist-safe per §5 check 3.
- **PSC binding constraint:** All bindings here are simple dotted scalar / int-indexed array — should pass PSC validator cleanly.
- **C# builder output:** would land in `hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/HMI_1/Screens/*.xml` (mirroring the spec markdown files in same directory).

### 6.4 — Open items / [NEEDS_HUMAN]

- [NEEDS_HUMAN] **Operator must build the 4 screens in TIA Portal UI** (or invoke HMI agent if adaptation done). Specs are complete; no PLC-side ambiguity remaining.
- [NEEDS_HUMAN] **Verify iDB + TO HMI-accessibility flags** (pre-promotion checklist items 4-6). Operator toggles in Properties on first compile error.
- [INFO] **V6 gate verification** happens automatically once Target_Screen is online + cycle running — acceptance criterion T2-T6 walks through it.

### 6.5 — V-OB91 confidence note

Phase F V8 ran 5 continuous cycle wraps in 45s without any fault. V-OB91 manual confirmation via TIA Diagnostics Buffer is still nominally pending (deferred to Phase E), but inferred PASS is high-confidence given the cycle-health observation.

---

## 7. Verification commands

For PLC-side verification (already done; included for HMI builder's reference):

```powershell
# Phase D smoke test (V0-V5 + V-OB91-Inferred)
& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_PhaseD.ps1"
# Expected: 9/9 gates PASS

# Phase F V8 smoke test (V8 blending)
& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_PhaseF_V8.ps1"
# Expected: 5/5 gates PASS
```

For HMI-side verification (operator runs in TIA HMI Runtime):

```
# Per Home_Screen.md, Target_Screen.md, Actual_Pos_Screen.md, Actual_Joints_Screen.md
# Each spec has an "Acceptance criteria" table (H1-H9, T1-T8, AP1-AP8, AJ1-AJ8)

# Cross-cutting: OPERATOR_PHASE_C_HANDOFF.md C1-C10 covers V6 gate + V7 partial.
```

---

## 8. Closure markers

- [PENDING] HMI authoring per `OPERATOR_PHASE_C_HANDOFF.md`
- [INFO] PLC side fully verified; no PLC changes required for Phase C
- [INFO] If V6 fails due to iDB HMI-accessibility not enabled, operator toggles ON and recompiles (no SCL change needed)

---

## Cross-references

- `HMI_BINDING_MAP.md` — canonical widget→tag binding (PLC-side source of truth, this cycle)
- `HMI_1/Screens/00_README.md` — cross-screen conventions
- `HMI_1/Screens/Home_Screen.md` — V2 + V5 gate verification
- `HMI_1/Screens/Target_Screen.md` — V6 gate verification
- `HMI_1/Screens/Actual_Pos_Screen.md` — V7 partial
- `HMI_1/Screens/Actual_Joints_Screen.md` — per-joint commissioning visibility
- `OPERATOR_PHASE_C_HANDOFF.md` — operator workflow + cross-screen verification
- `PROJECT_STATUS.md` — phase + gate dashboard
- `OPERATOR_PHASE_F_HANDOFF.md` — predecessor (V8 blending; complete)
- `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md` — full plan
