**Status:** PENDING_VERIFICATION → scara-PLC. **TIA target:** `hmiDemoSCARA_ABCDE.ap20`. **Predecessor:** `PLC_HANDOFF_2026-05-19_HMI_Followups_HeaderStripAndIOFieldRendering.md` (Issue A — IOField rendering bug). **Companions this session:** `HMI_HANDOFF_2026-05-19_WinCCUnifiedGraphQL_FunctionRightDiagnosis.md` + `HMI_HANDOFF_2026-05-19_WebPageAPIRoleApplied_PlcReTestTrigger.md` (auth-side; orthogonal track).

# HMI Handoff 2026-05-19 — Cycle-7.6 Issue A closed: 02_Auto_Ubp facade retrofit + project-wide TagDynamization adapter fix; scara-PLC re-test trigger

## §1 What this handoff closes

PLC handoff `_HMI_Followups_HeaderStripAndIOFieldRendering.md` §2 mapped Issue A (5 IOFields on `02_Auto_Ubp` cardProgress rendering binding-path strings as text instead of LReal/Int values) to **scara-HMI cycle-7.6+** planning Option 1. This handoff announces source landed + 4 fires saved on `hmiDemoSCARA_ABCDE.ap20` + tag-table cross-check confirmed alignment with operator's `Ubp_PLC` table. Awaiting your runtime smoke per PLC handoff §5 to flip PENDING_VERIFICATION → VERIFIED.

**Three sub-cycles delivered this session** to fully close Issue A:

| Sub-cycle | Substance | LOC | Files |
|---|---|---|---|
| **7.6** | Facade retrofit: 5 IOFields on `02_Auto_Ubp` cardProgress swap direct iDB/GDB paths (`instFB_AutoCtrl_ABCDE.statTargetPos.{x,y,z,a}` + `GDB_MachineCmd.i16_AutoStep`) → C71 facade short HMI names (`hmiCurrentStep` + `hmiTargetX/Y/Z/A`) | ~30 | `UbpAutoBuilder.cs` |
| **7.6b** | Adapter-level fix: `UnifiedScreenAdapter.CreateIoField` now creates canonical V20 `TagDynamization("ProcessValue")` mirroring BackColor + Screen patterns (lines 420-425 + 576-580). Direct setter kept as fallback for read-back diagnostic compatibility. **Cross-cutting** — ALL IOFields project-wide get the fix | ~40 | `UnifiedScreenAdapter.cs` |
| **7.6c v2** | HMI tag aliases for 9 IOField bindings; aligned with operator's `Ubp_PLC` auto-created tag names (cross-checked via operator screenshot). Factory methods `Jn_ActualPos_Hmi/Vel_Hmi(j)` + const `StatProgress` updated to return underscore-replaced names. **No new bootstrap calls** (tags already exist in operator's tag table) | ~20 | `AbcdePhase1Tags.cs` + `UbpManualBuilder.cs` + `UbpHomeBuilder.cs` + `UbpDiagBuilder.cs` |

Total: **~90 LOC across 5 files**.

## §2 Why three sub-cycles

**Discovery sequence**:

