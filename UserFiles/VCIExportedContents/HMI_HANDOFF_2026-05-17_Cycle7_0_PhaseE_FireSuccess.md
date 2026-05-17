**Status:** PENDING_VERIFICATION

# HMI → PLC Handoff — 2026-05-17 (Cycle-7.0 Phase E: UBP MTP1000 fire SUCCESS — 7+ screens authored on `hmiDemoSCARA_ABCDE.ap20` HMI_1; runtime smoke remains owed)

> **Predecessor:** [HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseD_UbpManualBuilder.md](HMI_HANDOFF_2026-05-17_Cycle7_0_PhaseD_UbpManualBuilder.md) (Phase D source landed; Phase E fire owed pending operator TIA Openness ACL registration)
>
> **Operator unblock:** Between the Phase A+B+C smoke (19:00, surfaced `EngineeringSecurityException`) and the Phase E live fire (19:53), the operator registered `hmiDemoSCARA_ABCDE.ap20` in TIA → Settings → Openness → Authorized projects/users. Evidence per `ubp_authoring_trace.log`:
> ```
> [2026-05-17T19:53:41.4204695+08:00] candidate pid=112292 project=...hmiDemoSCARA_ABCDE.ap20
> [2026-05-17T19:54:06.3567462+08:00] attached to already-open project
> ```
> ✓ Authorization succeeded.

---

## Header

| Field | Value |
|---|---|
| Cycle date | 2026-05-17 19:53 (Phase E fire) |
| Triggered by | Operator: "Phase E fire now" |
| TIA target | `E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\hmiDemoSCARA_ABCDE.ap20` at HMI_1 (operator-confirmed MTP1000 device class pre-seeded) |
| Fire command | `dotnet run --no-build -- --only=ubp-all` |
| Attach mode | TryAttachToOpenProject (operator had project open in TIA Portal) — `attached to already-open project` ✓ |
| Project saved | `[UBP] Project saved.` ✓ |
| Phases A+B+C+D | ✅ DELIVERED (prior handoffs) |
| **Phase E** | ✅ **FIRE SUCCESS** — UBP family authored on canonical project; all builders fired (Layout host + Auto + Manual + 4× per-axis) |
| Phase F | 🟡 PARTIAL — this handoff + scoreboard + ledger; full ACK pending operator runtime smoke (TIA Runtime / WebRH visual + click on big-font + Siemens-teal + cycle-6.19 INVERT toggle) |
| Status | **PENDING_VERIFICATION** (source-side authoring VERIFIED on canonical project; runtime-side smoke still owes operator confirmation) |

---

## 1. Audit findings

`--only=audit-tags` was fired but uses the EXISTING v10-default audit knob (writes report to `E:\TIA_Project_Directory_V20\hmiDemoMomoryCapacity_v10\tag_audit_report.json`). The audit knob is not parameterized for SCARA_ABCDE target; UBP family is a FRESH project (no v10 baseline applies). The proper Phase E verification is the **implicit per-widget verification in the UBP fire log** itself — every `[IO] ✓`, `[EVENT] ✓`, `[DYN] ✓`, `[SLOT] ✓` line confirms a binding landed on the project.

**Cycle-7.1 candidate**: parameterize `--only=audit-tags` (or add `--only=audit-tags-ubp`) to target `ScaraAbcdeProjectPath`. Out of scope for cycle-7.0.

## 2. Tags authored

`UbpLayoutHostBuilder.EnsureUbpTags()` ran successfully — `Ubp_Local` HMI tag table bootstrapped on HMI_1 with 3 Int tags:

