# PM_HANDOFF — 2026-05-23 — scara-PLC Session Recovery (post-PDF-crash briefing)

**Status:** INFORMATIONAL — scara-PM briefing for the next scara-PLC session, after the previous session's conversation context was poisoned by batched PDF reads.

**From:** scara-PM  **To:** next scara-PLC session

---

## 1. Why this handoff exists

The previous scara-PLC session died on 2026-05-23 with a sticky `API Error: a document in the conversation could not be processed and was removed` after **batch-reading 5 WanErXin reference PDFs** in one tool call (`FB_Pallet_Station_Manager.pdf`, `码垛判断.pdf`, `Palletizer.pdf`, `Main_wex.pdf`, `HMI变量.pdf`). The Anthropic API removed one document but left it referenced in conversation context → every subsequent API call repeated the same error → session unrecoverable.

**The agent had already finished Modules D / E / F before the crash.** It was reading the WanErXin reference PDFs to research **Module G (NX-MCD 联仿)** — the next step — when the context died. All code is on disk, all handoffs written, all smoke green.

## 2. What's done (all code on disk, all handoffs written, all smoke green)

| Item | Status | Handoff | Smoke |
|---|---|---|---|
| Phase 1 close (R5 / R6 + ABCDE retire) | ✅ VERIFIED | `PLC_HANDOFF_2026-05-22_R6_PauseStep.md` | mid-move halt + resume |
| Module D — Recipe (PSC-bound) | ✅ 14/14 PASS | `PLC_HANDOFF_2026-05-23_ModuleD_Recipe.md` | superseded by E shape, code intact |
| Module E V3.0 — Dual-Pallet (WanErXin-driven) | ✅ 27/27 PASS | `PLC_HANDOFF_2026-05-23_ModuleE_DualPallet.md` | 11 sections incl. WanErXin-review bug-fix regression |
| Module F V1.2 — Teach (4th mutex mode) | ✅ 24/24 PASS | `PLC_HANDOFF_2026-05-23_ModuleF_Teach.md` | TCP + joint capture, V1.2 jogframe-override fix |

**Binding map sections:** §8 (R6) · §9 **DEPRECATED** (Module D shape replaced by E) · §10 (Module D + E combined, authoritative) · §11 (Module F).

**Files on disk (all complete, verified by PM at recovery time):**

- `PLC_1/PLC data types/UDT_Recipe.xml`
- `PLC_1/Program blocks/700_Palletizing/{GDB_ActiveRecipe, GDB_PalletizingCmd (moved from 500_), GDB_PalletizingPath (moved from 500_), FB_PatternAutoGen V3.0}`
- `PLC_1/Program blocks/750_Teach/{FB_TeachCtrl V1.2, GDB_TeachCmd, GDB_TeachPoints}`
- `PLC_1/Program blocks/instances/{instFB_PatternAutoGen, instFB_TeachCtrl}` + updated R5/R6 instance DBs
- `FB_AutoCtrl_ABCDE.scl` + iDB DELETED (Module 0 retirement; `FB_AutoCtrl_5Pts.scl` is the only 5-point FB)
- `VCI_EXPORT_RUNBOOK.md` + `900_TIALib/README_EXPORT.md` (export workflow docs)

## 3. What's next — Module G (NX-MCD 联仿)

The PLC side of `Phase2计划_杨子楠.md` §3.1 (传送带 + 生箱) and §3.2 (精细码垛 V5–V9 真实抓放) is functionally ready in 幻影 mode (PLCSIM phantom), but **physical V2–V9 acceptance requires the NX-MCD 联仿 environment**. That's Module G — the dying agent was researching the WanErXin pattern for it.

Pre-requisites (operator-owned):

- **NX 吸盘 attach bug (scoreboard B.19)** needs NX-side fix before V5 / V6 真实抓放 can verify
- **Operator deploy of the current working tree** (now committed by PM, see `git log`): VCI 同步 → 编译 → MRES → 下载 to PLCSIM-Adv before any further smoke

## 4. Phase 2 plan status (authoritative)

