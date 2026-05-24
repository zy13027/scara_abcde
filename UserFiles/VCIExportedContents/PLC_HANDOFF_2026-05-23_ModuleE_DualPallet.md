# PLC_HANDOFF — 2026-05-23 — Module E V3.0: Dual-pallet (WanErXin operator-driven + critical-review fixes)

**Status:** VERIFIED (2026-05-23) — Module E V3.0 PLC code deployed (MRES + download) and
smoke-tested green on PLCSIM-Adv instance `DemoScara_ABCDE`: **27/27 PASS** across all
11 sections (preamble, pallet 1 default regression, pallet 2 switch, mutex stalemate,
idle, WanErXin full+swap clear path, V3.0 Ack-reset, V3.0 mid-cycle swap attribution
[Bug #1 regression test], V3.0 both-released attribution, V3.0 aggregate, default
restore). `GDB_ActiveRecipe` restructured to `recipe1`+`recipe2` + per-pallet status +
WanErXin operator flags + per-pallet full alarms + V3.0 Ack/aggregate bits;
`FB_PatternAutoGen` V3.0 validates both recipes, mediates the mutex, writes the active
pallet's config, snapshots cycle-pallet on bo_InitPallet edge, supports explicit per-
pallet Ack reset, and computes the bo_BothPalletsFull aggregate. Smoke script:
`C:\Users\Admin\AppData\Local\Temp\scara_smoke_moduleE.ps1`. **V3.0 amends V2.0
same-day** with WanErXin-review bug fixes (see Section 1.5).

**From:** scara-PLC  **To:** scara-HMI
**Plan:** `C:\Users\Admin\.claude\plans\replicated-forging-flamingo.md` (SCARA Phase 2 Module E)
**Authoritative binding contract:** `HMI_BINDING_MAP.md` Section 10 (Section 9 is DEPRECATED)

---

## 1. What Module E adds

Two pallets, operator-driven switch — modelled on the `WanErXin_v1.0_V20` reference (per your
direction). The WanErXin pattern is:

- Two maintained Bool flags `bo_ExecutePallet1` / `bo_ExecutePallet2` — one per pallet,
  operator holds one to make that pallet active.
- **No auto-advance** when a pallet fills; the operator presses the OTHER side's button to
  swap (which also clears the just-emptied pallet's "full" flag so it can be re-used).
- Per-pallet `bo_PalletNFull` alarms. **No aggregate `bo_AllPalletsDone`** — by design.

`FB_AutoCtrl_Palletizing` is **unchanged** — Module E only extends `FB_PatternAutoGen` to do
per-pallet validation + the WanErXin mutex + write the active pallet's config into
`GDB_PalletizingCmd`.

## 1.5 V3.0 WanErXin critical-review fixes (same-day, 2026-05-23)

Per operator's request — "WanErXin pattern is from another Siemens engineer, contemplate
and verify it thoroughly" — the WanErXin source (`WanErXin_v1.0_V20\UserFiles\`,
specifically FC7 `码垛判断` for the actual pallet-switch logic; FB_Pallet_Station_Manager
is orphan) was reverse-engineered and cross-checked against my V2.0 implementation. Three
real bugs surfaced:

| # | Bug | Symptom | V3.0 fix |
|---|---|---|---|
| 1 | LatchPalletFull used live `i16_ActivePalletIdx` | Operator swap mid-cycle → wrong pallet's full bit latches. Both released mid-cycle → neither latches → re-press starts another cycle on the already-full pallet. | New `statCyclePalletIdx` snapshotted on rising edge of `GDB_PalletizingCmd.bo_InitPallet` (= moment Module-C builder locks `aCmd[]`). LatchPalletFull uses this snapshot — operator state changes mid-cycle no longer mis-attribute. |
| 2 | No reset of `bo_PalletNFull` without going via other pallet | Operator empties + replaces pallet 1, presses pallet 1 → stays idle, must "fake swap" via pallet 2 to release. | New `bo_AckPallet1Full` / `bo_AckPallet2Full` HMI-write bits; while held TRUE, the corresponding full bit clears each scan. WanErXin swap-clear path remains as convenience. |
| 3 | No aggregate "both pallets full" | HMI / future Module F-G has no single status bit to gate "both need unloading". | New `bo_BothPalletsFull` = `bo_Pallet1Full AND bo_Pallet2Full`, FB-computed each scan. |

**Other WanErXin oddities investigated and intentionally NOT copied** (mine was already
cleaner): equality-not-latched full bit (mine: latched on edge), `Count[i]==Total[i]` exact
equality (mine: latched on `bo_PalletDone` edge), parallel FB4/FC7 dead-code (mine: single
FB), missing `AND NOT thisSide` guard on swap-clear (mine: has the guard), multi-source
mutex via LSKI conditions (mine: single source of truth on operator flags).

Mid-cycle **swap prevention** (block activeIdx changes while cycle running) was considered
and rejected — V3.0's cycle-snapshot already makes mid-cycle swap safe (attribution stays
correct, the next cycle picks up the new pallet's config). Adding a hard block would remove
operator override capability for no robustness gain.

The V3.0 changes are zero-impact for the "normal" workflow (start pallet, wait for done,
swap) — the snapshot equals the live activeIdx in that case. V3.0 only matters at the
unhappy-path edges (mid-cycle swap, dual-flag release, physical refill without swap).

## 2. Shape change — Module D's `recipe` singular is GONE

`GDB_ActiveRecipe.recipe.*` (Module D) no longer exists. The DB now has:

- `recipe1 : UDT_Recipe` — pallet 1 (LEFT)
- `recipe2 : UDT_Recipe` — pallet 2 (RIGHT)
- Per-pallet status / echo: `bo_PatternValid1` + `_2`, `bo_PatternError1` + `_2`,
  `i16_ComputedGridColsX1` + `_X2`, `i16_ComputedGridRowsY1` + `_Y2`,
  `i16_ComputedBoxCount1` + `_BoxCount2`.
- Operator flags + status: `bo_ExecutePallet1`, `bo_ExecutePallet2`, `i16_ActivePalletIdx`.
- Per-pallet alarms: `bo_Pallet1Full`, `bo_Pallet2Full`.
- **V3.0 (2026-05-23):** explicit per-pallet Ack reset bits `bo_AckPallet1Full`,
  `bo_AckPallet2Full` (HMI-write); aggregate `bo_BothPalletsFull` (FB-write).

**HMI action:** rebind any Module D Section 9 paths to Section 10. The remap table is in
`HMI_BINDING_MAP.md` §10.4.

**The HMI binding work for Module D had not been authored yet (Module D was PENDING)** —
this rebind is effectively a single re-authoring against Section 10.

## 3. HMI action — author two PSCs + two-button switch + per-pallet alarms

### 3.1 Parameter Set Control (one per pallet)

Author two Parameter Set Controls (or one PSC with two parameter-set groups — vendor UX
choice), bound member-for-member to `GDB_ActiveRecipe.recipe1.*` and `.recipe2.*`. Each PSC
manages its own library of box-product recipes on the panel storage.

**Same `bo_Valid` handshake as Module D, per pallet:**

1. `recipeN.bo_Valid := FALSE`
2. Write all `recipeN.product.*` / `recipeN.pallet.*` / `recipeN.dynamics.*` / `recipeN.sName`
3. `recipeN.bo_Valid := TRUE`

### 3.2 Two-button pallet switch UI (WanErXin idiom)

Two MAINTAINED buttons on the runtime screen:

- "**Execute Pallet 1**" → write `GDB_ActiveRecipe.bo_ExecutePallet1` (hold while pallet 1 is
  the active target; release when swapping).
- "**Execute Pallet 2**" → write `GDB_ActiveRecipe.bo_ExecutePallet2`.

UX guidance (matches WanErXin):

- The HMI should ideally **prevent the operator pressing both at once** (stalemate → idle).
- An IOField bound to `i16_ActivePalletIdx` shows the current active pallet (1, 2, or 0).
- When `bo_Pallet1Full` or `bo_Pallet2Full` is TRUE, light the corresponding alarm lamp
  AND visually disable that pallet's button until the operator swaps (presses the other side,
  which auto-clears the full bit so the pallet can be re-used after physical emptying).

