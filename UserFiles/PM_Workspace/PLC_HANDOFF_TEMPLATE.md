# PLC Handoff to HMI Agent — _YYYY-MM-DD_

> **Template.** Copy this file to `PLC_HANDOFF_<date>.md` (e.g.
> `PLC_HANDOFF_2026-05-04.md`) at the start of each promotion cycle.
> Fill every section. Delete unused subsections — but do not delete the
> top-level headings; an empty section is information ("nothing changed
> in this domain") and the HMI agent's audit script keys off it.

---

## Header — promotion metadata

| Field | Value |
|---|---|
| Cycle date | _YYYY-MM-DD_ |
| v9 commit SHA at promotion | _git rev-parse HEAD on v9 VCI repo_ |
| `HMI_BINDING_MAP.md` rows touched | _N added / N deprecated / N removed_ |
| Schema version of `HMI_BINDING_MAP.md` | _1 (or higher if schema changed)_ |
| Promotion status | **READY** / **BLOCKED-ON-HMI** / **DRY-RUN-ONLY** |
| Verification artifact | _e.g. `pytest 38 passed`, `probe_per_axis [PASS]`_ |

---

## 1. Bindings added — Section 1 deltas

New rows added to `HMI_BINDING_MAP.md` Section 1 this cycle. Mirrors the
exact rows the PLC agent committed. HMI agent uses this as the
authoritative add-list for `Ensure*Tag(...)` calls.

| hmi_tag_name | plc_path | data_type | direction | trigger | domain | reason for addition |
|---|---|---|---|---|---|---|
| _e.g. mc_kin_statusHomed_ | _e.g. "GDB_HMI_Motion".ManualControl.statusHomed_ | Bool | R | LEVEL | motion | _UDT status mirror — closes instFB_ModeManager binding exception_ |

If no additions: write `_(none)_` in the row.

---

## 2. Bindings deprecated — Section 3 entries

Rows moved to Section 3 this cycle. HMI agent has **one cycle** to
migrate off these before they're removed. List the exact migration path.

| hmi_tag_name | replacement | migration steps for HMI agent |
|---|---|---|
| _e.g. mc_kin_statusEnabled_ | _mc_kin_statusEnabledMirror_ | _swap binding in `MotionControlBuilder.BuildKinManualScreen` lamp `lmpKinEnabled`; rerun `--only=motion-control`_ |

If no deprecations: write `_(none)_`.

---

## 3. Bindings removed — Section 1 rows deleted

Rows that completed their deprecation cycle and were removed from
Section 1 (they appeared in Section 3 of a previous handoff note).
HMI agent verifies these no longer appear in any `AllTags()` enumerator
or any builder's `Ensure*Tag(...)` call.

| hmi_tag_name | deprecated_since | removed_this_cycle | last_handoff_referencing_it |
|---|---|---|---|
| _e.g. mc_allowRobotManual_ | 2026-04-20 | 2026-05-04 | PLC_HANDOFF_2026-04-20.md |

If no removals: write `_(none)_`.

---

## 4. UDT shapes touched — Section 2 deltas

New UDTs added to Section 2, OR existing UDTs whose field set changed.
For changed UDTs, list the field-level diff (added / removed / type-
changed) so the HMI agent's auditor knows what to recheck.

### New UDTs

```
UDT_NAME:
  .field_path : data_type    [comment]
  ...
```

### Changed UDTs

```
UDT_NAME (changed):
  + .new_field        : Bool          [added this cycle]
  - .old_field                        [removed; was Int]
  ~ .field_changed    : DInt → LReal  [type changed]
```

If no UDT changes: write `_(none)_`.

---

## 5. Pre-promotion checklist outcomes

PLC agent ran the checklist before publishing this handoff. Record
results so HMI agent can trust the contract.

- [ ] Every Section 1 `plc_path` resolves in v9 PLC export — _verdict + count_
- [ ] No `plc_path` matches `UNSUPPORTED_PLC_DENYLIST.md` — _verdict_
- [ ] `data_type` matches PLC export's declared type for every row — _verdict_
- [ ] Section 2 consistent with Section 1's UDT references — _verdict_
- [ ] Deprecation cycles honored (no Section 1 removal without prior Section 3 entry) — _verdict_
- [ ] PLC pytest harness: _e.g. 38 passed in 2.4s_
- [ ] Probe scripts: _e.g. probe_per_axis [PASS]_

If any check failed, set Promotion Status to **BLOCKED-ON-HMI** in the
header and document the blocker below in section 6.

---

## 6. Notes for HMI agent

Free-form section for cross-cutting concerns, [MANUAL-WIRING]
expectations, or warnings the HMI agent should know.

Examples:
- _"Per-axis deadman gate now active — HMI must add the deadman widget per Action B1 in this handoff."_
- _"The new `mc_kin_statusHomed` binding makes the existing `instFB_ModeManager.statusEnabled` binding redundant; consider migrating in a follow-up cycle."_
- _"Orphan FB_CallAxes block remains in v9; harmless but cluttering — cleanup deferred."_

If no notes: write `_(none)_`.

---

## 7. Verification commands (HMI agent runs after VCI import)

The HMI agent runs these against v10 after importing this v9 promotion:

```cmd
:: 1. Audit binding map vs project state
cd /d E:\VS_Code_Proj\TiaUnifiedAuto
dotnet run -- --only=audit-tags

:: 2. (Optional) Dry-run prune to see drift before authoring
dotnet run -- --only=prune-orphans-dry

:: 3. Author HMI tags + screens for the new bindings
dotnet run -- --only=motion-control       :: or --only=all if cross-domain

:: 4. Confirm the PLC pytest harness still green (v9 sim if up)
cd /d E:\Claude\plcsim_harness_hmiDemoMomoryCapacity_v9
python tools\probe_per_axis.py
python -m pytest tests\ -v
```

Expected outcomes documented in `HMI_HANDOFF_<date>.md` reply.

---

_End of PLC_HANDOFF_<date>.md_
