**Status:** PENDING_VERIFICATION

# HMI → PLC Handoff — 2026-05-17 (Cycle-7.0 Phase D: UbpManualBuilder.cs landed — 7 screens, 707 LOC; Phase E fire still owed)

> **Predecessor:** [HMI_HANDOFF_2026-05-17_Cycle7_0_UbpMtp1000PhasesABC.md](HMI_HANDOFF_2026-05-17_Cycle7_0_UbpMtp1000PhasesABC.md) (Phases A+B+C: theme tokens + screen-names + layout host + Auto module; Phase D listed as deferred to next session)
>
> **Continuation trigger:** Operator returned in same session with directive "do the next step" + Auto mode active → Phase D executed in current session rather than deferring.
>
> **PLC handoffs absorbed via read** (no ACK required — informational only):
> - [PLC_HANDOFF_2026-05-17_C62_HmiAckAbsorption.md](PLC_HANDOFF_2026-05-17_C62_HmiAckAbsorption.md) — Path-A 9/9 PLCSIM-Adv smoke VERIFIED + Pattern view Depth A integrity intact (no obligations created for cycle-7.0 lane)
>
> **Cycle-7.0 scope reminder:** SEPARATE from C61 Phase 1 scope lock. Full Auto + Manual module surface preserved on UBP MTP1000, NOT the C61-minimized ABCDE-only HMI_1 surface on v10/v9 main HMI device. Tag bindings reach the same `mc_kin_*` / `mc_axis_J{n}_*` PLC backbone — identical contract, separate authoring lane.

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-17 late-night continuation (Phase D delivered in same session) |
| Triggered by | Operator: "do the next step" + Auto mode active. Per cycle-7.0 plan Phase D = `UbpManualBuilder.cs` adaptation. |
| TIA target | `E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20` at HMI_1 (unchanged from Phases A+B+C) |
| Build verdict | 2 incremental builds: 1 surfaced CS8625 nullable-default warning on `BuildLamp`'s `activeColor` parameter, fix landed (`= UbpC.LampOk` instead of `= null` + null-coalesce); second build **0 Warning(s) / 0 Error(s)** |
| Phase A | ✅ DONE (prior handoff) — UbpProfile.cs tokens |
| Phase B | ✅ DONE (prior handoff) — UbpScreenNames + Program.cs knobs |
| Phase C | ✅ DONE (prior handoff) — UbpLayoutHostBuilder + UbpAutoBuilder |
| **Phase D** | ✅ **DONE this turn** — UbpManualBuilder.cs (707 LOC) + Program.cs RunUbpAuthoring dispatch wired |
| Phase E | ⏭️ STILL DEFERRED — operator adds project to TIA Openness allow-list + fires `--only=ubp-all` |
| Phase F | 🟡 PARTIAL — this handoff + scoreboard + ledger; full ACK pending Phase E completion + operator runtime smoke |
| Status | **PENDING_VERIFICATION** (Phases A+B+C+D source delivered; Phase E + operator smoke still owe completion) |

---

## 1. Audit findings

_(N/A this cycle — no fire executed against `hmiDemoSCARA_ABCDE.ap20` yet. Operator-side TIA Openness allow-list registration still owes per Phase E pre-step.)_

## 2. Tags authored / deprecated

_(N/A this cycle — no fire. UbpLayoutHostBuilder.EnsureUbpTags will bootstrap `Ubp_Local` with `ubpNavSection / ubpPopupIndex / ubpManualTab` Ints in Phase E; UbpManualBuilder reuses the same Manual-tab Int.)_

## 3. Manual-wiring follow-ups (delta vs prior handoff: ZERO new items)

All [MANUAL-WIRING] obligations from the Phases A+B+C handoff remain unchanged. Phase D's `UbpManualBuilder.cs` reuses the **existing v10 `mc_kin_*` + `mc_axis_J{n}_*` tag layer** authored by `MotionControlBuilder` — no new TBD tag bindings, no new operator wiring asks.

