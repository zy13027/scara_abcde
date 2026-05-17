# HMI Handoff to PLC Agent — _YYYY-MM-DD_

> **Template.** Copy this file to `HMI_HANDOFF_<date>.md` (e.g.
> `HMI_HANDOFF_2026-05-04.md`) at the end of each HMI rebuild cycle.
> Fill every section. Empty sections are information ("nothing to
> report from HMI side this cycle"); do not delete the headings.

---

## Header — rebuild metadata

| Field | Value |
|---|---|
| Cycle date | _YYYY-MM-DD_ |
| Triggered by | _PLC_HANDOFF_<date>.md_ (or "self-initiated maintenance") |
| HMI codebase commit SHA | _git rev-parse HEAD on TiaUnifiedAuto repo_ |
| v10 project state at rebuild | _path + last-modified timestamp_ |
| Build verdict | **CLEAN (0 warnings, 0 errors)** / **WARNINGS: N** / **FAILED** |
| TIA HMI compile verdict | **CLEAN** / **N errors (attributed below)** / **NOT YET RUN** |
| Rebuild status | **READY** / **BLOCKED-ON-PLC** / **PARTIAL** |

---

## 1. Audit results — `--only=audit-tags`

The HMI agent runs `dotnet run -- --only=audit-tags` against v10 before
authoring. Report all four buckets verbatim from the auditor's output.

| Bucket | Count | Notes |
|---|---|---|
| Healthy (declared ∩ referenced) | _N_ | |
| Cosmetic orphans (declared - referenced) | _N_ | _candidates for `--only=prune-orphans`_ |
| **Runtime errors (referenced - declared)** | _N_ | **must be 0 before authoring** |
| Broken imports (matches `UnsupportedPlcDenylist`) | _N_ | _list paths if > 0_ |

If runtime errors > 0: set Rebuild Status to **BLOCKED-ON-PLC** and list
the unresolved paths in section 6 ("Issues escalated to PLC agent").

---

## 2. Tags authored this cycle

Cross-reference against `PLC_HANDOFF_<date>.md` Section 1 (added
bindings). Every added binding from PLC's handoff should appear here as
authored, OR be flagged in section 6 with a reason.

| hmi_tag_name | source_handoff | builder_method | status |
|---|---|---|---|
| _e.g. mc_kin_statusHomed_ | _PLC_HANDOFF_2026-05-04.md_ | _MotionControlBuilder.EnsureAllKinManualTags_ | **AUTHORED** / **DEFERRED** / **MANUAL-WIRING** |

Aggregate counts:
- New tags authored: _N_
- Tags deprecated (migrated off): _N_
- Tags pruned (Section 3 removals confirmed): _N_

If no tags this cycle: write `_(none — read-only audit pass)_`.

---

## 3. `[MANUAL-WIRING]` checklist for TIA Portal

Items the C# builder cannot author through Openness V20 and that require
one-pass touch by the user in TIA Portal. Each item has a precise
location + action.

| # | Screen / item | Property | Action in TIA Portal |
|---|---|---|---|
| 1 | _e.g. LMotionCtrl_Layout / lmpSvcLim_ | _BackColor dynamization_ | _Add Tag dynamization on `mc_requireServiceLimits`: 0 → grey, 1 → amber_ |
| 2 | _LMotionCtrl_AxisManual_J1 / screen-level "Cleared" event_ | _Event script_ | _Paste JS: `HMIRuntime.Tags("mc_kin_cmdDeadman").Write(false)`_ |

Aggregate: _N items pending manual touch._

If no manual wiring needed: write `_(none — fully automated this cycle)_`.

---

## 4. Screen authoring summary

Domains touched and counts.

| Domain | Screens authored | Screens modified | Component-screens | Notes |
|---|---|---|---|---|
| motion | _N_ | _N_ | _N_ | |
| recipe | _N_ | _N_ | _N_ | |
| stack | _N_ | _N_ | _N_ | |
| robot | _N_ | _N_ | _N_ | |
| pallpatt | _N_ | _N_ | _N_ | |
| template | _N_ | _N_ | _N_ | |

If running `--only=audit-tags` only (no authoring): write `_(audit-only cycle, no screen edits)_`.

---

## 5. TIA HMI compile results

After importing the rebuild back into TIA Portal and running HMI
compile, report the error count by family.

| Error family | Count | Owner | Action |
|---|---|---|---|
| `Tag <name> for dynamization not exist` | _N_ | _HMI / PLC_ | _e.g. user must run `--only=templates` first_ |
| `HMITag with name <X> not found in JS` | _N_ | _HMI_ | _audit-tags drift; rerun_ |
| `Data type not supported by communication driver` | _N_ | _PLC_ | _add to `UnsupportedPlcDenylist.cs`; PLC agent re-publishes Section 1 with leaf-only path_ |
| `Current value 'Array' of property 'Data type' is invalid` | _N_ | _PLC_ | _same — flat array UDT; needs leaf binding_ |
| Other | _N_ | _-_ | _describe_ |

If compile not yet run: write `_(not yet run — pending TIA Portal cycle)_`.

---

## 6. Issues escalated to PLC agent

Any audit-blocking issues, unresolved paths, or proposed new bindings
the HMI agent needs from PLC side.

### Unresolved `plc_path` references (audit-blocking)

| hmi_tag_name | declared_plc_path | error |
|---|---|---|
| _e.g. mc_axis_J1_cfg_unknownField_ | _"GDB_HMI_Motion".axis[1].cfg.unknownField_ | _PLC field doesn't exist in v10 export — was it renamed in v9?_ |

### Proposed new bindings (HMI agent requesting PLC agent to add to Section 1)

| proposed_hmi_tag_name | proposed_plc_path | use case |
|---|---|---|
| _e.g. mc_axis_J1_actualTorque_ | _"GDB_HMI_Motion".axis[1].status.actualTorque_ | _add torque IO field to commissioning screen for J1_ |

### Bindings flagged for deprecation (HMI agent suggests PLC agent move to Section 3)

| hmi_tag_name | reason |
|---|---|
| _e.g. mc_legacyDebugFlag_ | _no screen references it; appears unused in HMI codebase_ |

If no escalations: write `_(none)_`.

---

## 7. Verification commands run

Document what was actually run this cycle so PLC agent can reproduce.

```cmd
:: HMI build
cd /d E:\VS_Code_Proj\TiaUnifiedAuto
dotnet build -c Release          :: result: 0 warnings 0 errors

:: Audit
dotnet run -- --only=audit-tags
:: result: see Section 1 above

:: Authoring (if any)
dotnet run -- --only=<phase>
:: result: tag count delta + [MANUAL-WIRING] count

:: Re-export for readback (optional)
dotnet run -- --export=hmi_export_<date>
```

If a different sequence was run, document verbatim.

---

## 8. Notes for PLC agent

Free-form. Anything the PLC agent should know going into the next
cycle.

Examples:
- _"Cycle landed clean. Next PLC commit can proceed."_
- _"User has a v11 manual-correction copy where they tested cfgService gating; the gating logic is now landed in C# and authors into v10 — feel free to discard v11."_
- _"Found one row in Section 1 (`mc_axis_J3_cfg_obscureField`) with no HMI screen reference; flagged in section 6 for deprecation."_

If no notes: write `_(none)_`.

---

_End of HMI_HANDOFF_<date>.md_