### 3.3 Per-pallet status / alarm screen

For each pallet, display:

- Recipe name (`recipeN.sName`).
- Validation status (`bo_PatternValidN` lamp / `bo_PatternErrorN` alarm).
- Computed grid (`i16_ComputedGridColsXN` × `_YN` = `i16_ComputedBoxCountN`).
- Full alarm (`bo_PalletNFull`).

## 4. Mutex / completion semantics (precise, V3.0)

`FB_PatternAutoGen` V3.0 each scan, in order:

1. **Validates both recipes** independently.
2. **Computes `i16_ActivePalletIdx`** (live operator state):
   - `ExecutePallet1 AND NOT ExecutePallet2 AND NOT Pallet1Full` → 1
   - `ExecutePallet2 AND NOT ExecutePallet1 AND NOT Pallet2Full` → 2
   - anything else (idle / both pressed / active-side full) → 0
3. **Clears `bo_PalletNFull`** if either:
   - the OPPOSITE side's button is held + this side's button released (WanErXin swap-clear),
     OR
   - `bo_AckPalletNFull` is held TRUE (V3.0 explicit operator reset).
4. **WriteActiveConfig:** if active pallet's recipe is valid, writes its config into
   `GDB_PalletizingCmd`. Otherwise leaves `GDB_PalletizingCmd` at its previous state.