Cycle-6.19 ENABLE INVERT pattern was authored **directly in source** (not [MANUAL-WIRING]):
- `btnAxSecEnable_Ubp_J{j}` (j=1..4) — Tapped slot bound to inline JS:
  ```javascript
  HMIRuntime.Tags("mc_axis_J{j}_cmd_Enable").Write(
    !HMIRuntime.Tags("mc_axis_J{j}_cmd_Enable").Read());
  ```
- Down/Up slots **LEFT EMPTY** (defensive per cycle-6.23 Comfort Panel duplicate-fire feedback in CLAUDE.md memory file). This prevents the cycle-6.23 known hazard where MTP1000 hardware fires Pressed-on-touchdown + Tapped-on-release as two events per quick tap (double-INVERT → net-no-op or double-PULSE noise).

Kin-screen ENABLE/STOP CTAs (`btnKinEnable_Ubp` / `btnKinStop_Ubp`) also use the cycle-6.19 INVERT pattern in Tapped, with Down/Up slots empty.

## 4. Screen authoring summary

UbpManualBuilder.Build() emits **7 screens** in order (sub-screens FIRST so swManualTab Range mapping resolves at slot-wire time):

| # | Screen | Folder | Canvas | Substance |
|---|---|---|---|---|
| 1 | `02_Manual_Kin_Ubp` | `UBP/02_Content` | 1024×420 | Single-row status banner (4 lamps: ENABLED / READY / HOMED / ERROR) + 3 axis rows (X/Y/Z × 92 px each — Display 40pt label + R/W IO target + JOG−/JOG+ HOLD buttons + active-axis lamp) + footer ENABLE/STOP CTAs (cycle-6.19 INVERT) |
| 2 | `02_Manual_Axis_Ubp` | `UBP/02_Content` | 1024×420 | 2×2 J{1..4} quadrant grid (512×210 cells) — each cell: J{n} Display label + actual-position read-only IO + JOG−/JOG+ HOLD + 3 status mini-lamps |
| 3 | `02_Manual_Axis_Ubp_J1` | `UBP/02_Content` | 1024×480 | Per-axis deep-drill: 72px header (Display title + 3 status lamps) + 2-card position row (Actual + Velocity) + JOG−/JOG+ HOLD row (big buttons) + ENABLE/HOME/RESET control row (**cycle-6.19 INVERT preserved on ENABLE**) + hardware-deadman hint footer |
| 4 | `02_Manual_Axis_Ubp_J2` | (same) | 1024×480 | Same template as J1 (j=2) |
| 5 | `02_Manual_Axis_Ubp_J3` | (same) | 1024×480 | Same template as J1 (j=3) |
| 6 | `02_Manual_Axis_Ubp_J4` | (same) | 1024×480 | Same template as J1 (j=4) |
| 7 | `02_Manual_Ubp` | `UBP/02_Content` | 1024×480 | Host — inner-tab strip (60px, 2 × 512px tabs Kin / Axis with Siemens-teal active-highlight) + Range-mapped `swManualTab` ScreenWindow (420px content area) |

**Geometry re-tile vs v10 ManualBuilder.cs (1280×640 → 1024×480 + big-font):**
- Inner-tab strip: 80→60px tall; 2 × 640→512px cells
- Kin content: 560→420 px; 3 axis rows compressed 120→92 px each; footer 96→64 px
- Axis 2×2 quadrants: 640×280→512×210 (innerPad 12→8); big-font keeps J{n} Display label readable
- Per-axis screens: NEW UBP surface (no v10 source); big-font + Siemens-teal accent stripes; cycle-6.19 INVERT preserved

## 5. Compile results

| Build | Source | Result | Notes |
|---|---|---|---|
| 1 | After Write of UbpManualBuilder.cs + Program.cs RunUbpAuthoring edit | **0 Errors / 1 Warning** | CS8625 on `BuildLamp(..., string activeColor = null)` — nullable literal in default parameter conflicts with non-nullable string |
| 2 | After fix (`= UbpC.LampOk` default + drop null-coalesce) | **0 Errors / 0 Warnings** ✅ | Time elapsed 1.26s |

