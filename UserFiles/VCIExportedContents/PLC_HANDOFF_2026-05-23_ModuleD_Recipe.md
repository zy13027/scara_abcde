# PLC_HANDOFF — 2026-05-23 — Module D: Recipe-driven box sizes (PSC binding)

**Status:** PENDING_VERIFICATION — Module D PLC code authored (`UDT_Recipe`, `GDB_ActiveRecipe`, `FB_PatternAutoGen` + instance DB, `Main.scl` wiring, `GDB_PalletizingCmd` comment refresh). Operator deploy + PLCSIM-Adv smoke pending.

**From:** scara-PLC  **To:** scara-HMI
**Plan:** `C:\Users\Admin\.claude\plans\replicated-forging-flamingo.md` (SCARA Phase 2 Module D)
**Authoritative binding contract:** `HMI_BINDING_MAP.md` Section 9

---

## 1. What Module D is

A recipe layer for the palletizing cycle. The operator picks a box-product recipe;
`FB_PatternAutoGen` (a new OB1 FB) auto-fits a one-block rectangular grid from the recipe's
product + pallet-base dimensions and writes the result into `GDB_PalletizingCmd`'s Module-C
config members each scan. The existing `FB_AutoCtrl_Palletizing` builder is **untouched** —
it reads the same `GDB_PalletizingCmd` members it always has; Module D just supplies them
from a recipe instead of from hand-tuned StartValues.

Architecture (the operator workflow's PLC slice):

- **WinCC Unified Parameter Set Control (PSC)** holds the recipe LIBRARY on the HMI panel
  (SD / USB). PSC binds member-for-member to `GDB_ActiveRecipe.recipe.*`.
- **PLC** keeps exactly ONE slot (`GDB_ActiveRecipe`) — the active recipe.
- Per the operator workflow: the active recipe in the PLC is sourced from HMI storage; the
  operator writes the loaded recipe to the PLC's active-recipe DB (with confirmation), and
  can read the current active recipe back — both are PSC actions on the HMI side.

## 2. HMI action — author Parameter Set Control + screens

### 2.1 Parameter Set Control

Author a Parameter Set Control whose parameter sets are box-product recipes, bound to
`GDB_ActiveRecipe.recipe.*` member-for-member (the full list lives in
`HMI_BINDING_MAP.md` Section 9.1). The library lives on the HMI panel storage (SD / USB).

### 2.2 Mandatory `bo_Valid` handshake (closes the mid-write race)

PSC MUST write `recipe.bo_Valid := FALSE` **before** transferring a parameter set and
`:= TRUE` only **after** every other recipe member has been written. `FB_PatternAutoGen`
consumes the recipe only while `bo_Valid` is TRUE — this prevents the FB from reading a
half-written recipe (the v9 `FB_RecipeAdapter` has no such handshake and is bitten by
exactly this race; Module D fixes it).

Recommended PSC write sequence:

1. `recipe.bo_Valid := FALSE`
2. Write all `recipe.product.*`, `recipe.pallet.*`, `recipe.dynamics.*`, and `recipe.sName`
3. `recipe.bo_Valid := TRUE`

### 2.3 Confirm-before-overwrite dialog (workflow step 5)

When the operator triggers PSC's "Load to PLC" action (or a wrapping "Write to PLC" button),
present a confirmation dialog ("Overwrite the active recipe in the PLC?") — only proceed on
Yes. This is the workflow's confirmation-on-write requirement.

### 2.4 Recipe parameter / overview screen

A screen displaying the active recipe (name + product + pallet + dynamics) for review, plus
the status echoes (`bo_PatternValid`, `bo_PatternError`, `i16_ComputedGridColsX` / `RowsY` /
`BoxCount`). The status echoes give the operator immediate feedback that the loaded recipe
is accepted (or rejected, with the computed values showing why).

## 3. Value-semantics change — `GDB_PalletizingCmd` config members are recipe-driven

The 10 Module-C config members on `GDB_PalletizingCmd` (`i16_LayerCount`, `i16_GridColsX`,
`i16_GridRowsY`, `lr_BoxPitchX`, `lr_BoxPitchY`, `lr_BoxHeight`, `lr_MoveVelocity`,
`lr_MoveAccel`, `lr_MoveDecel`, `lr_MoveJerk`) are now **sole-written by `FB_PatternAutoGen`
each scan**. The HMI must NOT write these directly any more — write the recipe instead; the
FB mirrors it into the config. An IOField bound to one of these is OK for *display*, but a
write would be overwritten on the next OB1 scan. The `GDB_PalletizingCmd` member comments
document this.

## 4. Cap — recipe box count ≤ 22

`FB_PatternAutoGen` validates that the auto-computed box count
(`LayerCount × ComputedCols × ComputedRows`) does not exceed the `GDB_PalletizingPath.aCmd[1..200]`
ceiling of 22 boxes (= `(200 − 1) DIV 9`, the Module-C builder's commands-per-box rate).
Over-ceiling recipes are rejected (`bo_PatternError := TRUE`, config stays at safe defaults).
The HMI may optionally warn the operator pre-write by computing the same fit math.

## 5. What's deferred (NOT in Module D)

- **WebEditor** for custom non-grid per-box patterns — embedded in a Unified Web Control
  widget (no border / header), reading/writing a SEPARATE DB (e.g. `GDB_CustomPattern`) via
  the S7 Webserver API. Out of Module D. `GDB_ActiveRecipe` is symbolically reachable via the
  S7 Webserver API by default, so the WebEditor add-on architecture remains open.
- **Per-layer pattern variation** — Module D is tower mode (all layers use the same auto-gen
  grid). Per-layer different patterns arrive with the WebEditor + a layer-sequence DB in a
  future module.
- **Recipe library on PLC side** — none; the library lives entirely HMI-side via PSC.

## 6. Verification

1. **Operator deploy:** VCI-sync → compile → MRES → download.
2. **PLCSIM-Adv smoke** (instance `DemoScara_ABCDE`):
   - Regression: with `GDB_ActiveRecipe` at default StartValues (`BaseLength` 800,
     `BaseWidth` 1200, Length/Width/Height 400/600/200, Gap 0, LayerCount 4, dynamics
     2000/10000/10000/100000), auto-grid = 2×2 → 16 boxes; the palletizing cycle runs the
     same 16-box 4×(2×2) path as the tasks-#5/#8 smoke. Clean end-to-end.
   - Recipe switch: write `LayerCount 2`, Grid via `BaseLength 1200 / BaseWidth 800` with
     `Length/Width 400` → auto-grid 3×2, total 12 boxes; pulse `bo_InitPallet`; the builder
     computes `i16_TotalBoxes` = 12 and the cycle runs the new pattern clean.
   - Invalid-recipe gate: (a) `bo_Valid := FALSE`; (b) over-ceiling recipe; (c) zero dim →
     each must set `bo_PatternError := TRUE` and leave `GDB_PalletizingCmd` at safe defaults.
3. **HMI-side PSC verification:** parameter-set authoring, panel load/save, the `bo_Valid`
   handshake — scara-HMI's, after this handoff.

Module D PLC side is verifiable **without** the HMI — the PLCSIM-Adv harness drives
`GDB_ActiveRecipe` directly. The PSC screen is a separate scara-HMI deliverable.
