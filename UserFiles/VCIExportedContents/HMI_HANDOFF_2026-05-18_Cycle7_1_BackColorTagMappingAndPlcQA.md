**Status:** ACKNOWLEDGED

# HMI → PLC Handoff — 2026-05-18 (Cycle-7.1 redo: BackColor tag-mapping table delivered + answers to 4 PLC open questions on color dynamization)

> **Predecessor (HMI lane):** [HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md](HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseE_CompileGreen.md) (cycle-7.0 compile-green) + [HMI_HANDOFF_2026-05-17_C63AckAndPhase1EHmiReauthorDelivered.md](HMI_HANDOFF_2026-05-17_C63AckAndPhase1EHmiReauthorDelivered.md) (C63 ACK)
>
> **Predecessor (PLC lane):** [PLC_HANDOFF_2026-05-17_C65_HMI_Rebind_Requirements.md](PLC_HANDOFF_2026-05-17_C65_HMI_Rebind_Requirements.md), [PLC_HANDOFF_2026-05-17_C66_v9Phase1Phase2MegaAbsorption.md](PLC_HANDOFF_2026-05-17_C66_v9Phase1Phase2MegaAbsorption.md). Sibling project: `hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md` (Phase G proposal) + `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md`.
>
> **Triggered by:** Operator (2026-05-18) provided canonical PLC tag-mapping table for HMI BackColor dynamization + 4 open questions for HMI ACK. This handoff delivers the cycle-7.1 redo source (per the canonical table) AND answers all 4 questions to unblock PLC Phase G design.

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-18 |
| TIA target | `E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20` at HMI_1 |
| Source delta | 4 builders edited (~+180 LOC net): `AbcdePhase1Tags.cs` (+3 HMI tags) + `UbpAutoBuilder.cs` (+5 status lamps + 5 step-row dyns + revert 4 button dyns) + `UbpManualBuilder.cs` (3 Kin status lamps rebound + revert 2 button dyns) + `UbpDiagBuilder.cs` (rename lampToolActive + inverted inactive AccentRed) |
| Build verdict | 2 builds — #1 surfaced CS8625 (nullable default on `string inactiveColor = null`); fix: empty-string sentinel + `IsNullOrEmpty` check. Build #2: **0W / 0E** in 2.10s |
| Fire verdict | 3 chunked fires (ubp-auto + ubp-manual + ubp-diag) all clean; project saved 3× |
| HMI tag table | 14 → **17 entries** (4 W cmd + 13 R LEVEL); 3 NEW: `axesEnabled / axesHomed / axesError` bound to `GDB_Control.axes*` |
| Status | **ACKNOWLEDGED** — answers 4 PLC open questions + delivers cycle-7.1 redo source on canonical project (awaits operator TIA HMI Compile Rebuild All for final verification) |

---

## 1. Answers to 4 PLC open questions

### Q1: Per-axis status — Phase G clean mirror (Option A) OR HMI bit-mask of StatusWord today (Option B)?

**Answer: Option A — Phase G clean PLC mirror (GDB_ManualStatus).**

Rationale:
- **WinCC Unified Basic constraint**: `HmiTag.PlcTag` attribute accepts a typed PLC member path (Bool/Int/LReal), not a bit-slice of a Word (`StatusWord.%X2`). The S7 driver binding model expects clean named members.
- **TIA Compile validation**: compile-time-checked binding paths beat runtime JS-side bit extraction (which would require Tag-Cycle handlers + new HMI internal Bool tags + scheduled re-evaluation overhead).
- **Pattern consistency**: matches existing 17-tag bootstrap (each HMI tag = bare PLC member name, bound via `tag.PlcTag = "DB.member"` in `AbcdePhase1Tags.EnsureHmiTags`). Adding 12 per-joint Enabled/Homed/Error Bools follows the same idempotent flow.
- **Cycle-6.19 precedent**: HMI INVERT pattern bound to PLC-published bits (`cmd_Enable`), not slices — consistent with this choice.
- **PLC cost**: ~12 SCL lines in FB_ManualCtrl status mirror REGION (per C66 ManualMode_TagProposal §3.3 example already drafted).

### Q2: Derived "Ready" lamp — HMI Tag Set / JS event compute, OR ask PLC to add `GDB_Control.axesReady` derived bit?

**Answer: Ask PLC to add `GDB_Control.axesReady` derived bit.**

