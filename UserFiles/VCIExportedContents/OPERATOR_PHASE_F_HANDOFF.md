# OPERATOR_PHASE_F_HANDOFF — V8 Blending (Phase F)

**Project:** `hmiDemoSCARA_ABCDE`
**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md` (Phase F)
**Predecessor:** Phase D PASSED 9/9 gates on 2026-05-17 (`harness/results/phaseD_20260517_180109.log`)
**Date:** 2026-05-17

---

## What changed

`FB_AutoCtrl_ABCDE.scl` was edited from rev 2.1 (Phase D done-triggered) to rev 3.0 (V8 blending). Diffs in `500_AutoCtrl/FB_AutoCtrl_ABCDE.scl`:

### Interface (VAR + VAR_TEMP)

| Section | Added | Purpose |
|---|---|---|
| `VAR` | `statTotalDistance : LReal;` | Snapshot at step-change: total Euclidean distance from TCP to target |
| `VAR` | `statProgress : LReal;` | 0.0 (start of step) → 1.0 (arrived). Drives early advance at >0.5 |
| `VAR_TEMP` | `tempRemaining : LReal;` | This-scan Euclidean distance from TCP to target |

### Behavior changes

1. **`MC_MoveLinearAbsolute.BufferMode`**: `1` (BM_BUFFERED) → **`5` (BM_BLENDING_HIGH)** — queues next motion behind current
2. **Step-advance logic**: `.Done`-triggered → **progress > 0.5**-triggered:
   - Each scan: compute `tempRemaining` = `SQRT(SQR(target.x - Tcp.x) + SQR(target.y - Tcp.y) + SQR(target.z - Tcp.z))`
   - On step-change edge: snapshot `tempRemaining` into `statTotalDistance`
   - Each scan: `statProgress := 1.0 - tempRemaining / statTotalDistance` (guarded against divide-by-zero)
   - **When `statProgress > 0.5` AND step IN [10..50]**: advance step (with cycle wrap 50→10)

Result: by the time step advances, the SCARA is half-way through the current motion. The next `MC_MoveLinearAbsolute` (re-triggered by the step change) queues into the buffer **before the current motion completes**, so the kinematic group blends from one segment to the next without stopping at intermediate target.

---

## What you need to do in TIA Portal (4 manual steps)

### Step 1 — Stop the running cycle (so the download won't fight against motion)

In TIA Watch Table or via Online & Diagnostics, set:
- `GDB_MachineCmd.bo_Stop` = TRUE (briefly, ~1s)
- Wait for `i16_AutoStep` = 0
- Set `GDB_Control.enableAxes` = FALSE (optional, removes torque)

### Step 2 — Delete the old FB_AutoCtrl_ABCDE block

Project tree → `PLC_1` → `Program blocks` → `500_AutoCtrl` → right-click **FB_AutoCtrl_ABCDE [FB3]** → **Delete**. Confirm.

(The old iDB `instFB_AutoCtrl_ABCDE` in `instances/` will become invalid — leave it; we'll recreate after re-import.)

### Step 3 — Re-import via External Source

The edited SCL is on disk at:
```
E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\VCIExportedContents\PLC_1\Program blocks\500_AutoCtrl\FB_AutoCtrl_ABCDE.scl
```

In TIA Portal:
1. `PLC_1` → `External source files` → if `FB_AutoCtrl_ABCDE.scl` is already listed there, **delete it** (right-click → Delete) so TIA re-reads from disk
2. Right-click `External source files` → **Add new external file** → pick the SCL above
3. Right-click the file → **Generate blocks from source**
4. TIA creates a new `FB_AutoCtrl_ABCDE [FB3 or new number]` in `Program blocks`
5. Move it to `500_AutoCtrl/` group if it landed at root

If TIA complains the iDB `instFB_AutoCtrl_ABCDE` is invalid (it references the old interface), delete the iDB too. The Main.scl call will prompt to re-create on next compile.

### Step 4 — Recompile (use Rebuild All to avoid stale-symbol cache crash)

Right-click `PLC_1` → **Compile → Software (rebuild all)** (NOT "only changes" — Rebuild All forces a clean re-parse, avoids the SymbolHandlingException crash we hit before).

Expected: **0 errors, 0 warnings**.

If Main.scl warns about missing `instFB_AutoCtrl_ABCDE`, TIA prompts → click **Yes/Create** → accept default name `instFB_AutoCtrl_ABCDE`.

### Step 5 — Download to PLCSIM-Adv

Right-click `PLC_1` → **Download to device → Hardware and software (only changes)**. Confirm + wait for sim to re-enter RUN.

---

## Then run the V8 smoke test

Once download completes and PLCSIM-Adv is in RUN, tell me "ready" and I'll execute:

```powershell
& "E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\harness\SmokeTest_PhaseF_V8.ps1"
```

The script verifies 3 V8 gates:
- **V8.Blending**: <5% of velocity samples show standstill (motion stays continuous via BLENDING_HIGH)
- **V8.CycleCount**: ≥3 cycles in 45s (should be similar to or faster than Phase D's done-triggered baseline)
- **V8.ProgressAdvance**: avg `statProgress` at step-advance is 0.4-0.8 (proves progress-based trigger fires correctly, not .Done)

---

## Rollback if V8 doesn't work

If V8 fails (e.g., motion overshoots, joints fault, cycle stuck), revert FB_AutoCtrl_ABCDE.scl by:
1. Restore the rev 2.1 version from git: `git show 79cae9a:UserFiles/VCIExportedContents/PLC_1/Program\ blocks/500_AutoCtrl/FB_AutoCtrl_ABCDE.scl > ...`
2. Re-import + recompile + redownload
3. Phase D's done-triggered version is the safe baseline (V1-V7+V9+V-OB91 all confirmed pass)

V8 is **optional per source spec** — basic done-triggered cycle is the production-ready baseline.
