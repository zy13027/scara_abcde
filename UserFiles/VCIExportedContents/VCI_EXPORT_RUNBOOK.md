# VCI Export / Import Runbook — hmiDemoSCARA_ABCDE

**TIA project:** `hmiDemoSCARA_ABCDE.ap20`  
**Disk tree:** `UserFiles/VCIExportedContents/PLC_1/` (and HMI handoffs alongside)

This runbook fixes the common VCI export errors **“already mapped”** and **“maximum path length”** seen on 2026-05-21.

---

## Error quick reference

| Message | Meaning | Action |
|---------|---------|--------|
| `already mapped to the file(s) '...\*.scl'` | Block is already an **external source** linked to that path | **Do not** full re-export; use **Generate blocks from source** (below) |
| `would exceed the maximum path length` | Windows path > ~260 chars | Shorten project path and/or **exclude** `900_TIALib` from export (below) |
| `Export not possible` (after many “already mapped”) | Full export aborted; disk may still be usable | Use routine sync; fix path issue only if you need every LKinCtrl file on disk |

---

## Normal workflow (recommended — after agent edits on disk)

Use this for day-to-day **VCI-sync** / PLC handoffs. **No VCI export required.**

1. Open TIA Portal V20 → `hmiDemoSCARA_ABCDE.ap20`.
2. In project tree: **PLC_1** → **Program blocks** → **External source files**.
3. For each file changed under `VCIExportedContents/PLC_1/...`:
   - Right-click the `.scl` or `.xml` entry → **Generate blocks from source**.
4. Right-click **PLC_1** → **Compile** → **Software (rebuild all)** (not “only changes”).
5. Expected: **0 errors, 0 warnings** (re-create `instFB_*` if TIA prompts after FB interface changes).
6. Download to PLCSIM/device if needed.

**References:** [OPERATOR_PHASE_F_HANDOFF.md](OPERATOR_PHASE_F_HANDOFF.md) Step 3–4; palletizing handoffs “VCI-sync”.

---

## Full VCI export (only for a clean disk snapshot)

Run full export **only** when you intentionally refresh the whole tree on disk.

### Option A1 — Unlink, then export to same folder

1. Stop PLCSIM / go offline.
2. **PLC_1** → **External source files** → select all links → **Delete** (removes **mapping only**; files on disk usually remain).
3. VCI → Export to `UserFiles\VCIExportedContents\`.
4. Re-import anything TIA still needs per [OPERATOR_PHASE_A_HANDOFF.md](OPERATOR_PHASE_A_HANDOFF.md) Step 6 if blocks show broken links.

**Risk:** Temporary loss of external linkage until re-import.

### Option A2 — Export to a new empty folder (safer)

1. Create empty folder: e.g. `UserFiles\VCIExportedContents_export_YYYYMMDD\`.
2. VCI Export **only** into that folder.
3. Diff with git; merge deliberately; keep old tree as backup.

Avoids fighting hundreds of existing mappings in the live `VCIExportedContents` tree.

---

## Path length fix (`900_TIALib` / LKinCtrl)

One block often fails export:

`LKinCtrl_CalcCircPathChoiceByIntermediatePointAndEndPoint.scl`

Full path under this project is ~**262 characters** (Windows legacy limit **260**).

### B1 — Shorten project base path (most reliable)

Example: move or clone project to `E:\TIA\hmiDemoSCARA\` and reopen `.ap20` from there. Re-check **External source files** paths in TIA if you moved the folder.

### B2 — Enable Windows long paths

1. Windows: enable long path support (Group Policy “Enable Win32 long paths” or registry `LongPathsEnabled=1`).
2. In repo: `git config core.longpaths true`
3. Restart TIA Portal; retry export.

TIA/VCI may still hit legacy APIs — prefer B1 if export still fails.

### B3 — Exclude `900_TIALib` from VCI export (pragmatic)

In the VCI export scope, **exclude**:

- `PLC_1/Program blocks/900_TIALib/**`
- Optionally `PLC data types/LKinCtrl_*` if agents do not edit them

**Rationale:** Application code (100_OB, 500_AutoCtrl, 600_*, 700_, instances, TOs) is what agents edit. LKinCtrl blocks live **inside TIA** as library copies; disk export is for agent-maintained sources only.

See [900_TIALib/README_EXPORT.md](PLC_1/Program%20blocks/900_TIALib/README_EXPORT.md).

---

## What is already on disk (2026-05-21)

After a partial export, these areas are typically **already mapped** and **do not need re-export**:

- `100_OB/` — Main, Startup, CyclicInterrupt_10ms
- `500_AutoCtrl/` — Auto, manual, palletizing FBs and GDBs
- `600_HMI_Comm/` — MCD transfer, HMI status facade
- `600_AxisControl/` — GDB_AxisCtrl (if present in project)
- `700_/` — FB_MovePath, GDB_MovePath
- `instances/` — instFB_* iDBs
- `Technology objects/` — ScaraArm3D, J1–J4
- Most of `900_TIALib/` except the one path-length failure

---

## Post-sync verification checklist

- [ ] **Compile → Software (rebuild all)** → 0E / 0W
- [ ] Spot-check: Project tree → block → external source path points under `VCIExportedContents\PLC_1\...`
- [ ] `Main.scl` still calls correct `instFB_*` names
- [ ] After FB interface change: delete/recreate iDB if TIA shows interface mismatch
- [ ] `git status` under `VCIExportedContents/PLC_1/` — only expected diffs
- [ ] Smoke harness or watch-table spot check if you changed motion logic

---

## What NOT to do

- Do not delete the whole `VCIExportedContents` folder while TIA still references those paths.
- Do not rename FB numbers in TIA without updating `Main.scl` and `instances/`.
- Do not run full VCI export after every agent edit — use **Generate blocks from source**.
- Do not treat hundreds of “already mapped” lines as PLC compile errors.

---

## Related docs

- [OPERATOR_PHASE_A_HANDOFF.md](OPERATOR_PHASE_A_HANDOFF.md) — initial external source import
- [OPERATOR_PHASE_F_HANDOFF.md](OPERATOR_PHASE_F_HANDOFF.md) — re-import single SCL after edit
- [PROJECT_STATUS.md](PROJECT_STATUS.md) — VCI / LKinCtrl export note
- [AGENT_BOOTSTRAP_PLC.md](AGENT_BOOTSTRAP_PLC.md) — agent write lane under `VCIExportedContents/PLC_1/`
