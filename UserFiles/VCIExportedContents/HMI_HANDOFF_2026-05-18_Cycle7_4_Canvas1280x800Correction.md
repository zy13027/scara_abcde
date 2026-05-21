**Status:** PENDING_VERIFICATION

# HMI → PLC Handoff — 2026-05-18 (Cycle-7.4 canvas correction: 1024×600 → 1280×800; all 14 UBP screens re-authored to fill real MTP1000 visible area)

> **Predecessor (HMI lane):** [HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md](HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md) (Phase G unblock — 53 Manual widgets rebound; cumulative ~2050 LOC + 68 HMI tags + 14 screens)
>
> **Triggered by:** Operator screenshots (post cycle-7.3 fire): TIA "New device" dialog confirms MTP1000 Unified Basic (6AV2 123-3KB32-0AW0) is **10.1" TFT 1280×800**, NOT the 1024×600 I assumed in cycle-7.0 plan. Editor screenshot shows my 1024×600 widgets cluster top-left of the actual visible area (black outline = real device); ~40% of screen unused. Operator directive: "you need adapt the UBP 1280 *800 size / black line is UBP 10 inch real visible area".

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-18 |
| TIA target | `E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20` at HMI_1 |
| Plan file | `C:\Users\Admin\.claude\plans\there-is-should-be-tingly-stroustrup.md` (cycle-7.4 plan, operator-approved via ExitPlanMode with 2 design defaults: chrome 80 + 2-column retained) |
| Source delta | ~50 LOC across 5 files: 6 const bumps in `UbpProfile.cs` + ~12 hardcoded fixes in `UbpManualBuilder.cs` + 3 in `UbpHomeBuilder.cs` + 3 in `UbpAutoBuilder.cs` + 3 in `UbpDiagBuilder.cs` |
| Build verdict | Single build clean **0W / 0E** in 2.17s |
| Fire sequence | 5 chunked fires (manual + auto + home + diag + layout) all SAVED on canonical project; then 4 content re-fires (ordering fix — see §5 below) all saved |
| Total operator confirmations | 2 (plan-mode ExitPlanMode approval + "go" for fires 3-5 + 4 content re-fires implicit) |
| Status | **PENDING_VERIFICATION** — operator TIA HMI Compile Rebuild All + runtime smoke walkthrough remains |

---

## 1. Canvas token bump (`Builders/Ubp/UbpProfile.cs` — 6 const changes)

| Constant | Before (cycle-7.0) | After (cycle-7.4) |
|---|---|---|
| `CanvasW` | 1024 | **1280** |
| `CanvasH` | 600 | **800** |
| `TopBarH` | 60 | **80** |
| `BottomNavH` | 60 | **80** |
| `ContentH` (derived) | 480 | **640** (= 800 − 80 − 80) |
| `TabCellW` | 204 | **256** (1280 / 5 exact, no slack) |
| `TabCellH` | 60 | **80** |

All other tokens (button widths, IOField dimensions, Gap, CardTitleH, etc.) unchanged — operator-comfort touch-target sizes don't scale with canvas. `UbpFont` typography also unchanged — sized for 40-60 cm reading distance.

## 2. Builder hardcoded-value fixes

### 2.1 — `UbpManualBuilder.cs` (~12 fixes)

| Method | Before | After |
|---|---|---|
| `InnerTabH` const | 60 | **80** (proportional to canvas bump) |
| `InnerContentH` (derived) | 420 | **560** (= 640 − 80, auto) |
| `BuildKinScreen` axis rows: `rowY` start | 56 | **80** |
| `BuildKinScreen` axis row spacing | 100 | **140** |
| `BuildKinStatusBanner` rowH | 48 | **64** |
| `BuildKinAxisRow` rowH | 92 | **120** |
| `BuildKinFooterCtas` btnH × btnW | 64 × 480 | **80 × 600** |
| `BuildAxisScreen` quadrant offsets | (0,0)/(512,0)/(0,210)/(512,210) | **(0,0)/(640,0)/(0,280)/(640,280)** |
| `BuildAxisQuadrant` quadW × quadH | 512 × 210 | **640 × 280** |
| `BuildPerAxisHeader` hdrH | 72 | **96** |
| `BuildPerAxisPositionCard` top × cardH | 80 × 112 | **104 × 140** |
| `BuildPerAxisJogRow` top × rowH × btnH | 200 × 112 × 80 | **256 × 152 × 100** |
| `BuildPerAxisControlRow` top × rowH × btnH | 320 × 112 × 80 | **416 × 152 × 100** |
| `BuildPerAxisHintFooter` top | 440 | **576** |