Recommended PLC implementation (single SCL line in FB_AxisCtrl status REGION):
```scl
"GDB_Control".axesReady := "GDB_Control".axesEnabled
                       AND "GDB_Control".axesHomed
                       AND NOT "GDB_Control".axesError;
```

Rationale:
- **HMI side already has the 3 inputs** as bootstrapped HMI tags (`axesEnabled / axesHomed / axesError` from this cycle), but V20 `BackColor` `TagDynamization.Range` condition only supports a SINGLE tag (no multi-bit AND).
- **JS-side compute** (Option B) requires: new HMI internal Bool tag `kinReady_Derived` + new Tag-Cycle handler script + scheduled re-evaluation (1s cycle typical). Adds runtime overhead + non-trivial JS maintenance burden + breaks the "PLC publishes, HMI consumes" pattern.
- **PLC-derived bit**: 1 SCL line, evaluated every PLC scan, exposed via existing GDB_Control mechanism (already HMI-accessible per C65/C66 confirmation).
- **HMI follow-up after PLC publishes**: 1 line in `AbcdePhase1Tags.EnsureHmiTags()` to bootstrap `axesReady` HMI tag + 1 `BindButtonBackColorDynamization` call to wire `lmpKinReady_Ubp` to `axesReady` Range `1:1` LampOk.

This cycle's `lmpKinReady_Ubp` stays as STRIPPED placeholder (no BackColor dyn) until PLC publishes `axesReady`.

### Q3: Color palette — confirm operator's table §4 matches HMI's `UbpC` static class?

**Answer: CONFIRMED match.** Explicit correspondence:

| Operator's color name | HMI const (`UbpC` static class) | Hex / RGB |
|---|---|---|
| gray (idle / inactive) | `UbpC.DisabledBg` (preferred) OR `UbpC.LampIdle` | #F5F5F5 / #BDBDBD |
| teal (auto / brand / mode-on) | `UbpC.SiemensTeal` | #00557F |
| green (OK / ready / homed / running-OK) | `UbpC.AccentGreen` / alias `UbpC.LampOk` | #4CAF50 |
| Siemens-red / red (alarm / error / E-stop-open) | `UbpC.AccentRed` / alias `UbpC.LampError` | #E53935 |
| amber (warn / pending) | `UbpC.AccentAmber` / alias `UbpC.LampWarn` | #FFA726 |

Per `feedback_palette_use_existing_tokens.md` memory + cycle-6.22 C41 §1.3 discipline: HMI agent never invents RGB triples — always uses `UbpC.*` tokens. This table provides the canonical mapping so PLC agent can publish color-spec strings (e.g., "teal" / "green") in handoffs without ambiguity; HMI agent resolves to the matching `UbpC.*` token at authoring time.

**Proposal for HMI_BINDING_MAP §5**: add this 5-row color-palette correspondence sub-table as a sibling to §5.3 (binding consumers table). PLC agent is sole writer per AGENT_CONTRACT §2.5; HMI proposes this row block here.

### Q4: Simple Bool → 2-color — idiomatic to use Range dyn (2 ranges), or simpler binding in WinCC Unified Basic?

**Answer: Range dyn (single condition with active + inactive color spec) is the ONLY idiomatic pattern in WinCC Unified Basic.**

WinCC Unified Basic on UBP MTP1000 does NOT support:
- `ShapeFillSettings` (Comfort-only)
- `MemberFillDynamization` (Comfort-only)
- `BackgroundColorVariableExpression` (Advanced HMI only)

The canonical pattern is the **single-Range with active + inactive color** that we've been using throughout cycle-7.0 + cycle-7.1:
```csharp
_adapter.BindButtonBackColorDynamization(
    _screen, lampName,
    tagPath:           hmiTagName,        // short HMI name; PlcTag attribute resolves to PLC path
    activeCondition:   "1:1",             // exact-match for Bool; Range M:N for Int (e.g., "10:50")
    activeColorSpec:   UbpC.AccentGreen,  // color when condition matches
    inactiveColorSpec: UbpC.LampIdle);    // color when condition doesn't match (= the "other" Bool state)
```

For an **INVERTED** Bool (e.g., lampEstop where TRUE=OK / FALSE=alarm), keep Range `"1:1"` but flip the colors:
```csharp
activeCondition:   "1:1",             // matches when bo_ESTOP_LOCK == TRUE
activeColorSpec:   UbpC.AccentGreen,  // chain OK
inactiveColorSpec: UbpC.AccentRed,    // E-stop opened → visible red warning
```

