# PLC Scoreboard — hmiDemoSCARA_ABCDE

**Project:** SCARA ABCDE 5-point auto cycle (minimal rebuild from hmiDemoMomoryCapacity_v9)
**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`
**Source spec:** `UserFiles/VCIExportedContents/杨子楠5月17日周计划.md` (cross-mounted reference)
**Last updated:** 2026-05-21 (PM bookkeeping catch-up #3 partial — palletizing V4.2 buffered-path + suction-cup capture blocker + ABCDE/HMI auto-control verified; `PLC_HANDOFF_2026-05-21` authored)
**Last action:** Authored `PLC_HANDOFF_2026-05-21_PalletizingV4_SuctionCupBlocker_AbcdeHmiVerified.md`. Palletizing FB rewritten V3.0→V4.2 buffered-path (+GDB_PalletizingPath, UDT_PathCmd, FB_ConveyorCtrl); smoke reported 16/16 cycle-counter both modes. **Open blocker:** suction-cup capture fails — NX `Suction_Cup_Gripper` won't attach the box (PLC verified vs LSKI ref); demo non-functional until NX fix. ABCDE "Auto"+HMI co-sim drive verified; button→status-tag map handed to scara-HMI. Catch-up #3 commit still deferred (no SCARA git remote).

---

## Status legend

| Icon | Meaning |
|---|---|
| 🆕 | New ask this session — not yet started |
| 🚧 | In progress |
| ✅ | Done (kept on board ≤ 5 cycles for context) |
| ⏸️ | Blocked / waiting on operator or other agent |
| 🔴 | Critical / failing |

---

## A. Manual-by-USER (TIA Portal UI operations, not Openness-scriptable)

| # | Task | Source / Status |
|---|---|---|
| A.1 | TIA Portal: File → New → TIA Project V20 named `hmiDemoSCARA_ABCDE` at `E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/` | ✅ Confirmed (commit `79cae9a` baseline) |
| A.2 | Add Device 1: PLC_1 = S7-1511T-1 PN at firmware V4.0 (fall back to V3.0 if V4.0 not in TIA V20 catalog) | ✅ Confirmed (`.ap20` has PLC_1 device) |
| A.3 | Add Device 2: HMI_1 = MTP1000 Unified Basic Panel 10" (6AV2123-3KB32-0AW0) | ✅ Confirmed (HMI Cycle 7_0 authored 14 UBP screens on HMI_1) |
| A.4 | PROFINET network: link PLC ↔ HMI | ✅ Confirmed (HMI tags bind to PLC via S7 connection) |
| A.5 | Import 5 TO XMLs via TIA → Add Technology Object → "From existing XML": J1-J4_SCARA_Arm3D + ScaraArm3D from `UserFiles/VCIExportedContents/PLC_1/Technology objects/` | ✅ Confirmed (TOs operational per Phase D + Phase F V8 + Phase C V6 smoke results) |
| A.6 | TIA Portal: import 9 SCL/XML source files into Program blocks via Openness or External Sources: Main.scl + Startup.scl + GDB_Control.xml + GDB_MachineCmd.xml + FB_AxisCtrl.scl + FB_AutoCtrl_ABCDE.scl + FB_MCDDataTransfer.scl + GDB_MCDData.xml + UDT_typePoint5.xml | ✅ Confirmed (commit `79cae9a` VCI fix) |
| A.7 | TIA Portal: HMI screen authoring (4 screens per UBP 5-control cap) | ✅ Confirmed — DUAL PATH: (a) operator manual specs at HMI_1/Screens/*.md for direct authoring; (b) HMI agent Cycle 7_0 programmatic — 14 UBP screens authored + TIA Compile 0E/0W |
| A.8 | TIA Portal: compile entire project → expect 0W/0E | ✅ Confirmed (PLC 0W/0E pre-Phase-D + HMI Cycle 7_0 Phase E 0E/0W) |
| A.9 | TIA Portal: download to PLCSIM-Adv instance `1511T_ABCDE` at 192.168.0.5 (NOT plan's prior .40 placeholder) | ✅ Confirmed (Phase D + F V8 + C V6 all PASS via PLCSIM @ .5) |
| A.10 | Operator runtime smoke: V1–V7 + V9 + V-OB91 (10 sub-tasks per plan Phase D) | ✅ V1-V9 all PASS — V1✅ V2✅ V3✅ V4✅ V5✅ V6✅ **V7✅** (operator visual 2026-05-18 ~15:18 on Phase E run #6) V8✅ V9✅. V-OB91 ℹ️ inferred from 60 wraps × 540s Phase E streaming with ZERO errors (manual TIA Diag Buffer confirmation optional). |

## B. Claude-Code-PM-tasks (PM agent owned)

| # | Task | Source / Status |
|---|---|---|
| B.1 | Author + back up prior 11-state+LKinCtrl work + rewrite to 6-state+no-libraries per approved plan | ✅ 2026-05-17 |
| B.2 | Bootstrap PM_Workspace + PROJECT_STATUS.md + HMI_BINDING_MAP.md | ✅ 2026-05-17 (PROJECT_STATUS comprehensively populated through Phase C; HMI_BINDING_MAP §5+§6 has UBP family + diagnostic mirror rows) |
| B.3 | Author OPERATOR_PHASE_A_HANDOFF.md describing TIA Portal manual UI steps for operator | ✅ 2026-05-17 (in tree, plus follow-on OPERATOR_PHASE_C_HANDOFF.md + OPERATOR_PHASE_F_HANDOFF.md) |
| B.4 | Git init + initial commit establishing baseline | ✅ 2026-05-17 (3 commits on master: `79cae9a` + `d20319a` + `c2d4f86`) |
| B.5 | Once operator completes Phase A: write follow-up handoff confirming TO import + 0W/0E compile result | ✅ 2026-05-17 (THIS catch-up handoff PM_HANDOFF_2026-05-17_PhaseAtoF_Catchup.md serves as B.5 + B.6 rollup) |
| B.6 | Once operator completes Phase D smoke: write PROJECT_STATUS.md update with V1–V7+V9 results | ✅ V-suite complete — D + F + C V6 + E (V7 visual) + V8 all green; V-OB91 inferred from clean Phase E. PROJECT_STATUS Phase E/G/2.2 rows present (scara-PLC authored; committed this cycle). |
| B.7 | Absorb HMI agent Cycle 7_0 (5 handoffs migrated from v9 tree → SCARA) + scara-PLC C66 PhaseC_HMI_Verified + C66 HMI_ManualMode_TagProposal | ✅ catch-up #1 (2026-05-17) |
| B.8 | Author cross-team coordination protocol amendment to AGENT_CONTRACT.md (currently verbatim copy of v9's; needs SCARA adaptation: substitute paths, drop §1.1/§4.4 worktree-split, add §13 cross-team protocol) | 🆕 deferred (no urgency change; carry-over from catch-up #1) |
| B.9 | Absorb scara-PLC Phase E/G/2.2 work + 6 new handoffs (BackColor, J2J3, C67 PhaseG, C68 PhaseE, C69 Phase 2.2, C70 Pallet HMI) into PM bundle handoff | ✅ This cycle (catch-up #2): `PM_HANDOFF_2026-05-18_Phase1Complete_Phase2Staged.md` |
| B.10 | Surface C70 Palletizing HMI surface + BackColor proposals to scara-HMI when next HMI session activates | 🆕 Surfaced in catch-up #2 §4 [NEEDS_HMI_ACK] × 3; awaits scara-HMI response handoff |
| B.11 | Absorb post-`c8f8af1` activity into a catch-up #3 when co-driver work reaches closure: C69 §11 SW-limit lesson (already in handoff body) + HMI Runtime Co-Driver harness (5 files, no handoff yet) + TO XML revert + PROJECT_STATUS edit | 🚧 In-flight; defer commit until co-driver lands a closure handoff |
| B.12 | ACK v9-PM's C71-v9 mirror enforcement closure handoff + flag SCARA remote-push gap | ✅ This cycle — `PM_HANDOFF_2026-05-19_scaraPM_to_v9PM_CoordinationLoopAck.md` (~95 LOC, `[CLOSES]` cross-tree boundary enforcement). Adds 1 new `[NEEDS_OPERATOR]` (SCARA remote URL/naming). Joins catch-up #3 backlog. |
| B.13 | Author per-agent claim-manifest + move-if-misplaced requests (mirror v9-PM's §5 mechanism) | ✅ Authored 2 PM-to-agent handoffs in `VCIExportedContents/`: `PM_HANDOFF_2026-05-19_scaraPLC_FileClaimRequest.md` (~80 LOC, low effort) + `PM_HANDOFF_2026-05-19_scaraHMI_FileClaimRequest.md` (~120 LOC, higher-priority — names 4 Cycle7_X ⬜ TBD rows for claim/disclaim). Open `[NEEDS_scaraPLC]` + `[NEEDS_scaraHMI]` claim manifest publication, next active session. |
| B.14 | Forensic authorship audit of 4 Cycle7_X files + Cycle7_2 cross-read (PM-side resolution while waiting for scara-HMI session) | ✅ Authored `PM_HANDOFF_2026-05-19_scaraHMI_ForensicAuthorshipAudit.md` (~200 LOC). **Conclusion: all 4 misplaced files = scara-HMI authored** (legacy "v9 = canonical comm tree" drift); Cycle7_2 = v9-HMI correctly placed. **v9-HMI is NOT encroaching.** Resolves `[NEEDS_HMI_ACK]` from catch-up #2 §4; downgrades `[NEEDS_OPERATOR]` parallel v9 directive concern. Awaits scara-HMI 1-line ACK in next session. |
| B.15 | Absorb scara-HMI's claim manifest (landed 2026-05-19 PM session) + cross-mount Cycle 7.2 reverse-drift finding to v9-PM | ✅ scara-HMI's manifest confirmed all 4 ⬜ TBD authorship verdicts AND self-disclosed REVERSE-direction Cycle 7.2 drift (scara-HMI authored v9-target work). scara-HMI also self-moved 3 NEW handoffs today (recovery loop working). scara-PM authored `PM_HANDOFF_2026-05-19_scaraPM_to_v9PM_Cycle72ReverseDrift.md` (~135 LOC) for v9-PM awareness — surfaces ownership question for C65 rebind execution (now v9-HMI's obligation, not scara-HMI's). `[NEEDS_v9PM_v9HMI]` Cycle 7.2 reclamation decision (low urgency); `[NOT_BLOCKING]` catch-up #3. |
| B.16 | scara-PLC formal claim manifest | 🚧 Open `[NEEDS_scaraPLC]` (carry-forward from B.13). Implicit discipline confirmed via today's authoring activity in SCARA tree (2 new PLC handoffs: HMI_Followups + MCDSignalAdditions, both correctly placed). Formal manifest still owed but low priority; carry-forward to next scara-PLC session. |
| B.17 | Identity signoff drift discovered + 3 scara-side discipline edits + cross-mount to v9-PM | ✅ Operator surfaced PLC agent signing off as `v9-PM standing by.` (identity drift — same root cause as cross-tree write drift). Added Q4 "signoff identity check" to `AGENT_BOOTSTRAP_PLC.md` + `AGENT_BOOTSTRAP_HMI.md` ⛔ warning boxes + `PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md` §3 pre-write checklist. Authored `PM_HANDOFF_2026-05-19_scaraPM_to_v9PM_IdentitySignoffDrift.md` (~150 LOC) cross-mount suggesting same 3 mirror edits on v9 side. `[NEEDS_v9PM]` 3 mirror edits low-urgency; `[NOT_BLOCKING]` catch-up #3. |
| B.18 | Absorb 2026-05-20→21 scara-PLC palletizing V4.2 buffered-path rewrite (FB_AutoCtrl_Palletizing V3.0→V4.2 + GDB_PalletizingPath + UDT_PathCmd + FB_ConveyorCtrl + Main OB1 call) | ✅ This cycle — `PLC_HANDOFF_2026-05-21`. Smoke reported 16/16 cycle-counter both modes (BufferMode 16#80B2 fixed). |
| B.19 | Suction-cup capture blocker | 🔴 OPEN — NX `Suction_Cup_Gripper` does not attach `rbContainer_1`; PLC side verified correct vs LSKI ref. `[NEEDS_HUMAN]` NX fix per `dazzling-squishing-sloth.md`. Palletizing demo non-functional until fixed. |
| B.20 | J1 pointless-motion / modulo whip | ⏸️ Operator applied TO fix (J1 modulo off + SW limits J1±160 / J2−1820..+600 / J3±134); one-box real-mode re-test owed. |
| B.21 | ABCDE "Auto" tab + HMI co-sim drive verified; bo_Start/Stop/InitPath=edge, bo_Mode=level; button→status-tag map documented | ✅ This cycle — `[INFO]` in `PLC_HANDOFF_2026-05-21` §4 for scara-HMI cycle-7.7 header strip. |
| B.22 | scara-HMI Cycle 7.6 ABCDE 5/5 re-test (per `HMI_HANDOFF_2026-05-19_Cycle7_6_IssueA_Closed` §5) | 🆕 `[NEEDS_scaraPLC]` carry-forward — not run this session (palletizing priority took precedence). |

## Recently completed

| Date | Cycle | Handoff / Doc | Status |
|---|---|---|---|
| 2026-05-21 | PM catch-up #3 (partial) | `PLC_HANDOFF_2026-05-21_PalletizingV4_SuctionCupBlocker_AbcdeHmiVerified.md` | ⏸️ palletizing blocked on NX suction-cup; ABCDE/HMI drive verified |
| 2026-05-18 | PM catch-up #2 | `PM_HANDOFF_2026-05-18_Phase1Complete_Phase2Staged.md` | ✅ landed; **Phase 1 全 100%** |
| 2026-05-18 | C71 Phase 2.4 HMI Status Facade | `PLC_HANDOFF_2026-05-18_C71_HMIStatusFacade.md` + `hmiStatusFacade_20260518_220300.log` (9/9) | ✅ centralised read-side facade; INFORMATIONAL → scara-HMI for cycle-7.X+ incremental migration |
| 2026-05-18 | C70 Pallet HMI Proposal | `PLC_HANDOFF_2026-05-18_C70_PalletizingHmiSurfaceProposal.md` (scara-PLC) | 🆕 [NEEDS_HMI_ACK] |
| 2026-05-18 | C69 Phase 2.2 Palletizing | `PLC_HANDOFF_2026-05-18_C69_Phase2_PalletizingBackport.md` + `palletizing_20260518_161518.log` (12/12) + 20:53 post-L1 (11/12) | ✅ STAGED_FOR_PHASE_2 |
| 2026-05-18 | C68 Phase E NX MCD | `PLC_HANDOFF_2026-05-18_C68_PhaseE_NxMcdIntegration.md` + 6 runs × 7/7 + V7 operator visual | ✅ **GOAL 3 / Phase 1 CLOSED** |
| 2026-05-18 | C67 Phase G Manual | `PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md` + `phaseG_20260518_124758.log` (16/16) | 🅿️ STAGED_FOR_PHASE_2 |
| 2026-05-18 | C66 follow-ups | `PLC_HANDOFF_2026-05-18_BackColor_TagProposal.md` + `..._J2J3DeliberateMisorder.md` | ℹ️ INFORMATIONAL anchors |
| 2026-05-17 | PM catch-up #1 | `PM_HANDOFF_2026-05-17_PhaseAtoF_Catchup.md` | ✅ landed (commit `8e2468f`) |
| 2026-05-17 | Phase C HMI Verified | `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` (scara-PLC) | ✅ V6 8/8 PASS, Goal 2 DONE |
| 2026-05-17 | Phase G Proposal | `PLC_HANDOFF_2026-05-17_C66_HMI_ManualMode_TagProposal.md` (scara-PLC) | 🚧 [NEEDS_HMI_ACK] 6 open questions |
| 2026-05-17 | HMI Cycle 7_0 Phase A→E | 5 handoffs migrated from v9 tree → SCARA tree | ✅ source compile-green (TIA HMI 0E/0W) |
| 2026-05-17 | Phase F V8 | `phaseF_V8_20260517_182059.log` (commit `c2d4f86`) | ✅ 5/5 V8 PASS |
| 2026-05-17 | Phase D | `phaseD_20260517_180109.log` (commit `d20319a`) | ✅ 9/9 PASS |
| 2026-05-17 | Initial bootstrap | `OPERATOR_PHASE_A_HANDOFF.md` | ✅ Phase A→F all executed |

---

## Refresh model

Bump the **Last updated** + **Last action** lines on every cycle. Move newly-completed items into Recently completed table (top row), mark with ✅ in their original section (keep visible for ≤ 5 cycles). New asks surface as 🆕 in section A or B.

---

## File-mediated coordination notes

**UPDATE 2026-05-17:** SCARA project now has its OWN HMI agent (scara-HMI) — separate identity from v9-HMI. scara-HMI authored 14 UBP screens on `hmiDemoSCARA_ABCDE.ap20` HMI_1 via Cycle 7_0 (Phases A→E) using C# Openness builders in `E:\VS_Code_Proj\TiaUnifiedAuto\Builders\Ubp\` (cross-mounted to both projects). Per the cross-team protocol in bootstrap brief:

- **scara team:** scara-PM (me) + scara-PLC + scara-HMI — all 3 identities work on SCARA_ABCDE
- **v9 team:** v9-PM + v9-PLC + v9-HMI — independent identities, work on v9 + v10 sibling
- **Operator interfaces with both teams in parallel sessions**
- Cross-citations use relative paths; never cross-post handoff files
- If a handoff lands in wrong tree, filesystem-move (no commit history rewriting since untracked)

Handoff convention follows v9's `plc-hmi-handoff-cycle` skill conventions, with these SCARA-specific deltas:
- Single-branch `master` (NOT v9's plc/* + pm/* worktree split)
- Phase A/B/C/D/E/F lifecycle naming (NOT v9's C1-C66 numeric)
- Cycle numeric (e.g., "C66") allowed for sub-phase tagging when scara-PLC borrows v9 pattern, but PM tracker uses Phase lifecycle

Cross-team handoffs (scara ↔ v9): rare. Default cross-citation pattern is relative-path link in handoff narrative.