See `Phase2计划_杨子楠.md` — operator hand-annotated 2026-05-23 with full detail. Summary:

| § | Item | Status |
|---|---|---|
| §3.1 | 传送带 + 生箱 | 🚧 部分完成 — FB 就绪,V2–V4 物理验收待 NX 联仿(Module G) |
| §3.2 | 精细码垛 | 🚧 部分完成 — 16-box 幻影 PLCSIM 冒烟绿,V5–V9 真实抓放待 NX(Module G + B.19) |
| §3.3 | 参数化 FB | ✅ 已完成(随 §3.4 一并:Module D 把 10 个 config 字段全部 recipe 注入) |
| §3.4 | 配方设定 | ✅ Module D 14/14 PASS + Module E 27/27 验证双配方切换 |
| §3.5 | 双托盘切换 | ✅ Module E V3.0 27/27 PASS(WanErXin 模式 + 3 个 bug 修复) |
| §3.6 | 示教功能 | ✅ Module F V1.2 24/24 PASS(4 模式互斥 + TCP+关节捕获 + jogframe 修复) |

**HMI 侧未做(scara-HMI agent 的下一步):** 配方 PSC 画面(V12) · 双托盘按钮 + 满垛灯 + Ack 复位(§10.6) · 示教点表画面 + 4 模式互斥单选(§11)。三份 PLC handoff 已下发。

## 5. New session — startup sequence

Read in this order, **one file at a time, NO PDF BATCHING**:

1. `AGENT_BOOTSTRAP_PLC.md` — your role, lane, edit boundaries
2. `AGENT_CONTRACT.md` — 3-agent split
3. `PM_Workspace/SCOREBOARD_PLC.md` — current task state
4. **This file**
5. `Phase2计划_杨子楠.md` — operator-authoritative annotated progress
6. `PLC_HANDOFF_2026-05-22_R6_PauseStep.md` → `PLC_HANDOFF_2026-05-23_ModuleD_Recipe.md` → `PLC_HANDOFF_2026-05-23_ModuleE_DualPallet.md` → `PLC_HANDOFF_2026-05-23_ModuleF_Teach.md` (chronological)
7. `C:\Users\Admin\.claude\plans\replicated-forging-flamingo.md` — Phase 2 plan
8. `git log --oneline -10` + `git status` — verify clean working tree

After reading, propose to operator: **Module G plan** — NX-MCD 联仿 scenarios + physical V2–V9 verification once NX 吸盘 bug fixed.

## 6. Strict rules (root-cause of this incident)

**NO PDF BATCHING.** Reading multiple PDFs in one tool call exceeds Anthropic's per-request document/page limit. When the API rejects, the broken document stays referenced in conversation context → every subsequent call fails → session unrecoverable. Code on disk survives; the agent's ability to continue does not.

Rules:

- **One PDF per `Read` call.** Use `get_pdf_info` first to check page count.
- **PDFs > 30 pages → split** via the `pages` parameter (e.g. `pages: "1-25"`, then `pages: "26-50"`).
- **Prefer `.md` handoffs** in `VCIExportedContents/` over reference-project PDFs whenever a handoff covers the topic — handoffs are pre-digested.
- **Reference-project PDFs** (`WanErXin_*`, `LSKI_*`, etc.) — read only the SPECIFIC block named in your task. No exploratory "read everything to see what's there".
- **Multiple reference docs** — spread across separate messages, never batched in one tool call.

## 7. Cross-references

- Plan: `C:\Users\Admin\.claude\plans\replicated-forging-flamingo.md` (Phase 2, Modules D + E + F)
- Authoritative module handoffs: R6 / ModuleD / ModuleE / ModuleF (all in `VCIExportedContents/`)
- Binding map: `VCIExportedContents/HMI_BINDING_MAP.md` §8 + §10 + §11 (§9 DEPRECATED)
- Phase 2 plan (operator-annotated): `VCIExportedContents/Phase2计划_杨子楠.md`

---

_End of PM_HANDOFF_2026-05-23_scaraPLC_SessionRecovery.md_