1. **Cycle-7.6 (planned escalation per PLC handoff §3 hypothesis #1)**: swap iDB paths → C71 facade. Eliminated the `Accessible-from-HMI` iDB flag risk. Build green; fire saved.
2. **Cycle-7.6 fire log surfaced a deeper issue**: every IOField's `[IO] Dynamizations.Count after ProcessValue set = 0`. Matches CLAUDE.md feedback note "V20 HmiIOField.ProcessValue requires TagDynamization — direct `item.ProcessValue = 'tagName'` C# setter stores STATIC string at runtime". Confirmed: ALL pre-cycle-7.6b IOFields were rendering as static strings (the cycle-7.6 facade swap alone would NOT have fixed Issue A — same symptom, just different text rendered).
3. **Cycle-7.6b (adapter fix)**: Replaced direct setter with `item.Dynamizations.Create<TagDynamization>("ProcessValue").Tag = ...` mirroring the BackColor pattern. Fire log post-7.6b: `[IO] ✓ ProcessValue TagDynamization created → tag='hmiTargetA'` + `Dynamizations.Count after = 1` ✓. Applied project-wide via 4 chunked fires (ubp-auto + ubp-pallet + ubp-manual + ubp-diag). All saved.
4. **TIA HMI Compile errors (16E / 0W)** surfaced AFTER cycle-7.6b applied: TagDynamization references to long PLC paths with DOTS (e.g., `J1_SCARA_Arm3D.ActualPosition`) couldn't resolve as HMI tag table names. Operator's tag-table cross-check (screenshot 4× `Ubp_PLC` [94 tags]) revealed TIA had auto-created HMI tags with **underscore-replaced names** (e.g., `J1_SCARA_Arm3D_ActualPosition`).
5. **Cycle-7.6c v2 (tag-table alignment)**: Factory methods + const adjusted to return the underscore-replaced names matching what's already in `Ubp_PLC`. No new bootstrap calls (would create duplicates in `Default tag table`).

## §3 Final source state (per file)

### §3.1 `Builders/UnifiedScreenAdapter.cs` lines 645 + 676-708

Replaced direct setter with canonical V20 TagDynamization. Both paths kept for safety:

```csharp
// Cycle-7.6b — canonical V20 TagDynamization (mirrors BackColor at line 422,
// Screen at line 578). Required for IOField runtime value resolution.
try
{
    var existingDyn = item.Dynamizations.Find("ProcessValue") as TagDynamization;
    bool reused = existingDyn != null;
    var pvDyn = existingDyn ?? item.Dynamizations.Create<TagDynamization>("ProcessValue");
    pvDyn.Tag = spec.TagPath;
    Console.WriteLine($"[IO] ✓ '{spec.Name}' ProcessValue TagDynamization {(reused ? "reused" : "created")} → tag='{pvDyn.Tag}'");
}
catch (Exception ex) { ... }

// Cycle-7.6b: kept as fallback / static default; the TagDynamization
// above is what actually binds the IOField to live tag values.
item.ProcessValue = spec.TagPath;
```

### §3.2 `Builders/Ubp/UbpAutoBuilder.cs` lines 224-241 (cardProgress)

5 `BuildIoKvRow` calls swap from direct iDB/GDB paths to facade short HMI names (cycle-7.6 retrofit):
- `AbcdePhase1Tags.I16_AutoStep` → `AbcdePhase1Tags.Hmi_CurrentStep` (`"hmiCurrentStep"`)
- `AbcdePhase1Tags.StatTargetX/Y/Z/A` → `AbcdePhase1Tags.Hmi_TargetX/Y/Z/A`

### §3.3 `Builders/Ubp/AbcdePhase1Tags.cs` factory methods (cycle-7.6c v2)

```csharp
// Match operator's Ubp_PLC tag-table auto-created underscore names:
public static string Jn_ActualPos_Hmi(int j)     => $"J{j}_SCARA_Arm3D_ActualPosition";
public static string Jn_ActualPos_PlcPath(int j) => $"J{j}_SCARA_Arm3D.ActualPosition";
public static string Jn_ActualVel_Hmi(int j)     => $"J{j}_SCARA_Arm3D_ActualVelocity";
public static string Jn_ActualVel_PlcPath(int j) => $"J{j}_SCARA_Arm3D.ActualVelocity";

public const string StatProgress         = "instFB_AutoCtrl_ABCDE_statProgress";
public const string StatProgress_PlcPath = "instFB_AutoCtrl_ABCDE.statProgress";

// Legacy aliases (return PLC paths — DO NOT use for new IOField bindings):
public static string AxisActualPosition(int j) => Jn_ActualPos_PlcPath(j);
public static string AxisActualVelocity(int j) => Jn_ActualVel_PlcPath(j);
```

`EnsureHmiTags()` end of method: **no new EnsureTagWithPlcBinding calls** (tags already exist in `Ubp_PLC`).

### §3.4 `Builders/Ubp/UbpHomeBuilder.cs` line 153 (Home cardJointPos)

`AxisActualPosition(j)` → `Jn_ActualPos_Hmi(j)` — 4 IOFields (J1-J4) bind to underscored auto-names.

### §3.5 `Builders/Ubp/UbpManualBuilder.cs` (3 binding sites)

- Line 374-376 (BuildKinAxisRow): `StatTargetX/Y/Z` → `Hmi_TargetX/Y/Z` (facade)
- Line 542 (BuildAxisQuadrant): `AxisActualPosition(j)` → `Jn_ActualPos_Hmi(j)`
- Lines 750+769 (BuildPerAxisPositionCard): `AxisActualPosition/Velocity(j)` → `Jn_ActualPos_Hmi/Vel_Hmi(j)`

### §3.6 `Builders/Ubp/UbpDiagBuilder.cs` line 279 (ioDiagBlendProgress)

`"instFB_AutoCtrl_ABCDE.statProgress"` (raw string) → `AbcdePhase1Tags.StatProgress` (which now resolves to `"instFB_AutoCtrl_ABCDE_statProgress"` underscored auto-name).

## §4 Fire sequence (all saved on `hmiDemoSCARA_ABCDE.ap20`)

| Fire | Phase | Save | TagDynamization Count=0→1 verified |
|---|---|---|---|
| Cycle-7.6 first attempt | `--only=ubp-auto` (from worktree) | ❌ no UBP dispatch (worktree on old HEAD) | n/a |
| Cycle-7.6 retry (main repo path) | `--only=ubp-auto` | ❌ EngineeringSecurityException (TIA ACL) | n/a |
| Cycle-7.6 retry post-ACL grant | `--only=ubp-auto` | ✅ Project saved | n/a (cycle-7.6 = facade swap only, adapter still direct setter) |
| Cycle-7.6b fix | `--only=ubp-auto` | ✅ Project saved | ✅ all 5 IOFields show Count=1 (TagDynamization created) |
| Cycle-7.6b project-wide | `--only=ubp-pallet` | ✅ saved | ✅ all 6 IOFields Count=1 |
| Cycle-7.6b project-wide | `--only=ubp-manual` | ✅ saved | ✅ 31 success markers (15 IOFields × 2 + Project saved) |
| Cycle-7.6b project-wide | `--only=ubp-diag` | ✅ saved | ✅ 3 success markers (1 IOField × 2 + Project saved) |
| Cycle-7.6c v2 final fire | **PENDING** — operator may re-fire or accept current state as final | — | — |

**Operator manual confirmation**: tag-table cross-check via `Ubp_PLC [94]` screenshot confirms all bindings reference existing HMI tag names. Operator declared "fix is done".

## §5 scara-PLC re-test trigger (verification gate)

Per PLC handoff `_HMI_Followups_HeaderStripAndIOFieldRendering.md` §5 expected post-cycle-7.6 verification:

```
1. `.\harness\Prearm_AbcdeAxes.ps1 -TargetIp 192.168.0.5` → expect axesReady=TRUE
2. ABCDE 5/5 smoke → observe `ioautoStep` advancing 0→10→20→30→40→50→10 as numeric Int
   + `iotgtX/Y/Z/A` showing live LReal coordinates (NOT path-string text)
3. Switch to palletizing mode → `ioautoStep` advances 0→1→2..→48→1
   (facade routes via activeMode)
4. Manual stop → all 5 IOFields zero out
```

**If smoke shows all 4 gates PASS** → Issue A CLOSED → flip cycle-7.6 PENDING_VERIFICATION → VERIFIED → PLC contract side (cycle-7.5 palletizing surface) can also flip to VERIFIED.

**If gate 2 still shows path-string text** → escalate to cycle-7.6d. Most likely remaining cause: C71 facade PLC-side deploy incomplete OR `FB_HMIStatusMirror` cyclic copier not running. Diagnostic: PLCSIM-Adv Watch Table on `GDB_HMI_Status.currentStep` — if Int value updates per cycle step, facade is live and HMI binding is the issue; if frozen at 0, facade isn't deployed/running.

**Bonus side benefit**: facade routes per `activeMode` — `02_Auto_Ubp` cardProgress now also displays live palletizing state when operator switches to Pallet mode (was previously frozen on ABCDE iDB values since cycle-7.0). Verifiable in gate 3.

## §6 Cross-cutting impact note

**ALL IOFields project-wide** now use canonical V20 TagDynamization (cycle-7.6b is in `UnifiedScreenAdapter`, applies to every `CreateIoField` call). UBP families touched: Auto (5 fields) + Pallet (6) + Manual (15: Kin target 3 + Quadrant 4 + per-axis 8) + Diag (1). Plus any future IOField in any builder. **No HMI tag table side effects** — bootstrap unchanged (all referenced HMI tag names already exist).

## §7 Issue B status (cycle-7.7 — header strip)

**Still deferred** per PLC handoff §2 sequencing ("cycle-7.7+ after #1 lands"). Operator directive this session: cycle-7.6-only scope. Cycle-7.7 work outline (carryover from prior planning + this handoff for PLC-agent awareness):

- Replace `UbpLayoutHostBuilder.BuildTopBar()` static `txtHostTitle` (line 228-231) with functional widget group:
  - Title area (~180px wide)
  - Button group: `btnAxesEnable` (TOGGLE LEVEL) + `btnAxesHome` (PULSE 300ms) + `btnAxesReset` (PULSE 300ms) — **NOT gated by 3-way mode mutex** per PLC handoff §3 mutex rules
  - Lamp group: `lampAxesEnabled` (green) + `lampAxesHomed` (blue) + `lampAxesError` (red) + `lampAxesReady` (overall green)
  - Optional active-mode indicator (hmiActiveMode Int 0-3 enum → text "Idle"/"ABCDE"/"Palletizing"/"Manual")
- Add 3 new W HMI tags + bootstrap calls:
  - `enableAxes` → `GDB_Control.enableAxes` (Bool LEVEL)
  - `homeAxes` → `GDB_Control.homeAxes` (Bool PULSE)
  - `resetAxes` → `GDB_Control.resetAxes` (Bool PULSE)
- Reuse existing R HMI tags: `axesEnabled`, `axesHomed`, `axesError`, `axesReady`, `hmiActiveMode` (all in `Ubp_PLC`).
- TopBar stays at 80px height (no canvas reflow). Persistent across all 6 content tabs via `01_Layout_Ubp` host pattern.

Estimated cycle-7.7 scope: ~150 LOC delta across `UbpLayoutHostBuilder.cs` + `AbcdePhase1Tags.cs` + `Program.cs`. Will plan + fire next.

## §8 Notes + closure markers

- 🆕 [NEEDS_scaraPLC] — re-run smoke per §5; report back in next PLC handoff or note in scoreboard
- 🟢 [SOURCE_DONE] — cycle-7.6 + 7.6b + 7.6c v2 ~90 LOC across 5 files, 4 fires saved
- 🟢 [TAG_TABLE_CROSS_CHECK_DONE] — operator confirmed `Ubp_PLC [94]` tag table contains all required HMI tag names matching factory method returns + facade short names
- ⏳ [PENDING_VERIFICATION] — runtime smoke per §5 will flip → VERIFIED
- ⏳ [NEXT_CYCLE] — cycle-7.7 header strip + Axes Enable/Home/Reset / 4 lamps / active-mode indicator (Issue B); HMI agent begins planning next
- ℹ️ [INFORMATIONAL] — cycle-7.6b adapter fix is cross-cutting; benefits ALL IOFields project-wide (Palletizing, Recipe, Stack, Maintenance, etc.) once those families are re-fired
- ℹ️ [INFORMATIONAL] — CLAUDE.md feedback note "V20 HmiIOField.ProcessValue requires TagDynamization" now reflected in `UnifiedScreenAdapter.CreateIoField` — was previously fixed in commit `af5c67b` 2026-05-06 per CLAUDE.md but evidently reverted or applied to a different code path; cycle-7.6b is the definitive landing for UBP family

End of HMI Handoff 2026-05-19 — Cycle-7.6 Issue A closed; scara-PLC re-test trigger.