5. **TrackCycleStart (V3.0):** on rising edge of `GDB_PalletizingCmd.bo_InitPallet`,
   snapshot the current `tempActiveIdx` into `statCyclePalletIdx`. This pins which pallet
   the in-flight cycle is building (the Module-C builder locks `aCmd[]` from
   `GDB_PalletizingCmd` at the same edge, so they're consistent).
6. **LatchPalletFull (V3.0):** whenever `GDB_PalletizingCmd.bo_PalletDone` is TRUE, latch
   `bo_PalletNFull` for N = `statCyclePalletIdx` (NOT the live `i16_ActivePalletIdx`). If
   `statCyclePalletIdx = 0` (no cycle ever started, or post-MRES), don't latch — orphan
   `bo_PalletDone` is ignored.
7. **ComputeAggregate (V3.0):** `bo_BothPalletsFull := bo_Pallet1Full AND bo_Pallet2Full`.

## 5. Cap — per-pallet box count ≤ 22 (each cycle builds ONE pallet at a time)

Same ceiling as Module D. Each pallet's `LayerCount × Cols × Rows ≤ 22` (derived from
`GDB_PalletizingPath.aCmd[1..200]` and the 9-cmds-per-box pattern). Per-pallet
`bo_PatternErrorN` for over-ceiling recipes.

## 6. What is NOT in Module E

- **WebEditor** (custom per-box patterns) — still deferred. `GDB_CustomPattern` would be a
  separate DB, used parallel to the auto-gen path.
- **Auto-switch** when a pallet fills — Phase 2 plan said auto, but the WanErXin reference
  is operator-driven and you steered to the WanErXin pattern. If you later want auto-switch,
  it's a small addition to `FB_PatternAutoGen` (on `bo_PalletDone` edge, swap the operator
  flags programmatically).
- **`bo_AllPalletsDone`** — by WanErXin design.
- **Per-pallet alarm TON (5-sec)** — the WanErXin reference has a 5-sec TON for alarm
  display. Not added here; the HMI can blink its alarm lamp instead, or this can be a small
  follow-up if you want the timer in the PLC.

## 7. Verification

1. **Operator deploy:** VCI-sync → compile → MRES → download. `MRES` is recommended — the
   `GDB_ActiveRecipe` shape changed (single `recipe` → two `recipe1`/`recipe2`), so a fresh
   init is the cleanest start.
2. **PLCSIM-Adv smoke** (instance `DemoScara_ABCDE`):
   - **Pallet 1 regression** — defaults: `bo_ExecutePallet1 := TRUE`, `bo_ExecutePallet2 := FALSE`.
     `recipe1` default StartValues → auto-grid 2×2 → 16 boxes; cycle runs clean.
   - **Pallet switch** — write `recipe2` with a different recipe (e.g. layers 2, grid 3×2 →
     12 boxes), set `bo_ExecutePallet2 := TRUE`, `bo_ExecutePallet1 := FALSE`. Confirm
     `i16_ActivePalletIdx = 2`, `GDB_PalletizingCmd` reflects recipe2, cycle runs clean.
   - **Mutex stalemate** — both `bo_ExecutePalletN` TRUE → `i16_ActivePalletIdx = 0`,
     `GDB_PalletizingCmd` unchanged from previous active state.
   - **Idle** — both FALSE → `i16_ActivePalletIdx = 0`.
   - **Full + swap (WanErXin path)** — simulate `GDB_PalletizingCmd.bo_PalletDone` during
     pallet 1 → `bo_Pallet1Full` latches. Operator releases pallet 1's button and presses
     pallet 2's → `bo_Pallet1Full` clears (WanErXin level-driven), `i16_ActivePalletIdx := 2`.
   - **V3.0 — Full + Ack reset (no swap)** — drive `bo_Pallet1Full := TRUE` (or simulate via
     bo_PalletDone), pulse `bo_AckPallet1Full := TRUE` for one scan → `bo_Pallet1Full` clears
     immediately, no swap needed. Release Ack, pallet 1 re-armable.
   - **V3.0 — Mid-cycle swap attribution (bug #1 regression test)** — start pallet 1 cycle
     (pulse `bo_InitPallet`), confirm `statCyclePalletIdx = 1`. Mid-cycle: clear
     `bo_ExecutePallet1`, set `bo_ExecutePallet2`. Confirm `i16_ActivePalletIdx = 2` but
     `statCyclePalletIdx` STAYS at 1. Simulate `bo_PalletDone` → `bo_Pallet1Full` latches
     (correct), NOT `bo_Pallet2Full`.
   - **V3.0 — Both released mid-cycle attribution** — start pallet 1 cycle, mid-cycle
     release BOTH operator flags. Confirm `i16_ActivePalletIdx = 0` but `statCyclePalletIdx`
     stays at 1. Simulate `bo_PalletDone` → `bo_Pallet1Full` latches (correct).
   - **V3.0 — Aggregate** — drive both `bo_Pallet1Full` and `bo_Pallet2Full` TRUE → confirm
     `bo_BothPalletsFull = TRUE`. Clear either → confirm aggregate goes FALSE.
3. **HMI-side PSC verification:** two parameter-set authorings, the two-button switch UI,
   per-pallet alarm lamps — scara-HMI's, after this handoff.