### 2.2 — `UbpHomeBuilder.cs` (3 fixes)

| Method | Before | After |
|---|---|---|
| `BuildHeroBanner` hdrH | 68 | **88** |
| `BuildLeftColumn` / `BuildRightColumn` y × cardH | 80 × 316 | **100 × 448** |
| `BuildStatusStrip` top × rowH | 408 × 48 | **560 × 64** |

### 2.3 — `UbpAutoBuilder.cs` (4 fixes)

| Method | Before | After |
|---|---|---|
| `BuildLeftColumn` nextH | 140 | **180** |
| `BuildLeftColumn` p1H | 140 | **180** |
| `BuildRightColumn` progressH | 220 | **280** |
| `BuildRightColumn` btnH × btnGap | 52 × 8 | **72 × 16** |

### 2.4 — `UbpDiagBuilder.cs` (4 fixes)

| Method | Before | After |
|---|---|---|
| `BuildSafetyCard` rowH × rowGap | 92 × 4 | **124 × 8** |
| `BuildMcSetToolCard` cardH | 220 | **296** |
| `BuildMcSetToolCard` rowH | 30 | **44** |
| `BuildBlendProgressCard` y offset (cardH-dependent) | Pad+220+Gap=244 | **Pad+296+Gap=320** |

### 2.5 — `UbpLayoutHostBuilder.cs` — no source changes (all positioning derived from `Mtp1000.*` tokens; auto-scales)

## 3. Fire sequence + outcomes

| # | Fire | Outcome | Notes |
|---|---|---|---|
| 1 | `--only=ubp-manual` | ✅ Project saved | 7 Manual screens re-authored at 1280×560 (incl. 4 per-axis × 1280×640) |
| 2 | `--only=ubp-auto` | ✅ Project saved | 02_Auto_Ubp at 1280×640 |
| 3 | `--only=ubp-home` | ✅ Project saved | 02_Home_Ubp at 1280×640 |
| 4 | `--only=ubp-diag` | ✅ Project saved | 02_Diag_Ubp at 1280×640 |
| 5 | `--only=ubp-layout` | ✅ Project saved | 01_Layout_Ubp + BottomNav at 1280×800 + 5 content stubs WIPED my prior 4 content fires |
| 6 | `--only=ubp-auto` (re-fire) | ✅ Project saved | Restore content over stub |
| 7 | `--only=ubp-manual` (re-fire) | ✅ Project saved | Same |
| 8 | `--only=ubp-home` (re-fire) | ✅ Project saved | Same |
| 9 | `--only=ubp-diag` (re-fire) | ✅ Project saved | Same |

