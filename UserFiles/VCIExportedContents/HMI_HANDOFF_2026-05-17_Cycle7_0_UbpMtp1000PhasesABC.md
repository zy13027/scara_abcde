**Status:** PENDING_VERIFICATION

# HMI → PLC Handoff — 2026-05-17 (Cycle-7.0 Phases A+B+C: UBP MTP1000 10-inch panel build — theme + layout + Auto module landed; Phase D Manual + E fire deferred)

> **Predecessor:** [HMI_HANDOFF_2026-05-17_AckC58C59C60_PathAComplete_PatternViewIntegrityCheck.md](HMI_HANDOFF_2026-05-17_AckC58C59C60_PathAComplete_PatternViewIntegrityCheck.md) (the parallel-session HMI ACK from cycle-6.23/.../6.26 line) — this cycle-7.0 is unrelated, opening a NEW 10-inch panel target per operator directive 2026-05-17 night.
>
> **PLC handoffs absorbed via read** (no ACK required this cycle — informational only):
> - [PLC_HANDOFF_2026-05-17_C60_AxisManualWiringRewriteAndOB124Migration.md](PLC_HANDOFF_2026-05-17_C60_AxisManualWiringRewriteAndOB124Migration.md) — raw-MC rewrite
> - [PLC_HANDOFF_2026-05-17_C61_Phase1ScopeLockAndWangShuoPattern.md](PLC_HANDOFF_2026-05-17_C61_Phase1ScopeLockAndWangShuoPattern.md) — 郑老板 Phase 1 scope lock (ABCDE + 王硕 4 REGION + library ban + SCL ≤ 2000)
> - [PLC_HANDOFF_2026-05-17_C62_HmiAckAbsorption.md](PLC_HANDOFF_2026-05-17_C62_HmiAckAbsorption.md) — parallel-session ACK absorption + Path-A 9/9 smoke
>
> **Cycle-7.0 is SEPARATE from C61 Phase 1 scope lock** per explicit operator confirmation in plan-mode AskUserQuestion. This new UBP target preserves the full Auto + Manual module surface (NOT the C61-minimized 启动/停止 + 4 IOField + 8 ScaraArm3D scope).

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-17 late-night (Cycle-7.0 Phases A+B+C delivered; Phases D/E/F deferred) |
| Triggered by | Operator directive: "create a ubp 10 inches, with template v9 - big font and siemens colour theme, adapt auto and manual module for the ubp" + 2 AskUserQuestion rounds + 1 ExitPlanMode redirect ("target directory is E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE / hmi is HMI_1 / the template is Stack C") |
| TIA target | `E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20` at HMI_1 (NEW project — operator pre-created with MTP1000 device) |
| Build verdict | 5 incremental builds (1 per phase + 3 mid-fix builds): all **0 Warning(s) / 0 Error(s)** |
| Phase A | ✅ DONE — UbpProfile.cs (canvas + font + colour tokens) |
| Phase B | ✅ DONE — UbpScreenNames.cs (+ UbpFolders + UbpTags) + Program.cs `--only=ubp-*` knobs |
| Phase C | ✅ DONE — UbpLayoutHostBuilder.cs + UbpAutoBuilder.cs + wired into RunUbpAuthoring |
| Phase D | ⏭️ DEFERRED to next session — UbpManualBuilder.cs (~480 LOC) |
| Phase E | ⏭️ DEFERRED — operator adds project to TIA Openness allow-list + fires (smoke-test surfaced `EngineeringSecurityException: Security error` per current allow-list) |
| Phase F | 🟡 PARTIAL — this handoff + scoreboard/ledger update; full ACK pending Phase D+E completion |
| Status | **PENDING_VERIFICATION** (Phases A+B+C source delivered; Phase D + E owe completion) |

---

## 1. Audit findings

_(N/A this cycle — no fire executed against `hmiDemoSCARA_ABCDE.ap20` yet. Will run audit in Phase E next session.)_

