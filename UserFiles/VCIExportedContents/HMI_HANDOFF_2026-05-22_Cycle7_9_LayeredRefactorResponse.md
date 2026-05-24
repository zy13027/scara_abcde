# HMI Handoff to PLC Agent — 2026-05-22 — Cycle-7.9 Layered Refactor Response

**Status:** PENDING_VERIFICATION — all C# edits compile clean (0W/0E); TIA fire + HMI Compile not yet run.

---

## Header — rebuild metadata

| Field | Value |
|---|---|
| Cycle date | 2026-05-22 |
| Triggered by | `PLC_HANDOFF_2026-05-21_LayeredRefactor_HmiBindingDeltas.md` |
| HMI codebase commit SHA | `71a6f13` (worktree: `keen-lederberg-6dd958`, uncommitted edits) |
| v10 project state at rebuild | `E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20` |
| Build verdict | **CLEAN (0 warnings, 0 errors)** |
| TIA HMI compile verdict | **NOT YET RUN** |
| Rebuild status | **PARTIAL** — Pause button `[BLOCKED-ON-PLC]`; `GDB_Control` ambiguity unresolved |

---

## 1. Audit results — `--only=audit-tags`

_(audit not run this cycle — binding-delta response cycle, not full audit)_

---

## 2. Tags authored this cycle

| hmi_tag_name | source_handoff | builder_method | status |
|---|---|---|---|
| `bo_Pause` | proposed (cycle-7.9) | `AbcdePhase1Tags` const only | **[BLOCKED-ON-PLC]** — EnsureHmiTags bootstrap commented out |
| `bo_Paused` | proposed (cycle-7.9) | `AbcdePhase1Tags` const only | **[BLOCKED-ON-PLC]** — EnsureHmiTags bootstrap commented out |

Aggregate counts:
- New tags authored: 0 (2 proposed constants defined, not yet bootstrapped)
- Tags deprecated (migrated off): 0
- Tags pruned: 0

---

## 3. `[MANUAL-WIRING]` checklist for TIA Portal

| # | Screen / item | Property | Action in TIA Portal |
|---|---|---|---|
| 1 | `04_Diag_Ubp / ioDiagBlendProgress` | ProcessValue TagDynamization | `[MANUAL-WIRING]` — `instFB_AutoCtrl_ABCDE.statProgress` iDB is retired. IOField shows stale/zero until PLC adds `blendProgress` to `GDB_HMI_Status` facade. |

Aggregate: 1 item pending (PLC-side facade expansion needed first).

---

## 4. Screen authoring summary

| Domain | Screens authored | Screens modified | Component-screens | Notes |
|---|---|---|---|---|
| ubp-layout | 0 | 1 | 0 | TCP position strip added to `01_Layout_Ubp` |
| ubp-home | 0 | 1 | 0 | Dynamic reflow for ContentH 640→592 |
| ubp-auto | 0 | 1 | 0 | N/M progress display + Pause placeholder |
| ubp-pallet | 0 | 1 | 0 | Label parity (totalSteps now dynamic, not "48") |
| ubp-manual | 0 | 5 | 0 | Per-axis dynamic layout + Cartesian jog relabels (4 per-axis + shared constants) |
| ubp-diag | 0 | 1 | 0 | Dynamic safety card row height |

8 C# source files changed. 6 UBP screen builders affected.

---

## 5. TIA HMI compile results

_(not yet run — pending TIA Portal fire cycle)_

---

## 6. Issues escalated to PLC agent

### 6.1 — `GDB_Control` (DB#3) retirement ambiguity `[NEEDS_CLARIFICATION]`

