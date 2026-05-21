**Status:** PENDING_VERIFICATION

# HMI → PLC Handoff — 2026-05-18 (Cycle-7.5: NEW `02_Pallet_Ubp` per C70 Option A + C71 facade adoption + 3-button mode-mutex symmetric retrofit; 14 new HMI tags; 1 cycle-7.1 binding bug fixed)

> **Predecessor (HMI lane):** [HMI_HANDOFF_2026-05-18_Cycle7_4_Canvas1280x800Correction.md](HMI_HANDOFF_2026-05-18_Cycle7_4_Canvas1280x800Correction.md) (canvas correction 1024×600 → 1280×800)
>
> **Predecessor (PLC lane):** [PLC_HANDOFF_2026-05-18_C69_Phase2_PalletizingBackport.md](../../../hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/PLC_HANDOFF_2026-05-18_C69_Phase2_PalletizingBackport.md) (Phase 2.2 palletizing VERIFIED 12/12) + [PLC_HANDOFF_2026-05-18_C70_PalletizingHmiSurfaceProposal.md](../../../hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/PLC_HANDOFF_2026-05-18_C70_PalletizingHmiSurfaceProposal.md) (HMI screen design proposal + retrofit callout) + [PLC_HANDOFF_2026-05-18_C71_HMIStatusFacade.md](../../../hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/PLC_HANDOFF_2026-05-18_C71_HMIStatusFacade.md) (GDB_HMI_Status read-side facade with 36 members; PENDING_VERIFICATION)
>
> **Triggered by:** Operator directive "read the hand off report and build auto screen" + 3 subsequent design-clarification messages: (1) confirm mutex responsibility table (HMI owns clearing other mode bits); (2) extend mutex retrofit to all 3 mode buttons in same cycle (per C70 §4 retrofit callout); (3) read C71 + adopt facade for new screen reads.

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-18 |
| TIA target | `hmiDemoSCARA_ABCDE.ap20` at HMI_1 |
| Plan file | `C:\Users\Admin\.claude\plans\there-is-should-be-tingly-stroustrup.md` (operator-approved via ExitPlanMode after 4 plan-mode revisions) |
| Source delta | 1 new file + 7 edited files = **~395 LOC** |
| Build verdict | Single build **0W / 0E** in 2.03s |
| Fire verdict | 6 chunked fires, all SAVED (Layout → Pallet → Auto → Manual → Home → Diag) |
| HMI tag table | 68 → **82 entries** (+14 new); V20 cache hazard on Layout re-author AVOIDED |
| Status | **PENDING_VERIFICATION** — awaits operator TIA HMI Compile Rebuild All + Phase 2.2 palletizing runtime smoke walkthrough |

---

## 1. Source delivered