**V20 cache hazard avoided**: Layout host re-author (fire #5) did NOT trigger the cycle-6.12 / cycle-7.0 Phase E EngineeringObjectDisposed NRE pattern. Likely because the fresh TIA session state from cycle-7.3 left clean references; or because `BuildContentStub` re-authors content screens BEFORE the Layout host (re-cached state via the content stub creation step).

## 4. Cycle-7.4 [SOURCE BUG] — ubp-layout overwrites prior content with stubs

**Discovered during this cycle's fire sequence:**

`UbpLayoutHostBuilder.Build()` always calls `BuildContentStub()` for all 5 content tabs (Home/Auto/Manual/Diag/Config) BEFORE authoring the layout host. The stub renders a bilingual title-card placeholder ("占位页面 / Placeholder — Tier 3 pending"). When ubp-layout fires AFTER ubp-auto/manual/home/diag have already authored their full content surfaces, the stubs OVERWRITE the content.

**Workaround applied**: re-fire ubp-auto + ubp-manual + ubp-home + ubp-diag AFTER ubp-layout to restore content over the stubs. Fires 6-9 above.

**Root cause + future fix**: `UbpLayoutHostBuilder.BuildContentStub()` should be made idempotent — skip if the screen already has substantive content (>2 widgets, or a marker widget like `recAutoBg`/`recHomeBg`/`recManualBg`/`recDiagBg`). Currently it unconditionally rewrites. Cycle-7.5 candidate to harden the chassis builder.

**Canonical ubp-all fire order** (for future cycles when re-authoring is needed): layout FIRST (stubs land), then content builders SECOND (overwrite stubs). Operator's `--only=ubp-all` knob in Program.cs RunUbpAuthoring dispatches in the order: layout → auto → manual → home → diag — which is the SAFE ordering. The fire sequence I made this cycle (manual → auto → home → diag → layout) was the WRONG order. Documented for future reference.

## 5. Cumulative cycle-7.0 → cycle-7.4 state

| Cycle | Source delta | What landed |
|---|---|---|
| Cycle-7.0 | ~1480 LOC, 6 source files | Initial UBP family at 1024×600 + Stack-C chassis + Auto + Manual + 4 per-axis + Diag + Config screens |
| Cycle-7.1 (redo) | ~285 LOC | ABCDE binding pivot (v10 LKinCtrl namespace → Phase 1 ABCDE) + HMI tag bootstrap + 4 PLC question answers |
| Cycle-7.3 | ~285 LOC | Phase G unblock — 53 Manual widgets rebound to GDB_ManualCmd/Status; 51 NEW HMI tags |
| **Cycle-7.4 (this)** | **~50 LOC** | **Canvas correction 1024×600 → 1280×800 — geometry-only adaptation; no tag changes; all 14 screens re-authored at new dimensions** |
| **TOTAL** | **~2100 LOC**, 6 source files, **68 HMI tags**, **14 screens**, **~120 wired bindings** | Full SCARA ABCDE UBP MTP1000 HMI surface |

## 6. Verification

| Gate | State |
|---|---|
| Local C# build | ✅ 0W/0E in 2.17s |
| 5 builder fires + 4 ordering-fix re-fires | ✅ All saved successfully (9/9 project.Save() ✓) |
| V20 cache hazard on Layout re-author | ✅ Avoided (no EngineeringObjectDisposed NRE) |
| HMI tag table | ✅ 68 tags preserved (no add/delete this cycle — pure geometry) |
| TIA HMI Compile Rebuild All | 🟡 PENDING — expect 0E/0W (no new tag refs; geometry-only change) |
| Operator runtime smoke | 🟡 PENDING — open `01_Layout_Ubp` in TIA Runtime; verify widgets fill the black-outline 1280×800 visible area; no top-left clustering |

## 7. Manual-wiring / cycle-7.5 candidates

| Item | Reason | Resolution path |
|---|---|---|
| `UbpLayoutHostBuilder.BuildContentStub()` should be idempotent | This cycle's discovered ordering bug — Layout re-author wipes content | Cycle-7.5: add skip-if-substantive-content check (e.g. probe for `recXxxBg` page-background marker rect; skip if present) |
| 6 Cartesian Kin X/Y/Z jog widgets (still STRIPPED from cycle-7.3) | Phase G covers per-joint (J1..J4) not Cartesian; design decision pending | Operator decides: PLC adds Cartesian jog FB OR HMI repurposes widgets as cfgKinTarget increment/decrement buttons |

## 8. Notes for the PLC agent

- **Pure HMI geometry adaptation** — no PLC asks, no tag changes, no contract surface delta. Cycle-7.4 is HMI-only consumer-side rework.
- **No new HMI handoff §6 proposals** for HMI_BINDING_MAP.md — all bindings stable from cycle-7.3.
- **All 14 UBP screens now fill the canonical 1280×800 MTP1000 visible area** (matching TIA hardware definition 6AV2 123-3KB32-0AW0).
- **Closure markers**: `[VERIFIED-SOURCE]` 50 LOC geometry refactor compiled clean + 5 fires saved + 4 ordering re-fires saved; `[NEEDS_OPERATOR]` TIA HMI Compile Rebuild All + runtime smoke walkthrough for full VERIFIED flip; `[CYCLE-7.5-CANDIDATE]` chassis builder idempotency hardening.

---

End of cycle-7.4 canvas correction handoff. Cumulative cycle-7.0 → cycle-7.4 SCARA ABCDE UBP HMI surface (~2100 LOC + 68 tags + 14 screens) NOW MATCHES the canonical MTP1000 1280×800 device dimensions. Awaiting operator TIA HMI Compile + runtime smoke.