PLC handoff §1 P2 declares `GDB_Control` (DB#3) "retired," but §3 (HMI action list) does **NOT** ask HMI to repoint the following 7 bindings used by the TopBar header strip + Kin status banner:

| HMI tag | PlcTag path | Widget(s) |
|---|---|---|
| `enableAxes` | `GDB_Control.enableAxes` | `btnAxesEnable` (TopBar) |
| `homeAxes` | `GDB_Control.homeAxes` | `btnAxesHome` (TopBar) |
| `resetAxes` | `GDB_Control.resetAxes` | `btnAxesReset` (TopBar) |
| `axesEnabled` | `GDB_Control.axesEnabled` | `lampAxesEnabled` (TopBar) |
| `axesHomed` | `GDB_Control.axesHomed` | `lampAxesHomed` (TopBar) |
| `axesError` | `GDB_Control.axesError` | `lampAxesError` (TopBar) |
| `axesReady` | `GDB_Control.axesReady` | `lampAxesReady` (Kin banner) |

**HMI action taken:** Retained all 7 bindings as-is. These are the operator's safety/recovery surface (Enable/Home/Reset axes + status feedback). Removing them without confirmed replacements would break the operator's commissioning workflow.

**Request:** Please clarify:
1. Is `GDB_Control` actually removed from the PLC project, or is it retained with the same interface?
2. If removed: what are the replacement paths for these 7 tags?
3. If retained: acknowledge so HMI can close this item.

### 6.2 — `StatProgress` (blendProgress) facade gap `[BLOCKED-ON-PLC]`

`instFB_AutoCtrl_ABCDE.statProgress` (LReal 0..1, V8 blending diagnostic) is bound to `ioDiagBlendProgress` on `04_Diag_Ubp`. The iDB is retired (FB replaced by `FB_AutoCtrl_5Pts`). The `GDB_HMI_Status` facade does NOT currently have a `blendProgress` member.

**Request:** Either:
- Add `GDB_HMI_Status.blendProgress` (LReal) to `FB_HMIStatusMirror` V0.3, OR
- Confirm this diagnostic field is no longer relevant (HMI will strip the IOField)

### 6.3 — Proposed `bo_Pause` / `bo_Paused` in `GDB_MachineCmd` `[NEEDS_PLC]`

Operator requests an Auto-mode **Pause** button on `02_Auto_Ubp`. Semantically distinct from Stop: freezes the CASE state machine mid-sequence (axes hold position, `currentStep` freezes) rather than aborting and resetting to step 0.

**HMI side authored:**
- `btnAutoPause` visual placeholder in 3×2 control grid (alongside Start/Stop/InitPath/Mode)
- Constants defined: `Bo_Pause = "bo_Pause"`, `Bo_Paused = "bo_Paused"`
- Click binding + BackColor dyn commented out `[BLOCKED-ON-PLC]`

**PLC side requested:**
- `GDB_MachineCmd.bo_Pause` (Bool W, PULSE 250ms) — pause command
- `GDB_MachineCmd.bo_Paused` (Bool R, LEVEL) — paused-state status feedback
- Implement pause/resume logic in `FB_AutoCtrl_5Pts` CASE machine
- On `bo_Pause` rising edge: freeze CASE state, hold axes
- On `bo_Start` rising edge while paused: resume from frozen state

Once PLC confirms, HMI will uncomment `EnsureHmiTags` bootstrap + button binding.

### 6.4 — Acknowledged items (no action needed from PLC)

| PLC handoff item | HMI action | Status |
|---|---|---|
| §2.1 — 4 target IOField repoints | Already done in cycle-7.6 (facade retrofit) | ✅ Closed |
| §2.2 — N/M progress display | `ioCurrentStep` / `ioTotalSteps` paired display on Auto screen; Pallet labels updated | ✅ Done |
| §2.3 — Cartesian jog relabeling | Per-axis headers show "J{n} → {X/Y/Z/A}"; jog button labels include axis letter; hint footer updated | ✅ Done |
| §2.4 — Unchanged paths confirmed | GDB_MachineCmd cmd tags, TO tags — no HMI change needed | ✅ Acknowledged |
| §3.3 — Future manual jog labels | Deferred jog widgets (§5.6 in binding map) not yet wired; when wired, will use X/Y/Z/A labels | Deferred |

---

## 7. Verification commands run

```cmd
:: HMI build (worktree keen-lederberg-6dd958)
cd /d E:\VS_Code_Proj\TiaUnifiedAuto
dotnet build --no-restore
:: result: 0 warnings, 0 errors

:: TIA fire (NOT YET RUN — pending operator authorization)
:: Fire order:
::   dotnet run -- --only=ubp-layout
::   dotnet run -- --only=ubp-home
::   dotnet run -- --only=ubp-auto
::   dotnet run -- --only=ubp-pallet
::   dotnet run -- --only=ubp-manual
::   dotnet run -- --only=ubp-diag
```

---

## 8. Notes for PLC agent

1. **TCP position now always-visible.** A 48px persistent strip below the TopBar shows live `ScaraArm3D.Tcp.{x,y,z,a}` IOFields across all 6 content screens. Operator directive: "TCP position visible whichever screen user switches to."

2. **ContentH shrunk 640→592.** All 6 content screen builders now compute bottom edges dynamically from `Mtp1000.ContentH`. No visual overflow expected but TIA fire + visual gate needed.

3. **`StatTargetX/Y/Z/A` marked `[OBSOLETE]`.** Constants retained in `AbcdePhase1Tags.cs` for reference but no builder references them (cycle-7.6 migrated to facade).

4. **`i16_AutoStep` value-semantics change acknowledged.** The ABCDE step-list row BackColor binding (`Range 10:50`) still works for the 5-point sequence highlight, but note the CASE states are now 0/10/20/30/50/100/110/200/230/800/900 per §2.2. The step-list visual is a subset indicator (rows A-E light when their step is active) and remains functionally correct — states > 50 don't highlight any row, which is the correct behavior for init/error/done states.

5. **Pallet `totalSteps` label corrected.** Was hardcoded "(48)" — now dynamic via `hmiTotalSteps` facade. Matches the new 16-box layout (was 48-step CASE states pre-refactor).

6. **Priority order for PLC response:** (a) `GDB_Control` clarification §6.1, (b) `bo_Pause` implementation §6.3, (c) `blendProgress` facade §6.2.

---

_End of HMI_HANDOFF_2026-05-22_Cycle7_9_LayeredRefactorResponse.md_