| File | Action | Delivery |
|---|---|---|
| `Builders/Ubp/UbpProfile.cs` | EDIT | `TabCellW` 256→**213** (6-tab nav: 1280/6 with 2 px slack) |
| `Builders/Ubp/UbpScreenNames.cs` | EDIT | NEW const `ContentPallet = "02_Pallet_Ubp"` |
| `Builders/Ubp/UbpLayoutHostBuilder.cs` | EDIT | NavTabs extended 5→6 (Pallet "码垛" inserted at index 2 between Auto + Manual) |
| `Builders/Ubp/AbcdePhase1Tags.cs` | EDIT | +14 const-pairs (4 W direct GDB_PalletizingCmd + 10 R via GDB_HMI_Status facade) + 14 EnsureTag bootstrap calls + new `BuildSetModeWithMutexJs` helper |
| `Builders/Ubp/UbpAutoBuilder.cs` | RETROFIT | btnAutoMode: `BuildToggleJs(Bo_Mode)` → `BuildSetModeWithMutexJs(Bo_Mode, Pal_Mode, Bo_ManualMode)` (SET-TRUE + 3-way mutex) |
| `Builders/Ubp/UbpManualBuilder.cs` | RETROFIT | btnKinEnable_Ubp: **REBIND target Bo_Mode → Bo_ManualMode** (corrects cycle-7.1 redo bug — Bo_ManualMode didn't exist then) + swap toggle → `BuildSetModeWithMutexJs(Bo_ManualMode, Bo_Mode, Pal_Mode)` |
| `Builders/Ubp/UbpPalletBuilder.cs` | **NEW** ~280 LOC | C71 facade-aware palletizing screen (clone of UbpAutoBuilder pattern; ALL reads via GDB_HMI_Status facade; writes direct to GDB_PalletizingCmd) |
| `App/Program.cs` | EDIT | `--only=ubp-pallet` knob + dispatch + ubp-all chain extension + help text update |

## 2. HMI tag manifest delta (68 → 82 entries; +14 new)

### Cycle-7.5 NEW tags

**4 W direct → GDB_PalletizingCmd**:
| HMI tag | Type | PLC path | Usage |
|---|---|---|---|
| `palMode` | Bool | `GDB_PalletizingCmd.bo_Mode` | swPalletMode SET-TRUE-with-mutex |
| `palInitPallet` | Bool | `GDB_PalletizingCmd.bo_InitPallet` | btnPalletInitPath PULSE 250ms |
| `palStart` | Bool | `GDB_PalletizingCmd.bo_Start` | btnPalletStart PULSE 250ms |
| `palStop` | Bool | `GDB_PalletizingCmd.bo_Stop` | btnPalletStop PULSE 250ms |

**10 R via GDB_HMI_Status facade**:
| HMI tag | Type | PLC path | Usage |
|---|---|---|---|
| `hmiActiveMode` | Int | `GDB_HMI_Status.activeMode` | lampActiveMode_Pal Range "2:2" (palletizing-active visual) |
| `hmiCurrentStep` | Int | `GDB_HMI_Status.currentStep` | cardProgress IOField + 4× cardLayerStack BackColor Range dyns (layers 1-4 highlight by step) + lampPalletRunning Range "1:48" |
| `hmiTotalSteps` | Int | `GDB_HMI_Status.totalSteps` | cardProgress IOField (48 in palletizing) |
| `hmiTargetX/Y/Z/A` | LReal × 4 | `GDB_HMI_Status.target_{x,y,z,a}` | cardProgress 4 target IOFields (mode-routed: facade auto-selects ABCDE vs Palletizing per activeMode) |
| `hmiPalletInitialed` | Bool | `GDB_HMI_Status.palletInitialed` | lampPalletInitialed Range "1:1" AccentGreen |
| `hmiAlarm` | Bool | `GDB_HMI_Status.alarm` | lampPalletAlarm Range "1:1" AccentRed (combined ABCDE+Palletizing alarm) |
| `hmiEstopLock` | Bool | `GDB_HMI_Status.estopLock` | lampPalletEstop Range "1:1" INVERTED green/red |

## 3. 3-way mode mutex retrofit — HMI owns write-side coordination

Per operator's responsibility matrix + C70 §4 retrofit callout + cycle-7.1 redo binding-bug correction, ALL three mode buttons now implement SET-TRUE-with-3-way-mutex pattern (clicking any mode button atomically activates that mode + clears the other 2):

| Mode button | Screen | Target | Auto-cleared others |
|---|---|---|---|
| `btnAutoMode` (ABCDE) | `02_Auto_Ubp` | `bo_Mode := TRUE` | `palMode := FALSE` + `bo_ManualMode := FALSE` |
| `swPalletMode` (Palletizing — NEW) | `02_Pallet_Ubp` | `palMode := TRUE` | `bo_Mode := FALSE` + `bo_ManualMode := FALSE` |
| `btnKinEnable_Ubp` (Manual — CRITICAL fix) | `02_Manual_Kin_Ubp` | `bo_ManualMode := TRUE` (was `Bo_Mode` — cycle-7.1 redo bug fixed) | `bo_Mode := FALSE` + `palMode := FALSE` |

**Cycle-7.1 redo binding-bug correction**: `btnKinEnable_Ubp` was previously bound to `Bo_Mode` (ABCDE auto mode) because `Bo_ManualMode` didn't exist when cycle-7.1 redo landed. Cycle-7.3 Phase G introduced `Bo_ManualMode` but `btnKinEnable_Ubp` was never retrofitted to use it. Cycle-7.5 corrects this AS PART OF the symmetric mutex retrofit — after this cycle's fire, `btnKinEnable_Ubp` correctly activates Manual mode (not ABCDE auto mode).

### Implementation status table (per operator's summary)

| Layer | Status post cycle-7.5 |
|---|---|
| PLC mutex contract (read-side enforcement, defense-in-depth) | ✅ Pre-existing in C69 |
| HMI mutex cooperation (write-side coordination) | ✅ **NEW** — all 3 mode buttons retrofitted in cycle-7.5 |
| Operator/test-script manual coordination | ✅ Still works (carryover) |

## 4. New `02_Pallet_Ubp` screen layout (1280×640 content area)

| Section | y range | Substance |
|---|---|---|
| Top status strip | 0..32 | 5 lamps via facade: `lampPalletRunning` (hmiCurrentStep Range "1:48" SiemensTeal) / `lampPalletInitialed` (hmiPalletInitialed AccentGreen) / `lampActiveMode_Pal` (hmiActiveMode Range "2:2" SiemensTeal) / `lampPalletAlarm` (hmiAlarm AccentRed) / `lampPalletEstop` (hmiEstopLock Range "1:1" INVERTED green/red) |
| Left column `cardLayerStack` | y=40..628 | 5 rows: Layer 1 (Box 1-4, z=300) BackColor Range "1:12" / Layer 2 (Box 5-8, z=350) Range "13:24" / Layer 3 (Box 9-12, z=400) Range "25:36" / Layer 4 (Box 13-16, z=450) Range "37:48" / Wrap placeholder. All bind to `hmiCurrentStep` via facade. |
| Right column top `cardPalletProgress` | y=40..320 | 6 IOFields ReadOnly via facade: hmiCurrentStep / hmiTotalSteps / hmiTargetX / hmiTargetY / hmiTargetZ / hmiTargetA |
| Right column bottom `cardPalletCtrl` | y=332..628 | 2×2 grid matching cycle-7.4b: Row 1 [btnPalletInitPath PULSE palInitPallet \| btnPalletStart PULSE palStart] / Row 2 [btnPalletStop PULSE palStop \| swPalletMode SET-TRUE palMode + 3-way mutex] |

## 5. Fire sequence (6 fires, all SAVED)

| # | Fire | Outcome |
|---|---|---|
| 1 | `--only=ubp-layout` | ✅ 6-tab nav + 6 content stubs (incl. NEW Pallet stub) + swContent/swBottomNav `rows=6/6` + project saved |
| 2 | `--only=ubp-pallet` (NEW) | ✅ 14 HMI tags `[ABCDE-P1][TAG] ✓ Created` (4 W + 10 R facade) + full screen authored (5 lamps + 4 cardLayerStack BackColor Range dyns + 6 IOFields + 4 buttons inc. swPalletMode SET-TRUE-with-mutex) + project saved |
| 3 | `--only=ubp-auto` (re-fire over stub) | ✅ btnAutoMode RETROFIT visible: `SET-TRUE → bo_Mode + mutex-clear palMode + bo_ManualMode` + project saved |
| 4 | `--only=ubp-manual` (re-fire over stub) | ✅ btnKinEnable_Ubp RETROFIT visible: `SET-TRUE → bo_ManualMode + mutex-clear bo_Mode + palMode (cycle-7.5 retrofit + rebind from Bo_Mode → Bo_ManualMode)` + project saved |
| 5 | `--only=ubp-home` (re-fire over stub) | ✅ project saved |
| 6 | `--only=ubp-diag` (re-fire over stub) | ✅ project saved |

**V20 cache hazard avoided** on Layout host re-author (cycle-6.12 / cycle-7.0 Phase E EngineeringObjectDisposed pattern did NOT trigger). Matches cycle-7.4 + cycle-7.3 precedents.

## 6. Manual-wiring follow-ups + dependencies

| Item | Status |
|---|---|
| C71 `GDB_HMI_Status` + `FB_HMIStatusMirror` + `instFB_HMIStatusMirror` PLC-side deploy | 🟡 **PENDING_VERIFICATION** (per C71 §6). Operator needs to: (a) VCI sync 4 files (1 new GDB + 1 new FB SCL + 1 new iDB XML + Main.scl edit); (b) TIA Compile Rebuild All; (c) PLCSIM-Adv memory reset; (d) Download; (e) C71 §5 manual smoke probe. **HMI source authoring + TIA HMI Compile complete WITHOUT C71 deploy** (PlcTag paths resolve at Compile-time via XML metadata). Runtime correctness requires C71 deploy. |
| `GDB_HMI_Status` "Accessible from HMI" iDB flag | 🟡 Verify at operator's TIA HMI Compile per C71 §6 #3. V20 Optimized defaults ON; if Compile flags, operator toggles via TIA → iDB Properties → Attributes. |
| Phase 2.2 palletizing runtime smoke walkthrough | 🟡 PENDING — per C70 §6 operator runbook (swPalletMode ON → btnPalletInitPath → btnPalletStart → observe palStep counts 1..48 + cardLayerStack rows highlight per layer + cardProgress IOFields show live XYZA cycling + btnPalletStop → palStep=0) |
| Cycle-7.1 redo `mcSetTool_Active` orphan (`Connection=<No Value>` per operator's tag dump) | 🟡 Not auto-repaired by cycle-7.5 (EnsureHmiTags is idempotent skip-if-present on existing names). Repair options documented in plan §Risks: (a) operator manual TIA Property Inspector fix; (b) operator deletes orphan + re-fires ubp-diag; (c) cycle-7.6 source patch for "repair-if-PlcTag-missing" |

## 7. Cycle-7.6+ candidates (out-of-scope this cycle)

| Item | Reason | Resolution path |
|---|---|---|
| Retrofit `02_Auto_Ubp` cardProgress to read via facade (`hmiCurrentStep` + `hmiTargetX/Y/Z/A`) | Per C71 §4.2 #2 — facade is ADDITIVE; existing direct bindings keep working | Cycle-7.6 — swap 5 IOField bindings on UbpAutoBuilder cardProgress |
| Retrofit Manual screens to use `GDB_HMI_Status.j{n}_*` per-joint fields | Per C71 §4.2 #3 — single source for 4 per-joint statuses | Cycle-7.7 |
| 2D 16-rectangle pallet view | Per C70 §3 visual layer-stack feedback | Cycle-7.8 candidate |
| 6 Cartesian Kin X/Y/Z jog widgets (still STRIPPED) | Phase G covers per-joint not Cartesian | Operator design decision pending |
| `BuildContentStub` idempotency hardening | Cycle-7.4 ordering-bug discovery | Cycle-7.6 source patch |
| `mcSetTool_Active` orphan repair | Cycle-7.1 silent PlcTag bind failure | Per §6 above |
| Per-axis Enable mutex review | btnAxSecEnable_Ubp_J{1..4} doesn't auto-enter Manual mode | Cycle-7.6 UX evaluation |

## 8. Verification

| Gate | State |
|---|---|
| Local C# build (`dotnet build --no-restore`) | ✅ 0W/0E in 2.03s |
| 6 chunked fires + 6 project.Save() | ✅ All clean; no V20 cache hazard |
| Operator TIA HMI Compile Rebuild All | 🟡 PENDING — expect 0E/0W; 14 new HMI tags resolve via GDB_PalletizingCmd (deployed per C69) + GDB_HMI_Status (deployed per C71 — PENDING_VERIFICATION) |
| Operator Phase 2.2 runtime smoke per C70 §6 | 🟡 PENDING — 6-tab nav visible + Pallet tab click → 02_Pallet_Ubp + swPalletMode mutex auto-clear + btnPalletStart cycles palStep + cardLayerStack rows highlight per layer + btnPalletStop halts cycle |
| C71 PLC-side deploy + smoke probe per §5 | 🟡 PENDING (operator-driven) |

## 9. Notes for the PLC agent

- **Cycle-7.5 absorbed C70 design recommendations + C71 facade adoption + operator's mutex responsibility matrix.** All 3 mode buttons now enforce 3-way mutex symmetric write-side coordination per the responsibility table.
- **Cycle-7.1 redo binding bug CORRECTED**: `btnKinEnable_Ubp` was binding ABCDE's `Bo_Mode` instead of `Bo_ManualMode`. Fixed this cycle as part of symmetric retrofit. After cycle-7.5 fire, the Manual ENABLE button correctly enters Manual mode (not ABCDE auto mode).
- **C71 facade is ADDITIVE**: cycle-7.5 NEW `02_Pallet_Ubp` adopts the facade fully (10 R via `GDB_HMI_Status.*`). Existing cycle-7.0..7.4 screens (`02_Auto_Ubp` / `02_Manual_*` / `02_Home_Ubp` / `02_Diag_Ubp`) keep their direct multi-DB reads — operator-discretionary retrofit deferred to cycle-7.6+.
- **No PLC asks back** — pure HMI consumer-side delivery against the Phase 2 + C71 PLC surfaces.
- **Closure markers**: `[VERIFIED-SOURCE]` 6 fires saved cleanly; `[NEEDS_OPERATOR]` TIA HMI Compile Rebuild All + Phase 2.2 runtime smoke + C71 PLC-side deploy; `[NEEDS_PLC_DEPLOY_FOR_RUNTIME]` GDB_HMI_Status facade reads require C71 fully deployed for runtime correctness (compile resolves either way via PlcTag XML metadata).

---

End of cycle-7.5 handoff. Cumulative cycle-7.0 → 7.5: **~2500 LOC + 82 HMI tags + 15 screens + ~140 wired bindings** on `hmiDemoSCARA_ABCDE.ap20`. UBP family surface complete for ABCDE Phase 1 + Phase 2.2 palletizing + Phase G manual control + C71 facade adoption (palletizing screen only; auto/manual retrofit deferred). Awaiting operator TIA Compile + Phase 2.2 runtime smoke.