Phase D delivers clean. Total source LOC = 707 (UbpManualBuilder.cs); ~707 + 5 (Program.cs dispatch edit) = ~712 LOC delta this turn.

## 6. Issues escalated for PLC agent

_None new from Phase D._ Continuing items carried from cycle-7.0 Phases A+B+C:
- [NEEDS_OPERATOR] TIA Openness allow-list registration for `hmiDemoSCARA_ABCDE.ap20` before Phase E fire (smoke-test confirmed `EngineeringSecurityException: Security error` at attach time)
- [INFORMATIONAL → PLC] Cycle-7.0 is parallel-track to C61 Phase 1 scope lock. PLC binding contract `mc_kin_*` + `mc_axis_J{n}_*` is REUSED unchanged — no PLC asks. Cycle-7.0 will VERIFY post Phase E + operator runtime smoke.

## 7. Verification commands (Phase E owed)

```bash
# Phase E fire (after operator adds project to TIA Openness allow-list):
cd /e/VS_Code_Proj/TiaUnifiedAuto
dotnet run -- --only=ubp-all
# Expected: 8+ screens authored (1 layout + 1 auto host + 1 auto-pallet content (planned for cycle-7.1 split)
#  + 1 manual host + 1 manual-kin + 1 manual-axis + 4 per-axis); project saves clean

# Phase E audit:
dotnet run -- --only=audit-tags
# Expected: declared count ≥ 1894 baseline (no UBP tag deltas — UBP family reuses
# existing mc_kin_* + mc_axis_J{n}_* tag layer authored by MotionControlBuilder)
# Plus 3 new local-table Int tags (ubpNavSection / ubpPopupIndex / ubpManualTab)
# in the new project's HMI_1 Ubp_Local table — declared count delta on this
# project = +3 from cold start, not against v10 baseline.
```

## 8. Notes for the PLC agent

- **Phase D delivers clean** — UbpManualBuilder.cs (707 LOC) + Program.cs dispatch edit landed; 2-build cycle (1 warning fixed, second clean). All cycle-6.19 ENABLE INVERT canonical patterns preserved on the 4 new per-axis screens.
- **Cycle-7.0 carries no PLC asks.** Tag bindings reach `mc_kin_*` / `mc_axis_J{n}_*` PLC paths via the existing MotionControlTags mapping — same contract as v10. PLC agent should treat cycle-7.0 as INFORMATIONAL.
- **Phase E + runtime smoke** still owe completion. Cycle-7.0 won't flip from PENDING_VERIFICATION to VERIFIED until operator (a) adds `hmiDemoSCARA_ABCDE.ap20` to TIA Openness allow-list, (b) fires `--only=ubp-all`, (c) confirms big-font + Siemens-teal theme + responsive tab nav + cycle-6.19 ENABLE INVERT toggle on per-axis screens via TIA Runtime / WebRH smoke.
- **Cycle-7.1 candidates** (out of scope, post-VERIFIED):
  - Auto inner-tab Pallet+Path split (currently 02_Auto_Ubp is single content cell)
  - Layer-stack + current-layer drawer (deferred from cycle-7.0 due to big-font + 1024×480 compaction)
  - Cycle-6.17 banner extension to UBP family (currently banner targets v10/v9 HMI_1 only)
  - Per-axis quadrant cards → deep-drill links (BindButtonClickScript on each card to write `ubpPopupIndex` + open per-axis screen)
  - Final PLC tag bindings replacing [MANUAL-WIRING] placeholders post C61 Phase 1 ABCDE arbiter tag confirmation
- **Closure markers** for this handoff: `[NEEDS_OPERATOR]` Phase E + smoke; otherwise INFORMATIONAL.

---

End of Phase D handoff. Awaiting operator for Phase E + runtime smoke to close cycle-7.0.