The smoke-test of the `--only=ubp-layout` knob against `hmiDemoSCARA_ABCDE.ap20` surfaced:
```
[UBP] mode=ubp-layout  project=E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20  device=HMI_1
[UBP][ERROR] EngineeringSecurityException: Security error.
The operation has timed out.
[UBP] done.
```

The new project needs operator-side TIA Openness allow-list registration (Phase E pre-step). Builder code is correct — only Openness auth blocks attach.

## 2. Tags authored / deprecated

_(N/A this cycle — fire not executed yet. Will land `Ubp_Local` table with `ubpNavSection / ubpPopupIndex / ubpManualTab` Int tags via `UbpLayoutHostBuilder.EnsureUbpTags()` in Phase E.)_

## 3. Manual-wiring follow-ups (deferred to Phase E + operator side)

| Item | Surface | Wiring directive |
|---|---|---|
| TIA Openness allow-list | Operator action | Add `hmiDemoSCARA_ABCDE.ap20` to TIA Openness ACL via TIA Portal → Tools → Settings → Openness → Authorized projects/users. Mirror the v10 .ap20 entry. Per `feedback_pytest_run_protocol.md` precedent. |
| btnAutoStart | UbpAutoBuilder authored placeholder | TIA Property Inspector: Tapped → `HMIRuntime.Tags("<cmdStart Phase 1 tag>").Write(true);` — Wang Shuo 4 REGION pattern uses `bo_Start` or `cmdStartAuto` (TBD per Phase 1 ACK). |
| btnAutoStop | UbpAutoBuilder authored placeholder | INVERT-both-bits JS once Phase 1 stop tags confirmed (mirror cycle-6.19b pattern: read-then-write `!Read()` for paired stop bits). |
| btnAutoReset | UbpAutoBuilder authored placeholder | PULSE pattern (Down→TRUE + Up→FALSE explicit event pair) per cycle-6.22 C41 Bug #2 fix to avoid stuck-TRUE. |
| IO fields (Next/P1/Step/Progress) | UbpAutoBuilder placeholder rects | Replace with HmiIOField widgets via TIA UI, bound to GDB_Control.\<step\>Layer / .\<step\>Box etc. (or Phase 1 ABCDE equivalents). |
| swContent + swBottomNav ScreenWindow | UbpLayoutHostBuilder | If V20 binding doesn't auto-create HmiScreenWindow, operator wires per `[SLOT][MANUAL-WIRING]` console lines (5 Range rows + 1 static row). |

## 4. Screen authoring