| Tag | Type | Purpose |
|---|---|---|
| `ubpNavSection` | Int | 5-tab bottom-nav selector (0..4 → Home/Auto/Manual/Diag/Config) |
| `ubpPopupIndex` | Int | Modal popup index (Steal #3 — LSKI pattern; reserved for cycle-7.1) |
| `ubpManualTab` | Int | Manual inner-tab selector (0 → Kin, 1 → Axis) |

**No PLC tags created.** All button bindings (IO, JOG, ENABLE, HOME, RESET, STOP) reference the existing `mc_kin_*` + `mc_axis_J{n}_*` PLC tag layer from MotionControlBuilder via fully-qualified tag names. Per-widget `Match=True` read-backs in the fire log confirm tag resolution worked (e.g., `[IO] 'ioAxJ4Vel_Ubp' ProcessValue read-back = 'mc_axis_J4_status_ActualVel' | Match=True`).

## 3. Manual-wiring follow-ups

Carried-forward from prior handoffs (no new items from Phase E):

| Item | Surface | Status |
|---|---|---|
| TIA Openness allow-list registration | Operator action | ✅ DONE (per 19:53 attach success) |
| btnAutoStart binding (Phase 1 PLC paths TBD) | UbpAutoBuilder placeholder | ⏭️ pending C61 Phase 1 ACK |
| btnAutoStop INVERT-both-bits (Phase 1 stop tags TBD) | UbpAutoBuilder placeholder | ⏭️ pending C61 Phase 1 ACK |
| btnAutoReset PULSE pattern (Phase 1 reset tag TBD) | UbpAutoBuilder placeholder | ⏭️ pending C61 Phase 1 ACK |
| IO fields on cardNextStep/cardP1Step/cardStepList (Phase 1 step tags TBD) | UbpAutoBuilder placeholder | ⏭️ pending C61 Phase 1 ACK |

Manual screens (`02_Manual_Kin_Ubp` + `02_Manual_Axis_Ubp` + `02_Manual_Axis_Ubp_J{1..4}`) carry **zero [MANUAL-WIRING] obligations** — all tag bindings are full and live (cycle-6.19 ENABLE INVERT pattern authored in source).

## 4. Screen authoring fire log summary

Visible in the tail of the fire output (full log preserved at `bin/Debug/net48/ubp_authoring_trace.log`):

**Phase C builders** (per cycle-7.0 Phases A+B+C handoff §4):
- `[UBP-CHASSIS]` — `01_Layout_Ubp` host + `BottomNav_Ubp` component + 5 content stubs (Home/Auto/Manual/Diag/Config bilingual placeholders)
- `[UBP-AUTO]` — `02_Auto_Ubp` content (cardNextStep + cardP1Step + cardStepList + cardProgress + cardAutoCtrl 3 buttons)

**Phase D builders** (NEW this turn):
- `[UBP-MANUAL] ───── Build CONTENT 02_Manual_Kin_Ubp ─────` ✓ X/Y/Z jog rows + ENABLE/STOP CTAs (cycle-6.19 INVERT on KinCmdEnable + KinCmdStop)
- `[UBP-MANUAL] ───── Build CONTENT 02_Manual_Axis_Ubp ─────` ✓ 2×2 J{1..4} quadrant grid
- `[UBP-MANUAL] ───── Build PER-AXIS 02_Manual_Axis_Ubp_J{1..4} ─────` × 4 ✓ per-axis deep-drill screens
- `[UBP-MANUAL] ───── Build CONTENT 02_Manual_Ubp ─────` ✓ host with inner-tab strip + swManualTab (rows=2/2 wired)
- `[UBP-MANUAL] Done.`

**cycle-6.19 ENABLE INVERT preservation evidence** (visible 4× in fire log, once per per-axis screen):

```
[EVENT] ✓ 'btnAxSecEnable_Ubp_J4' Tapped.ScriptCode set (97 chars).
[EVENT] 'btnAxSecEnable_Ubp_J4' Tapped read-back (97 chars):
  HMIRuntime.Tags("mc_axis_J4_cmd_Enable").Write(!HMIRuntime.Tags("mc_axis_J4_cmd_Enable").Read());
[UBP-MANUAL][CYCLE-6.19] btnAxSecEnable_Ubp_J4: INVERT on Tapped → mc_axis_J4_cmd_Enable; Down/Up slots EMPTY (defensive).
```

Same evidence for J1, J2, J3 — INVERT pattern preserved on all 4 per-axis ENABLE buttons. Down/Up slots LEFT EMPTY (no Down/Up bindings in fire log for btnAxSecEnable_*).

**Slot wiring evidence**:
- `[SLOT] ✓ 'swContent' HmiScreenWindow → tag 'ubpNavSection' (rows=5/5)` (Layout host's 5-tab content swap)
- `[SLOT] ✓ 'swBottomNav' HmiScreenWindow → tag 'ubpNavSection' (rows=5/5)` (static bottom-nav embed)
- `[SLOT] ✓ 'swManualTab' HmiScreenWindow → tag 'ubpManualTab' (rows=2/2)` (Manual host's Kin/Axis swap)

**Final**: `[UBP] Saving project... [UBP] Project saved. [UBP] done.` ✓

## 5. Compile results

No new compile this turn (fire used `--no-build` against the 0W/0E build from Phase D).

## 6. Issues escalated for PLC agent

_None new from Phase E._ Continuing item carried forward:
- [INFORMATIONAL → PLC] Cycle-7.0 UBP family co-exists with C61 Phase 1 scope lock — UBP HMI authors a parallel 10-inch panel surface; tag bindings reach the SAME PLC backbone (`mc_kin_*` + `mc_axis_J{n}_*`) as v10/v9 HMI_1. PLC's contract surface unaffected; treat cycle-7.0 as INFORMATIONAL. Cycle-7.1 will wire the 4 Auto-button [MANUAL-WIRING] placeholders once Phase 1 ABCDE arbiter tag paths confirmed.

## 7. Verification commands (already executed this turn)

```bash
cd /e/VS_Code_Proj/TiaUnifiedAuto
dotnet run --no-build -- --only=ubp-all
# Result: attached to already-open project (pid=112292)
#         UbpLayoutHostBuilder + UbpAutoBuilder + UbpManualBuilder all fired
#         7 Manual screens + 5 chassis stubs + 1 Auto content + 1 Layout host = 13+ screens authored
#         [UBP] Project saved.
```

## 8. Notes for the PLC agent

- **Phase E fire succeeded** — TIA Openness ACL authorized after Phases A+B+C smoke surfaced the gap. `hmiDemoSCARA_ABCDE.ap20` now hosts the full UBP MTP1000 surface (Layout + Auto + Manual + 4 per-axis) authored from source.
- **Cycle-6.19 ENABLE INVERT preserved live** — visible on 4× `btnAxSecEnable_Ubp_J{1..4}` Tapped scripts at 97 chars each, all matching the canonical `HMIRuntime.Tags("...").Write(!Read())` pattern. Down/Up slots LEFT EMPTY (defensive Comfort Panel duplicate-fire guard).
- **Operator runtime smoke STILL OWES** to flip cycle-7.0 from PENDING_VERIFICATION → VERIFIED:
  - Open `01_Layout_Ubp` in TIA Runtime / WebRH; verify big-font + Siemens-teal theme + responsive 5-tab nav (clicks navigate correctly via Range-mapped swContent)
  - Open `02_Manual_Ubp`; click between Kin / Axis inner tabs; verify swManualTab Range swap
  - Open `02_Manual_Axis_Ubp_J1`; click `使能/ENABLE` button; verify `mc_axis_J1_cmd_Enable` toggle in Watch Table (cycle-6.19 INVERT pattern smoke)
  - Optional: open `02_Auto_Ubp`; verify 2-column layout + Siemens-teal CardTitle accent stripes
- **No PLC contract change.** Cycle-7.0 carried zero PLC asks. Cycle-7.1 will replace the 4 Auto-button [MANUAL-WIRING] placeholders once Phase 1 PLC paths confirmed.
- **Cycle-7.0 cumulative source delta** ~1332 LOC (UbpProfile 140 + UbpScreenNames 90 + UbpLayoutHostBuilder 215 + UbpAutoBuilder 260 + UbpManualBuilder 707 + Program.cs ~140 edits) across 5 new files + 1 edited.
- **Closure markers**: `[NEEDS_OPERATOR]` runtime smoke; otherwise [INFORMATIONAL]. Once operator smoke confirms, this handoff (and the prior Phase D / Phases A+B+C handoffs) all flip PENDING_VERIFICATION → VERIFIED.

---

End of Phase E fire-success handoff. Cycle-7.0 SOURCE-SIDE COMPLETE on canonical project; runtime-side awaits operator smoke.
