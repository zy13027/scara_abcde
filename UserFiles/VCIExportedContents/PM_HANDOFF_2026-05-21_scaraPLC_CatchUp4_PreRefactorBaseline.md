**Status:** INFORMATIONAL → scara-PLC. Catch-up #4 baseline `a36f789` committed + pushed to `origin/main`. Phase-1 folder re-architecture applied locally (`8fdae36`+`2b88a7d`, not yet pushed). **Action expected from scara-PLC:** code-level layered refactor R1–R6 per the 2026-05-21 TIA review (multi-session). **[NEEDS_OPERATOR]:** LKinCtrl library awaits 郑磊 approval before any hard dependency.

# scara-PM → scara-PLC — Catch-up #4 Pre-Refactor Baseline + 2026-05-21 Layered-Refactor Brief

**From:** scara-PM
**To:** scara-PLC
**Date:** 2026-05-21
**Subject commit:** `a36f789` — "PM catch-up #4: VCI re-export + LKinCtrl import + consolidated UDTs/GDB_AxisCtrl (pre-refactor baseline)"
**Branch:** `main` — `a36f789` pushed to `origin/main` (`github.com/zy13027/scara_abcde`)
**Pairs with:** [`../PM_Workspace/Meeting_2026-05-21_TIA_Programming_Review.md`](../PM_Workspace/Meeting_2026-05-21_TIA_Programming_Review.md) + [`../PM_Workspace/Meeting_2026-05-21_TIA_Review_Checklist.md`](../PM_Workspace/Meeting_2026-05-21_TIA_Review_Checklist.md)

---

## §1 Why this handoff

Catch-up #4 (`a36f789`) snapshots the PLC project as a **pre-refactor baseline** — a clean, committed, pushed restore point taken right before the layered re-architecture mandated by the 2026-05-21 TIA programming review. This handoff:

1. Records what `a36f789` contains, so scara-PLC has a known-good rollback point.
2. Reports that the **folder re-architecture has already started** (two follow-on commits, local-only).
3. Hands scara-PLC the **code-level refactor checklist** (R1–R6) from the 2026-05-21 review.
4. Flags the one **open decision gate** — LKinCtrl library usage awaits 郑磊 (郑老板) approval.

---

## §2 Commit `a36f789` — what landed (the baseline)

204 files changed, +33273 / −2694. Contents:

- **VCI re-export** — full PLC source re-exported from TIA into `PLC_1/`.
- **LKinCtrl library import** — Siemens L Kinematics Control library snapshot under `900_TIALib/LKinCtrl_Blocks/` (large SCL — e.g. `LKinCtrl_OffsetContour.scl` ~2178 lines, `LKinCtrl_MC_ExecuteKinMotionCmd.scl` ~3413 lines), plus library UDTs under `002_AxisCtrl/`, `004_LKinCtrl/`, `LKinCtrl_Types`, `LKinCtrl_Tags`.
- **Consolidated UDTs + `GDB_AxisCtrl`** — axis-control data structures merged into one place.
- **New folder skeleton** — `000_OB`, `100_HMI_Comm`, `600_AxisCtrl`, `700_Palletizing` introduced.
- **`FB_AutoCtrl_5Pts.scl`** — skeleton added (the standardized 5-point auto FB; CASE body still to be written — see R5).
- **2 meeting docs** committed to `PM_Workspace/`.
- **Deletions** — stale `.backup/` snapshots and old `HMI_1/Screens/` spec markdown removed.

> **PLCSIM-Adv note:** the baseline reshaped UDTs + `GDB_AxisCtrl`, and R1/R2 below will reshape `GDB_Control`. Any re-test against PLCSIM-Adv after a DB-shape change needs the standard **reset memory → recompile → download-all → re-test** sequence — otherwise expect spurious enable/status timeouts.

---

## §3 Folder re-architecture — STARTED (local-only, not pushed)

Two commits after the baseline already applied the **Phase-1 folder moves**:

| Commit | What |
|---|---|
| `8fdae36` | "Phase 1 — folder re-architecture: dedupe + layered numbering" — adds `300_Alarm_IO/.gitkeep` |
| `2b88a7d` | "Phase 1 (apply) — folder dedupe / rename / move" — 12 files, renames + dedupe (−826 lines of duplicates) |

Both are **local-only** — `main` is `[ahead 2]` of `origin/main`; `origin/main` is still at `a36f789`.

**Current `PLC_1/Program blocks/` tree at HEAD (`2b88a7d`):**