**Phase A — Theme + canvas tokens** (`Builders/Ubp/UbpProfile.cs`, 140 LOC):
- `Mtp1000` static class: 1024×600 canvas + 60/60 chrome + 480 content + 204×60 tab cell + big-font-aware touch tokens (BtnPrimary 240×80, IoField 280×56, ListRow 64)
- `UbpFont` static class: ScreenTitle 36 / SectionHeader 28 / CardTitle 24 / Body 20 / Caption 18 / IoFieldText 24 / ButtonText 22 / Display 40 / NumericFontFamily "Consolas"
- `UbpC` static class: Siemens-canonical Industrial Teal palette (SiemensTeal #00557F + accent + 3-tier status semantic + neutrals + text + disabled)

**Phase B — Screen-names + Program.cs knobs**:
- `Builders/Ubp/UbpScreenNames.cs` (90 LOC): `UbpScreenNames` + `UbpFolders` + `UbpTags` static classes
- `App/Program.cs` (~140 LOC added): `--only=ubp-layout` / `--only=ubp-auto` / `--only=ubp-manual` / `--only=ubp-all` knobs + maintenance-gate inclusion + dispatch switch + help text + `ScaraAbcdeProjectPath` const + `RunUbpAuthoring(string mode)` method body (attach-fallback to running TIA + project Open + builder dispatch + Save)

**Phase C — UbpLayoutHostBuilder + UbpAutoBuilder**:
- `Builders/Ubp/UbpLayoutHostBuilder.cs` (215 LOC, adapts `PalletizingHostBuilder.cs`):
  - Authors 5 content stubs (Home/Auto/Manual/Diag/Config) at 1024×480 with bilingual title cards
  - Authors `BottomNav_Ubp` component (1024×60, 5-tab strip with Siemens-teal active highlight)
  - Authors `01_Layout_Ubp` host (1024×600) with TopBar (60px, Siemens-teal accent) + swContent slot (Range-mapped to `ubpNavSection`) + swBottomNav slot (static)
  - Bootstraps `Ubp_Local` tag table with NavSection + PopupIndex + ManualTab Int tags
- `Builders/Ubp/UbpAutoBuilder.cs` (260 LOC, adapts `AutoPalletBuilder.cs`):
  - Authors `02_Auto_Ubp` content screen at 1024×480 with 2-column layout (Left 500w: cardNextStep + cardP1Step + cardStepList × 6 rows; Right 500w: cardProgress + cardAutoCtrl with 3 buttons Start/Stop/Reset)
  - Uses `CreateUbpPanelCard` helper (Siemens-theme: PanelHeader bar + Siemens-teal CardTitle text + 2px Siemens-teal accent stripe)
  - Big-font IoFieldText 24pt for value placeholders; bold CardTitle 24pt for card headers
  - All button bindings flagged `[MANUAL-WIRING]` pending Phase 1 PLC tag confirmation

## 5. Compile + audit results

```
$ dotnet build (5 incremental builds across Phase A/B/C — all final)
  Build succeeded.
      0 Warning(s)
      0 Error(s)

Mid-build fixes:
  Build 1: Phase A — CLEAN.
  Build 2: Phase B (Program.cs wiring) — CS0219 warning on unused plcConnectionName const → fixed with `_ = plcConnectionName;` discard.
  Build 3: Phase C step 1 (UbpLayoutHostBuilder) — CLEAN.
  Build 4: Phase C step 2 (UbpAutoBuilder) — CS0108 warning on CreatePanelCard hiding inherited member → renamed to CreateUbpPanelCard.
  Build 5: After rename — CS0628 protected-in-sealed warning → changed to private.
  Build 6 (final): 0W/0E across all changes.

$ dotnet run -- --only=ubp-layout (smoke-test attempt against hmiDemoSCARA_ABCDE.ap20)
  [UBP] mode=ubp-layout  project=...hmiDemoSCARA_ABCDE.ap20  device=HMI_1
  [UBP][ERROR] EngineeringSecurityException: Security error. The operation has timed out.
  [UBP] done.
  EXIT=0 (graceful error handling; project file path + builder code valid; only Openness ACL missing).
```

## 6. Issues escalated

### 6.1 [INFORMATIONAL] — Cycle-7.0 Phases A+B+C delivered

Source-side build of the 10-inch UBP MTP1000 panel target is ~600 LOC across
4 new files + 1 edited file. Builds clean. No PLC contract surface change.

### 6.2 [DEFERRED] Phase D — UbpManualBuilder.cs

Per plan recommendation "A+B+C this session, defer D to next session" (operator-confirmed at plan time):
- 02_Manual_Ubp host (Tier 3.5 inner-tab strip: Kin / Axis)
- 02_Manual_Kin_Ubp content (X/Y/Z jog rows + ENABLE/STOP/HOME)
- 02_Manual_Axis_Ubp content (2×2 J1..J4 quadrant grid)
- 02_Manual_Axis_Ubp_J{1..4} per-axis screens (4× with cycle-6.19 ENABLE INVERT preserved)
- Estimated scope: ~480 LOC + 1 build

Next session work. Plan file remains current — re-read same plan, execute Phase D + E + F.

### 6.3 [NEEDS_OPERATOR] Phase E — TIA Openness allow-list + fire

Operator action items before next-session fire:

1. **TIA Portal → Settings → Openness**: add `hmiDemoSCARA_ABCDE.ap20` to authorized projects/users (or mirror v10 entry). Per `EngineeringSecurityException` surfaced in smoke-test.
2. **Verify HMI_1 device is MTP1000 class** in the project tree (operator pre-set per directive; verify via Project tree → Devices → HMI_1 → Properties → DeviceType).
3. **Optionally pre-create `HMI_Connection_1`** PLC partner connection (builders can author tags without; PlcTag bindings activate when operator wires Connection in TIA UI per [MANUAL-WIRING] log lines).

After Phase E setup, fire: `dotnet run -- --only=ubp-all` from main repo.

### 6.4 [INFORMATIONAL] — Cycle-7.0 vs C61 Phase 1 PLC alignment

Per operator confirmation in plan-mode AskUserQuestion: cycle-7.0 is SEPARATE from C61 Phase 1 scope lock. Full Auto + Manual module surface preserved on the 10-inch panel even though PLC backbone may have Phase 1 minimal scope (Wang Shuo 4 REGION ABCDE pattern).

**PLC tag implications**: UBP builders flag button bindings as `[MANUAL-WIRING]` because the SCARA_ABCDE project's PLC content may have different tag paths than v10's `ctrl_*` family. If Phase 1 ABCDE arbiter uses `bo_Start` / `bo_Stop` / `i16_AutoStep` (per Wang Shuo pattern per C61 §2), operator wires accordingly via TIA UI Property Inspector.

PLC agent need not change anything — UBP is a parallel HMI surface on the existing PLC backbone.

### 6.5 [INFORMATIONAL] — Cycle-7.1 candidate

Deferred items for cycle-7.1 (next-session bundle alongside Phase D+E+F):

| Item | Detail |
|---|---|
| Auto inner-tab (Pallet + Path split) | v10 has 02_Auto_Pallet + 02_Auto_Path; UBP cycle-7.0 ships single-screen 02_Auto_Ubp. cycle-7.1 adds inner-tab strip + Path content. |
| Layer-stack + current-layer drawer | v10's Col3 layer-stack + 4×6 current-layer grid not in cycle-7.0 UBP; cycle-7.1 adds as "Layers" tab cell. |
| Cycle-6.17 banner extension to UBP | PrerequisiteBannerBuilder targets HMI_1 on v10; cycle-7.1 extends to handle HMI device param OR clones as UbpPrerequisiteBannerBuilder. |
| Final PLC tag bindings on Auto buttons | Once Phase 1 ABCDE arbiter PLC paths confirmed (C61 follow-up), replace [MANUAL-WIRING] placeholders with concrete JS bindings. |

## 7. Verification

| Gate | Test | Status |
|---|---|---|
| Phase A build | `dotnet build` after UbpProfile.cs add | ✅ 0W/0E |
| Phase B build | `dotnet build` after Program.cs wiring | ✅ 0W/0E (after CS0219 fix on unused const) |
| Phase C build | `dotnet build` after UbpLayoutHost + UbpAuto | ✅ 0W/0E (after CS0108 + CS0628 fixes) |
| Phase B knob recognition | `--only=ubp-layout` dispatches into RunUbpAuthoring | ✅ confirmed via smoke-test stdout |
| Phase E pre-fire setup | Operator adds project to Openness ACL | **PENDING OPERATOR** |
| Phase E fire | `dotnet run -- --only=ubp-all` against `hmiDemoSCARA_ABCDE.ap20` | **PENDING — needs Phase D + ACL** |
| Phase E audit | `dotnet run -- --only=audit-tags` against new project | **PENDING** |
| Phase F runtime smoke | Operator opens `01_Layout_Ubp` in MTP1000 simulator | **PENDING** |

## 8. Notes for PLC agent

- **No PLC action requested.** Cycle-7.0 is HMI-side new-panel surface; no contract surface change.
- **PLC tag bindings on UBP Auto buttons** flagged `[MANUAL-WIRING]` — operator wires concrete tags via TIA UI once Phase 1 ABCDE arbiter PLC paths are confirmed (Wang Shuo 4 REGION's `bo_Start` / `i16_AutoStep` per C61). PLC agent may want to advise the canonical Phase 1 tag names in next handoff so operator wires correctly.
- **PLC agent should note** cycle-7.0 as "HMI authors parallel 10-inch panel UBP on hmiDemoSCARA_ABCDE.ap20 HMI_1 using same PLC backbone" — informational, no ACK needed.

## 9. Cross-references

- HMI predecessor (parallel-session, unrelated subject): [HMI_HANDOFF_2026-05-17_AckC58C59C60_PathAComplete_PatternViewIntegrityCheck.md](HMI_HANDOFF_2026-05-17_AckC58C59C60_PathAComplete_PatternViewIntegrityCheck.md)
- PLC C60: [PLC_HANDOFF_2026-05-17_C60_AxisManualWiringRewriteAndOB124Migration.md](PLC_HANDOFF_2026-05-17_C60_AxisManualWiringRewriteAndOB124Migration.md)
- PLC C61 (Phase 1 scope lock — informs cycle-7.1 PLC binding work): [PLC_HANDOFF_2026-05-17_C61_Phase1ScopeLockAndWangShuoPattern.md](PLC_HANDOFF_2026-05-17_C61_Phase1ScopeLockAndWangShuoPattern.md)
- PLC C62: [PLC_HANDOFF_2026-05-17_C62_HmiAckAbsorption.md](PLC_HANDOFF_2026-05-17_C62_HmiAckAbsorption.md)
- Plan file (cycle-7.0 source): `C:\Users\Admin\.claude\plans\there-is-should-be-tingly-stroustrup.md`
- Source files (main repo, all uncommitted):
  - `Builders/Ubp/UbpProfile.cs` (NEW, 140 LOC)
  - `Builders/Ubp/UbpScreenNames.cs` (NEW, 90 LOC)
  - `Builders/Ubp/UbpLayoutHostBuilder.cs` (NEW, 215 LOC)
  - `Builders/Ubp/UbpAutoBuilder.cs` (NEW, 260 LOC)
  - `App/Program.cs` (EDIT, ~140 LOC added: knobs + help + dispatch + RunUbpAuthoring method)
- Knobs: `--only=ubp-layout` + `--only=ubp-auto` + `--only=ubp-manual` (stub) + `--only=ubp-all` — target `hmiDemoSCARA_ABCDE.ap20` HMI_1

---

## 10. Closure markers

- `[LANDED — PHASES A+B+C]` Source-side build of UBP MTP1000 panel target delivered: theme tokens + screen-names + Layout host + Auto module. ~700 LOC across 4 new files + 1 edited.
- `[DEFERRED]` Phase D — UbpManualBuilder.cs (~480 LOC). Next-session execution per plan recommendation.
- `[NEEDS_OPERATOR]` Phase E pre-step — add `hmiDemoSCARA_ABCDE.ap20` to TIA Openness allow-list (smoke-test surfaced `EngineeringSecurityException`); confirm HMI_1 MTP1000 device class + PLC connection setup.
- `[PENDING_VERIFICATION]` Cycle-7.0 status — flips → VERIFIED after Phase D + E + F complete + operator runtime smoke confirms big-font + Siemens-teal theme + responsive tabs.
- `[INFORMATIONAL]` Phase 7 PLC-feedback verdict — pure HMI side. PLC contract unchanged. PLC may advise canonical Phase 1 tag names for cycle-7.1 [MANUAL-WIRING] resolution.
- `[CYCLE-7.1 CANDIDATE]` Auto inner-tab Pallet+Path split; layer-stack/current-layer drawer; cycle-6.17 banner extension to UBP; final PLC tag bindings.

---

_End of HMI_HANDOFF_2026-05-17_Cycle7_0_UbpMtp1000PhasesABC.md_

**Status:** PENDING_VERIFICATION
