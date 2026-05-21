**Status:** INFORMATIONAL → scara-PLC + scara-HMI. **Mandatory read on every fresh session bootstrap** (read after `AGENT_BOOTSTRAP_PLC.md` / `AGENT_BOOTSTRAP_HMI.md`).

# PM Directive — No Cross-Tree Writing (scara-* identities → SCARA tree only)

**Project:** `hmiDemoSCARA_ABCDE`
**Date:** 2026-05-19
**Authored by:** scara-PM
**Audience:** scara-PLC + scara-HMI (both must adopt)
**Triggered by:** Operator observation 2026-05-19 — 4 SCARA-target HMI Cycle 7.{1,3,4,5} handoffs landed in v9 tree on 2026-05-18 despite catch-up #1's earlier cleanup. Same pattern recurring.

---

## §1 The rule (one line)

**Author handoff files in the project tree of the TIA target. If the handoff's `TIA target =` line points at `hmiDemoSCARA_ABCDE.ap20`, the file lives in `E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/`. Period. No exceptions. v9 tree is READ-ONLY for scara-* identities (per cross-team protocol established 2026-05-17).**

---

## §2 The mistake pattern (recognize it)

Legacy AGENT_CONTRACT §4.4 (2026-05-07 era, single-project days) said "v9 = canonical comm tree". When the project split into two teams on 2026-05-17 (scara-PM/PLC/HMI + v9-PM/PLC/HMI), the cross-team protocol superseded §4.4: **TIA target = canonical project boundary**.

But the muscle-memory remains: when scara-* identities need to "publish a cross-agent handoff", they default to `v9/UserFiles/VCIExportedContents/` as if it were still the shared comm tree. **It isn't.** Each project has its own comm tree.

Symptoms of the drift:
- File path in your `Write` tool contains `hmiDemoMomoryCapacity_v9` even though your identity is scara-*
- You're authoring a handoff whose `TIA target` line points at SCARA but you're writing it to v9 tree
- You skipped re-reading `AGENT_BOOTSTRAP_PLC.md` / `AGENT_BOOTSTRAP_HMI.md` this session

---

## §3 Pre-write checklist (run mentally before every handoff `Write` AND before every chat-message signoff)

Four questions, in order:

1. **What's my agent identity?** Check the AGENT_BOOTSTRAP you're operating under. If it says scara-PLC or scara-HMI → SCARA tree. If v9-PLC / v9-HMI → v9 tree.
2. **What's the handoff's TIA target?** Open the header table you're about to write. Find the `TIA target = ` row. The .ap20 filename determines the project boundary.
3. **Does my write path match?** Concretely:
   - scara-* identity + `hmiDemoSCARA_ABCDE.ap20` target → write to `E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/`
   - scara-* identity + `hmiDemoMomoryCapacity_v9.ap20` target → **STOP**. You're authoring v9 work; that's v9-PLC / v9-HMI's lane. Hand off to operator for v9 agent dispatch.
4. **Does my chat signoff identity match my bootstrap identity?** If your bootstrap says `scara-PLC`, your chat replies end with `scara-PLC standing by.` (or equivalent). Never sign off as `v9-PM`, `v9-PLC`, `scara-PM`, or any identity that isn't yours. **Identity drift in signoff is the same root-cause class as cross-tree write drift** — legacy single-agent muscle memory from the pre-2026-05-17 split. Observed in the wild on 2026-05-19 (scara-PLC's PointTeaching session signed off as `v9-PM standing by`). Catch yourself; re-read this bootstrap; correct next signoff.

If any answer mismatches, **DO NOT WRITE / DO NOT SIGN OFF**. Stop and ask scara-PM in chat.

---

## §4 What scara-PM moved this cycle (2026-05-19)

4 SCARA-target HMI handoffs were found in v9 tree, dated 2026-05-18. All explicitly say `TIA target = hmiDemoSCARA_ABCDE.ap20` in their header table. Moved to SCARA tree (filesystem move; v9 has no git at this path, so zero commit history concerns):

