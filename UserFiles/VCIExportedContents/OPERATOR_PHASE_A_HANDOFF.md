# OPERATOR_PHASE_A_HANDOFF — TIA Portal Manual UI Steps

**Project:** `hmiDemoSCARA_ABCDE`
**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`
**Source spec:** `UserFiles/VCIExportedContents/杨子楠5月17日周计划.md`
**Date:** 2026-05-17
**Status:** READY FOR OPERATOR — all source files staged on disk; TIA Portal UI work needed to create the `.ap20` and import them

---

## Why this handoff exists

The PM agent has authored / cloned / staged all 9 PLC source files (XML + SCL) and 5 TO XMLs into `UserFiles/VCIExportedContents/PLC_1/`. But these can't be ingested by TIA Portal until the `.ap20` project exists with the correct hardware configuration. **Creating a new TIA project + adding hardware devices is operator-manual** (no headless Openness path before the `.ap20` exists).

This handoff lists the 8 TIA Portal UI steps the operator needs to do, in order, with exact paths/parameters/screenshots-to-take. Once done, the PM agent (or a tia-openness PowerShell skill) can take over for source import + compile + download.

---

## What's already on disk (verify before starting)

```
E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/
├── UserFiles/
│   ├── PM_Workspace/
│   │   ├── SCOREBOARD_PLC.md          (PM live to-do)
│   │   ├── PM_LEDGER.md               (append-only history)
│   │   ├── HMI_HANDOFF_TEMPLATE.md
│   │   ├── PLC_HANDOFF_TEMPLATE.md
│   │   └── PM_HANDOFF_TEMPLATE.md
│   └── VCIExportedContents/
│       ├── AGENT_CONTRACT.md          (cloned from v9 — lane discipline rules)
│       ├── PROJECT_STATUS.md          (Phase A-F + V1-V9 status board)
│       ├── HMI_BINDING_MAP.md         (4-screen widget map)
│       ├── OPERATOR_PHASE_A_HANDOFF.md (this file)
│       ├── 杨子楠5月17日周计划.md     (operator's source spec)
│       └── PLC_1/
│           ├── PLC data types/
│           │   └── UDT_typePoint5.xml
│           ├── Program blocks/
│           │   ├── 100_OB/
│           │   │   ├── Main.scl               (v2.0 — calls instFB_AxisCtrl + AutoCtrl_ABCDE + MCDDataTransfer)
│           │   │   ├── Startup.scl            (inits StartMode/StopMode/HomePos/HomeMode + clears cmd bits)
│           │   │   └── GDB_Control.xml        (enable/home/reset arrays)
│           │   ├── 500_AutoCtrl/
│           │   │   ├── FB_AxisCtrl.scl        (NEW v1.0 — per-axis MC_Power[4] + MC_Home[4] + system MC_GroupReset)
│           │   │   ├── FB_AutoCtrl_ABCDE.scl  (v2.0 — 6-state pattern + multi-instance MC_MoveLinearAbsolute)
│           │   │   └── GDB_MachineCmd.xml     (Wang Shuo cmd struct, i16_AutoStep 6-state semantics)
│           │   └── 600_HMI_Comm/
│           │       ├── FB_MCDDataTransfer.scl (cloned verbatim from v9)
│           │       └── GDB_MCDData.xml        (cloned verbatim from v9)
│           └── Technology objects/
│               ├── J1_SCARA_Arm3D/J1_SCARA_Arm3D.xml
│               ├── J2_SCARA_Arm3D/J2_SCARA_Arm3D.xml
│               ├── J3_SCARA_Arm3D/J3_SCARA_Arm3D.xml
│               ├── J4_SCARA_Arm3D/J4_SCARA_Arm3D.xml
│               └── ScaraArm3D.xml
└── .backup/2026-05-17/                (prior 11-state+LKinCtrl work, kept for reference)
```

---

## 8-step operator workflow

### Step 1 — Open TIA Portal V20 + create new project

1. Launch TIA Portal V20
2. Project view → **Project → New**
3. Project name: `hmiDemoSCARA_ABCDE`
4. Path: `E:/TIA_Project_Directory_V20/` (so the `.ap20` lands sibling to the existing `UserFiles/` folder)
5. Click **Create**

**Verification:** project tree shows the new project; `E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/hmiDemoSCARA_ABCDE.ap20` file exists.

---

### Step 2 — Add Device 1: PLC_1 (S7-1511T-1 PN at firmware V4.0)

1. Project tree → double-click **Add new device**
2. Select **Controllers → SIMATIC S7-1500 → CPU → CPU 1511T-1 PN**
3. Order number: `6ES7 511-1TK02-0AB0` (or successor — confirm catalog)
4. Firmware version: **V4.0**

   **Fallback:** If V4.0 is not yet in the TIA V20 catalog for that order number, drop to V3.0 (v9's tested baseline). Document the fallback in `PROJECT_STATUS.md → Plan-deviation log`.

5. Device name: `PLC_1`
6. Click **Add**

**Verification:** project tree → `PLC_1 [CPU 1511T-1 PN]` appears; device view shows the CPU + rack/slot layout.

---

### Step 3 — Add Device 2: HMI_1 (MTP1000 Unified Basic Panel 10")

1. Project tree → double-click **Add new device**
2. Select **HMI → SIMATIC Basic Panel → 10" Display → MTP1000 Unified Basic**
3. Order number: `6AV2123-3KB32-0AW0`
4. Resolution: 1280×800 (default)
5. Skip the device wizard's auto-tag-table-creation step (we'll create tags manually per `HMI_BINDING_MAP.md`)
6. Click **Add**

**Verification:** project tree → `HMI_1 [MTP1000 Unified Basic]` appears.

---

### Step 4 — PROFINET network: link PLC ↔ HMI

1. Project tree → **Devices & networks** view
2. Drag a connection line from `PLC_1` PROFINET interface to `HMI_1` PROFINET interface
3. Default subnet (PN/IE_1) accepted

**Verification:** Network view shows PLC_1 ↔ HMI_1 link; both devices share PN/IE_1 subnet.

---

### Step 5 — Import 5 TO XMLs (Technology Objects)

For each of the 5 TO XML files (`J1_SCARA_Arm3D` / `J2_..` / `J3_..` / `J4_..` / `ScaraArm3D`):

1. Project tree → `PLC_1` → expand **Technology objects**
2. Right-click **Technology objects** → **Add Technology Object → "From existing XML"** (or similar — check exact menu label in V20)
3. Source XML: `E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/PLC_1/Technology objects/<TO_name>/<TO_name>.xml`
4. TIA prompts for any conflicts → accept defaults
5. TIA reports "Configuration OK" when import succeeds

Order: J1, J2, J3, J4 first (TO_PositioningAxis), then ScaraArm3D (TO_Kinematics — depends on J1-J4).

**Verification:** project tree → `Technology objects` shows 5 children, all with green status. Each TO double-clicks open and reports "Configuration OK".

---

### Step 6 — Import 9 PLC source files (Program blocks + PLC data types)

This step is **Openness-scriptable** (via PowerShell + tia-openness skill) if desired, but can also be done manually:

**6a. PLC data type (1 file):**
- Right-click `PLC_1` → `PLC data types` → **External source files → Add new external file** → select `UserFiles/VCIExportedContents/PLC_1/PLC data types/UDT_typePoint5.xml`
- OR via External Sources Group `Add new external source file` then `Generate blocks from source`

**6b. Global DBs (4 files):**
- `GDB_Control.xml` (in `100_OB/` folder — operator can re-organize to a `400_DB/` group if preferred)
- `GDB_MachineCmd.xml` (in `500_AutoCtrl/`)
- `GDB_MCDData.xml` (in `600_HMI_Comm/`)
- (`HMI tag table` to be created in step 7, not part of this)

**6c. SCL blocks (5 files):**
- `100_OB/Main.scl` (OB1)
- `100_OB/Startup.scl` (OB100)
- `500_AutoCtrl/FB_AxisCtrl.scl` (FB)
- `500_AutoCtrl/FB_AutoCtrl_ABCDE.scl` (FB)
- `600_HMI_Comm/FB_MCDDataTransfer.scl` (FB)

For each SCL: right-click `Program blocks` → **External source files → Add new external file** → select file → then **Generate blocks from source**.

TIA Portal may prompt for iDB names when generating FBs. Use:
- `FB_AxisCtrl` → `instFB_AxisCtrl`
- `FB_AutoCtrl_ABCDE` → `instFB_AutoCtrl_ABCDE`
- `FB_MCDDataTransfer` → `instFB_MCDDataTransfer`

(These names match what Main.scl calls.)

**Verification:** project tree → `Program blocks` shows OB1 + OB100 + 3 FBs + 3 iDBs + 3 global DBs + UDT (under PLC data types). All green status.

---

### Step 7 — HMI screen authoring (Phase C — per `HMI_BINDING_MAP.md`)

4 screens to author manually in TIA Portal HMI screen editor (Openness HMI authoring is heavy + slow; manual screen edit is faster for 15 widgets total). See `HMI_BINDING_MAP.md` for widget-by-widget detail.

This step can be deferred until **after** step 8 compile passes.

---

### Step 8 — Compile entire project + expected 0W/0E

1. Project tree → right-click `PLC_1` → **Compile → Hardware and software (only changes)**
2. Wait for compile completion
3. **Expected result:** 0 warnings, 0 errors

**If errors surface:**

| Symptom | Diagnosis | Fix |
|---|---|---|
| "MC_GroupPower not defined" | Operator imported the wrong file — `FB_AxisCtrl` uses raw `MC_Power` per joint, not MC_GroupPower | Verify the imported `FB_AxisCtrl.scl` matches what's on disk (4× `MC_POWER` multi-instance, not LKinCtrl_MC_GroupPower) |
| "ScaraArm3D not declared" | TO XMLs not imported, or imported with different name | Re-do Step 5; verify TO name spelling matches Main.scl/FB_AutoCtrl_ABCDE.scl references |
| "instFB_AxisCtrl not declared" | iDB naming mismatch in Step 6c | Rename the iDB to `instFB_AxisCtrl` in TIA → Properties |
| "GDB_MCDData not declared" | GDB_MCDData.xml not imported | Re-do Step 6b for GDB_MCDData |

---

## After Phase A success

Once **8/8 steps pass** with 0W/0E compile:
1. Operator runs Phase D smoke test (V1–V7 + V9 gates) per plan
2. PM agent writes a follow-up handoff in `VCIExportedContents/PLC_HANDOFF_2026-05-XX_PhaseA_Complete.md` confirming compile pass + lessons learned + any plan deviations
3. PROJECT_STATUS.md Phase A row → ✅; Phase B/C → ✅ (since source files already on disk pre-import); Phase D → 🚧

---

## Notes for the operator

- **Save the project** after Step 4 (before TO import) — gives a clean rollback point.
- **Save after Step 5** (post-TO import) — TO imports can be fiddly; clean save lets you re-do Step 6 without losing TO setup.
- **DON'T compile until after Step 6** — partial blocks (e.g., Main.scl referencing not-yet-imported FB_AxisCtrl) will show false errors.
- TIA Portal V20 may auto-create iDBs with different names than expected. Always verify iDB names match what `Main.scl` calls (`instFB_AxisCtrl`, `instFB_AutoCtrl_ABCDE`, `instFB_MCDDataTransfer`).
- If V4.0 firmware isn't in catalog → V3.0 is acceptable; document the fallback in `PROJECT_STATUS.md → Plan-deviation log`.

---

## Cross-references

- `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md` — full plan (Phase A details in `### Phase A — Project bootstrap` section)
- `PROJECT_STATUS.md` — Phase + Verification status board (kept current by PM)
- `HMI_BINDING_MAP.md` — Phase C HMI screen widget map (operator authors per this map)
- `SCOREBOARD_PLC.md` (in `PM_Workspace/`) — PM agent's live to-do list
- `.backup/2026-05-17/` — prior agent's 11-state+LKinCtrl work, kept for reference/comparison