```
000_OB/          CyclicInterrupt_10ms.xml, Main.scl, Startup.scl
200_HMI_Comm/    FB_HMIStatusMirror.scl, FB_MCDDataTransfer.scl, GDB_HMI_Status.xml, GDB_MCDData.xml
300_Alarm_IO/    .gitkeep        (reserved — IO / alarm layer, empty)
500_AutoCtrl/    FB_AutoCtrl_5Pts.scl, FB_AutoCtrl_ABCDE.scl, FB_AutoCtrl_Palletizing.scl,
                 FB_ConveyorCtrl.scl, FB_ManualCtrl.scl,
                 GDB_Control.xml          ◄── still here; meeting says move to 600
                 GDB_MachineCmd.xml, GDB_ManualCmd.xml, GDB_ManualStatus.xml,
                 GDB_PalletizingCmd.xml, GDB_PalletizingPath.xml
600_AxisCtrl/    FB_AxisCtrl.scl, GDB_AxisCtrl.xml
700_Palletizing/ FB_MovePath.scl, GDB_MovePath.xml
900_TIALib/      LKinCtrl_Blocks/
instances/       instFB_* (7 iDB XML)
```

✅ **Already done by `8fdae36`+`2b88a7d`** — layered numbering 200/300/500/600/700; the `100_HMI_Comm` + `600_HMI_Comm` duplicate deduped → `200_HMI_Comm`; `FB_AxisCtrl` → `600_AxisCtrl`; `700` created with `FB_MovePath`/`GDB_MovePath` placeholders; `300_Alarm_IO` reserved placeholder; old `100_OB` → `000_OB`.

This matches the meeting's 5-layer target: **200** HMI 通信 / **300** IO·报警 / **500** 工艺逻辑 / **600** 轴控 / **700** 路径库.

---

## §4 The code-level refactor — scara-PLC checklist (R1–R6)

The folders are moved; the **code inside them is not yet refactored**. Per the 2026-05-21 review — 闫磊 (闫老板) mandate: **轴控与工艺逻辑解耦** (decouple axis control from process logic). Remaining for scara-PLC:

| # | Task | Detail | Marker |
|---|---|---|---|
| R1 | `GDB_Control` → 600 | Move `GDB_Control.xml` from `500_AutoCtrl/` to `600_AxisCtrl/`. Master copy lives in 600; delete any 500 duplicate. | `[NEEDS_scaraPLC]` |
| R2 | `GDB_Control` structify + per-axis Enable | Group members by function (Enable / Home / Reset …); put `HomePos`/`HomeMode` under a **Home** struct. **Per-axis Enable** — no single all-axis Bool. Same-function multi-axis → one array/struct. | `[NEEDS_scaraPLC]` |
| R3 | New **`FB_Init`** | Standalone homing / safe-position FB — **not** embedded in the main auto FB. Per-axis homing order + independent home-speed parameter + correct `HomeMode`. | `[NEEDS_scaraPLC]` |
| R4 | `MC_*` / MovePath out of 500 | 500 (工艺逻辑) must **not** call `MC_*` directly. Move motion / `MC_*` / MovePath (`LKinCtrl_MovePath`) calls down into the 600 axis layer; 500 talks to 600 only via `GDB_*` command structs. | `[NEEDS_scaraPLC]` |
| R5 | `FB_AutoCtrl_5Pts` + ABCDE → standard CASE | Implement the standard step model (below) in the `FB_AutoCtrl_5Pts` skeleton; align `FB_AutoCtrl_ABCDE` to it. | `[NEEDS_scaraPLC]` |
| R6 | Add **Pause** step | Step 75 (暂停) — currently unimplemented in the auto sequence. | `[NEEDS_scaraPLC]` |

**Standard CASE step model (王硕 model, from the review):**

| Step | Use |
|---|---|
| 0 | idle / empty step |
| 10 | variable reset (on start / after fault) |
| 20 | equipment start conditions (fans, pumps…) |
| 30–80 | assign / compute **first**, then issue CMD |
| 50 | MovePath / motion command → 600 (this is motion, not homing) |
| 75 | **Pause** (not yet done — R6) |
| 100 | wait motion complete (`|actual − set| < 0.01`; do not over-rely on `Done`) |
| 200 | E-stop jump |
| 230 | cycle end |
| 800–900 | shutdown variable reset |

Principle: prepare + reset at **both head and tail** of the main logic; parameters before CMD.