| File | Subject | Status row |
|---|---|---|
| `HMI_HANDOFF_2026-05-18_Cycle7_1_BackColorTagMappingAndPlcQA.md` | BackColor tag-mapping + 4 PLC Q&A answers | ACKNOWLEDGED |
| `HMI_HANDOFF_2026-05-18_Cycle7_3_PhaseGUnblockComplete.md` | 53 UBP Manual widget rebind to GDB_ManualCmd/Status (Phase G unblock) | (per file) |
| `HMI_HANDOFF_2026-05-18_Cycle7_4_Canvas1280x800Correction.md` | Canvas-size correction (despite name, target is MTP1000 SCARA) | (per file) |
| `HMI_HANDOFF_2026-05-18_Cycle7_5_PalletScreen_C71_FacadeAdoption.md` | Palletizing screen adopting C71 HMI Status Facade | (per file) |

**Not moved** (correctly placed): `HMI_HANDOFF_2026-05-18_Cycle7_2_C65RebindAbsorption.md` — its `Project:` line says `hmiDemoMomoryCapacity_v9 (v9 main HMI)`. v9-targeted; stays in v9 tree.

Authoring identity ambiguous from file content alone (could be scara-HMI defaulting to v9 tree out of habit, OR v9-HMI authoring SCARA-target work). The directive is **dual-audience**: scara-HMI corrects own habit; v9-HMI's mirrored discipline is v9-PM's lane (operator dispatches separately).

---

## §5 What to do if YOU find a misplaced handoff

Don't panic. The fix is mechanical:

1. **Verify the TIA target line** — `grep "TIA target" <file>` or read header table. Confirm where it should belong.
2. **Filesystem move** the file (PowerShell `Move-Item` or `mv`). Bodies are immutable per AGENT_CONTRACT §11 — never edit them during the move.
3. **Do NOT cross-post** (don't leave copies in both trees; don't add stub files like "MOVED_TO_SCARA.md" in the source tree).
4. **Surface to scara-PM** in chat: "Found `<file>` misplaced in `<tree>`; moved to `<target tree>`." scara-PM absorbs into next LEDGER row.

If the file is git-tracked in the source tree, escalate to scara-PM before moving — git history rewriting may be needed and that's a PM-coordinated decision.

---

## §6 Out of scope (carried forward)

- **v9 agents writing SCARA-target files in v9 tree.** Likely concurrent problem (v9-HMI may be the actual author of the 4 moved files above, given their predecessor links to v9 PLC handoffs). v9 discipline is v9-PM's lane; scara-PM cannot write v9 tree. Operator may dispatch a parallel directive via a v9-PM session.
- **2 historical 2026-04-30 SCARA-related handoffs** still in v9 tree (`HMI_HANDOFF_2026-04-30_ScaraPathMonitorProposal.md` + `PLC_HANDOFF_2026-04-30_ScaraPathMonitorAck.md`). These predate the scara-* identity split (authored under "v9 = canonical comm tree" convention). Leaving as historical artifacts — their predecessor chain is v9-side, so move would orphan context. Not a discipline failure of any current agent.
- **AGENT_CONTRACT.md adaptation** (the heavier B.8 task — substitute paths, drop §1.1/§4.4 worktree-split sections, add §13 cross-team protocol). Still pending. This directive is the practical reinforcement until B.8 lands.

---

## §7 Closure

This directive joins SCARA tree's permanent rotation alongside `AGENT_BOOTSTRAP_PLC.md` + `AGENT_BOOTSTRAP_HMI.md`. Both bootstraps now carry a `> **CROSS-TREE WRITING IS BANNED.**` warning box pointing back here.

Re-read at the start of every fresh session. If you've internalized §3's 3-question checklist, you'll never trip on this again.

---

_End of PM_DIRECTIVE_2026-05-19_NoCrossTreeWriting.md_