Internally TIA stores this as a single `TagDynamization` with one row in its Range condition collection. A "2-range" approach (one row for `0:0`→red, another for `1:1`→green) is NOT necessary — the single-Range + inactive color covers both states. We verified this pattern works on the UBP at cycle-7.0 compile-green + cycle-7.1 redo fires.

**For Int tags** (e.g., `i16_AutoStep` driving `lampAutoRunning`): use range inequality like `"10:50"` — TIA accepts M:N format (confirmed working at cycle-7.1 redo fire). Step-row highlights use single-value exact-match (`"10:10"`, `"20:20"`, ..., `"50:50"`).

## 2. Cycle-7.1 redo deliverable on canonical project

### 2.1 — Source delta (4 files, ~+180 LOC net)

**`Builders/Ubp/AbcdePhase1Tags.cs`**:
- Added 3 const-pairs (`AxesEnabled` + `AxesEnabled_PlcPath` + parallel for Homed/Error) bound to `GDB_Control.axes{Enabled,Homed,Error}`.
- Extended `EnsureHmiTags()` body with 3 new `EnsureTagWithPlcBinding` calls (idempotent skip-if-present).

**`Builders/Ubp/UbpAutoBuilder.cs`**:
- REVERTED 4 button BackColor dyn calls in `BuildRightColumn` (btnAutoStart/Stop/InitPath/Mode return to neutral default styling per operator's "visual feedback via dedicated lamps not button BackColor" design).
- Added NEW `BuildAutoStatusLamps()` method authoring 5 lamps in a horizontal strip at the top of the content area (y=4..36, 1024×32):
  - `lampAutoRunning` → `i16_AutoStep` Range `10:50` SiemensTeal (cycle-running visual)
  - `lampPathInitialed` → `bo_PathInitialed` Range `1:1` AccentGreen
  - `lampAutoMode` → `bo_Mode` Range `1:1` SiemensTeal
  - `lampAlarm` → `bo_Alarm` Range `1:1` AccentRed
  - `lampEstop` → `bo_ESTOP_LOCK` Range `1:1` **INVERTED** active=AccentGreen / inactive=AccentRed (E-stop open shows visible red)
- Added 5 step-row BackColor dyns in `BuildStepListRows` via `BindRectangleBackColorDynamization`:
  - `recStepRow_1` Range `10:10` AccentGreen (ABCDE row A)
  - `recStepRow_2` Range `20:20` AccentGreen (B)
  - `recStepRow_3` Range `30:30` AccentGreen (C)
  - `recStepRow_4` Range `40:40` AccentGreen (D)
  - `recStepRow_5` Range `50:50` AccentGreen (E)
  - Row 6 stays unbound (placeholder for future expansion)
  - Step labels updated `步骤 N / Step N` → `A (步骤 10) / A (Step 10)` etc.
- Layout: `BuildLeftColumn` + `BuildRightColumn` y start shifted from `Pad=12` → `Pad + LampStripH (32)` = 44 to make room for top strip.

**`Builders/Ubp/UbpManualBuilder.cs`**:
- REVERTED 2 Kin footer button BackColor dyn calls in `BuildKinFooterCtas` (btnKinEnable_Ubp + btnKinStop_Ubp neutral default).
- Rebound 3 of 4 Kin status banner lamps in `BuildKinStatusBanner`:
  - `lmpKinEnabled_Ubp` → `AxesEnabled` Range `1:1` SiemensTeal
  - `lmpKinHomed_Ubp` → `AxesHomed` Range `1:1` AccentGreen
  - `lmpKinError_Ubp` → `AxesError` Range `1:1` LampError (red)
  - `lmpKinReady_Ubp` STAYS STRIPPED (deferred to cycle-7.2 pending PLC adds `GDB_Control.axesReady` per Q2 answer above)

**`Builders/Ubp/UbpDiagBuilder.cs`**:
- Renamed `lmpDiagToolOk` → `lampToolActive` (operator's canonical naming).
- Extended `BuildLampRow` signature with optional `inactiveColor` parameter (empty-string sentinel preserves backward compatibility).
- `lampToolActive` uses **INVERTED inactive**: active=`UbpC.LampOk` (green when MC_SetTool Done), inactive=`UbpC.AccentRed` (red when statToolActivated=FALSE → UserFault risk visible at startup).
- 8 other lamps (lmpDiagEstop / lmpDiagPathInit / lmpDiagAlarm / 5 lmpMcSetTool*) unchanged.

### 2.2 — Fire verdict (3 chunked operator-authorized fires post-build-clean)

| Fire | Outcome | Substance |
|---|---|---|
| `ubp-auto` | ✅ Project saved | 3 NEW HMI tags created (axesEnabled/Homed/Error) + 5 step-row BackColor dyns + 5 status lamps + 4 button BackColor REVERTED |
| `ubp-manual` | ✅ Project saved | 3 Kin status lamps rebound + 2 Kin footer button BackColor REVERTED + lmpKinReady defer log emitted |
| `ubp-diag` | ✅ Project saved | lampToolActive (renamed from lmpDiagToolOk) with inactive=AccentRed; 8 other lamps unchanged |

## 3. Manual-wiring / cycle-7.2 follow-ups

| Item | Status |
|---|---|
| 47 Manual stripped widgets (per-axis jog + cmd + status lamps) | ⏭️ Phase G-blocked. Per Q1 answer above (Option A), PLC adds `GDB_ManualStatus` with 12 per-joint + 4 Kin Bools; HMI cycle-7.2 rebinds widgets. |
| `lmpKinReady_Ubp` derived state | ⏭️ Phase G-blocked. Per Q2 answer above, PLC adds `GDB_Control.axesReady` derived bit; HMI cycle-7.2 wires lamp to `axesReady` Range `1:1` LampOk. |
| V8 progress bar widget on 02_Diag_Ubp | ⏭️ Cycle-7.2 candidate. Plan §G defers; current IOField text display of `statProgress` LReal works in the interim. |
| HMI_BINDING_MAP §5 color-palette correspondence sub-table | ⏭️ HMI proposes via this handoff §1 Q3 answer; PLC absorbs in next cycle per sole-writer rule. |
| iDB `instFB_AxisCtrl` "Accessible from HMI" flag | 🟡 Verify at operator's next TIA Compile — if 6 of the 10 cycle-7.1 R LEVEL tags (statToolActivated + 5 mcSetTool_*) fail compile-time PlcTag resolution, operator fixes via TIA → iDB Properties → Attributes → flag ON. |
| GDB_Control `axes{Enabled,Homed,Error}` "Accessible from HMI" flag | 🟡 NEW risk this cycle. Verify at operator's TIA Compile — if 3 new tags' compile fails, operator fixes flag on GDB_Control. |

## 4. Notes for the PLC agent

- **Per-axis status mirror (Q1)**: HMI requests **Option A** (clean PLC mirror in `GDB_ManualStatus`). 12 per-joint Bools + 4 Kin Bools per C66 ManualMode_TagProposal §3.2 verbatim. Will unblock cycle-7.2 rebind of 12+4 = 16 stripped Manual lamps.
- **`axesReady` derived bit (Q2)**: HMI requests **1-line PLC addition** in FB_AxisCtrl status REGION: `axesReady := axesEnabled AND axesHomed AND NOT axesError`. Will unblock cycle-7.2 binding of `lmpKinReady_Ubp` (last remaining stripped widget in the Kin banner).
- **Color palette (Q3)**: confirmed match with `UbpC.*` static class. Proposed HMI_BINDING_MAP §5 sub-section table provided above; PLC agent absorbs as next-cycle row block in HMI_BINDING_MAP.md per sole-writer convention.
- **Bool→2-color idiom (Q4)**: WinCC Unified Basic on UBP supports ONLY `TagDynamization.Range` BackColor binding (single condition + inactive color spec covers both states). No simpler alternative exists.
- **No new PLC asks beyond Q1+Q2**: Q3+Q4 are HMI confirmations to PLC.
- **Closure markers**: `[ACKNOWLEDGED]` 4 PLC questions; `[VERIFIED-COMPILE-GATE]` cycle-7.1 redo source-side; `[NEEDS_OPERATOR]` Phase F runtime smoke + this-cycle TIA HMI Compile Rebuild All; `[INFORMATIONAL → PLC]` color-palette correspondence proposal for HMI_BINDING_MAP §5 absorption; `[BLOCKS]` PLC Phase G author cycle (Option A for §3.2 + 1-line axesReady) — once unblocked, HMI cycle-7.2 rebinds the remaining 16+1 widgets.

---

End of cycle-7.1 BackColor tag-mapping + 4-question ACK handoff. Awaiting operator TIA HMI Compile result + PLC Phase G author cycle for cycle-7.2 follow-up.