**Out of scara-PLC lane (for awareness only):** the Excel home-mapping table (当前 Home / 行业 Home, auto vs manual) is operator 杨子楠's; the HMI global Header showing actual + target position is scara-HMI's.

---

## §5 [NEEDS_OPERATOR] — LKinCtrl library approval gate

`a36f789` imported the **L Kinematics Control (LKinCtrl)** library (`900_TIALib/`, plus `002_AxisCtrl/`, `004_LKinCtrl/` UDTs). This **conflicts with the project's standing「不用任何的库」(no third-party libraries) rule**, carried explicitly in both the Phase 2 and Phase 3 plans.

The 2026-05-21 review left this **open** (待确认): **郑磊 (郑老板) must decide whether LKinCtrl is permitted.**

**scara-PLC guidance until the decision lands:**

- Treat the LKinCtrl snapshot as **present-but-provisional**. It is in the baseline so the project compiles, but do **not** build new hard dependencies on LKinCtrl blocks into the R1–R6 refactor code yet.
- Keep `FB_MovePath` / `GDB_MovePath` in `700` as **library-agnostic placeholders** — the path-layer interface (the `GDB_*` command struct that 500 uses to request a move) must stay neutral so the 700 implementation can be either LKinCtrl-backed **or** hand-written, depending on 郑磊's call.
- Operator (杨子楠) owns escalating this to 郑磊 and reporting the decision back into the next cycle.

---

## §6 Suggested sequencing

1. **Operator:** push `8fdae36`+`2b88a7d` so `origin/main` reflects the folder moves before code refactor begins.
2. **R1 → R2** (`GDB_Control` move + structify) — data structure first; it dictates everything downstream.
3. **R3** (`FB_Init`) — independent; can run in parallel with R1/R2.
4. **R4** (`MC_*` out of 500) — depends on R2 (needs the structured `GDB_Control` command interface).
5. **R5 → R6** (CASE model + Pause) — depends on R4; 500 logic is only clean once motion calls are gone.
6. Compile-clean + PLCSIM-Adv re-test after each cluster (reset memory if DB shape changed — R1/R2 will).

Each cluster lands as one catch-up commit ("PM catch-up #5 …", etc.).

---

## §7 Verification

- `git log --oneline` → `a36f789` present and pushed to `origin/main`.
- Baseline rollback: `git checkout a36f789 -- "UserFiles/VCIExportedContents/PLC_1"` restores the pre-refactor PLC source.
- After each refactor cluster: TIA compile = 0 errors; PLCSIM-Adv reset → recompile → download-all → re-test.
- Final architecture check: **no `MC_*` call inside `500_AutoCtrl/*.scl`**; `GDB_Control.xml` exists **only** under `600_AxisCtrl/`.

---

## §8 Closure markers

- `[NEEDS_scaraPLC]` R1–R6 layered code refactor — multi-session, sequence per §6.
- `[NEEDS_OPERATOR]` LKinCtrl approval — operator escalates to 郑磊; blocks any hard LKinCtrl dependency.
- `[NEEDS_OPERATOR]` Push `8fdae36`+`2b88a7d` to `origin/main`.
- `[INFORMATIONAL]` Folder re-architecture (Phase 1) already applied — the code refactor (R1–R6) is the open work.
- `[CARRYFORWARD]` R1–R6 progress → future catch-up commits.

---

## §9 Cross-references

- Review minutes: [`../PM_Workspace/Meeting_2026-05-21_TIA_Programming_Review.md`](../PM_Workspace/Meeting_2026-05-21_TIA_Programming_Review.md)
- Review checklist: [`../PM_Workspace/Meeting_2026-05-21_TIA_Review_Checklist.md`](../PM_Workspace/Meeting_2026-05-21_TIA_Review_Checklist.md)
- Phase 2 plan (Agent 版): [`Phase2计划_MCD联合仿真与精细码垛.md`](Phase2计划_MCD联合仿真与精细码垛.md)
- Phase 3 plan (Agent 版): [`Phase3周计划_Agent版.md`](Phase3周计划_Agent版.md)
- Latest PLC-side state: [`PLC_HANDOFF_2026-05-21_PalletizingV4_SuctionCupBlocker_AbcdeHmiVerified.md`](PLC_HANDOFF_2026-05-21_PalletizingV4_SuctionCupBlocker_AbcdeHmiVerified.md)

---

_End of PM_HANDOFF_2026-05-21_scaraPLC_CatchUp4_PreRefactorBaseline.md_
