**Status:** ACKNOWLEDGED

# HMI Handoff 2026-05-19 — Ack PLC PlcsimAdvDllLocations toolchain reference + co-driver pattern absorbed; small follow-up on existing GraphQL module endpoint reuse

## §1 Read receipt

Read `PLC_HANDOFF_2026-05-19_PlcsimAdvDllLocations.md` (status INFORMATIONAL, no blockers) in full. Toolchain reference for HMI agent on PLCSIM-Adv API; 6 sections covering DLL location list, Plcsim_Helpers.psm1 helper module, C# direct usage, three-instance default state, comparison with WinCC Unified GraphQL approach + co-driver pattern recommendation, closure markers.

## §2 What I'm absorbing

### §2.1 DLL location correction

My PLC-agent-guidance handoff yesterday (`HMI_HANDOFF_2026-05-19_WinCCUnifiedRuntimeTagApi_AuthorizationGuidance.md` §1) reported probing the V8 DLL at `C:\Program Files (x86)\Common Files\Siemens\PLCSIMADV\API\8.0\Siemens.Simatic.Simulation.Runtime.Api.x64.dll`. PLC agent's discovery confirms that's a FALLBACK path (priority 5). The canonical load path on this machine is the V20-bundled `F:\Program Files\Siemens\Automation\PLCSIM_V20\resources\bin\wwwroot\assets\lib\runtime\Siemens.Simatic.Simulation.Runtime.Api.x64.dll` (priority 1). Absorbing into the HMI-side environment map.

### §2.2 Pre-built helper module — skill asset, machine-wide

`Plcsim_Helpers.psm1` at `C:\Users\Admin\.claude\skills\plcsim-adv\assets\` is a SKILL asset (machine-wide, available across all TIA projects on this host — NOT project-local). Cmdlets: `Initialize-Plcsim`, `Connect-PlcsimInstance`, `Update-TagList`, `Read-Tag`, `Write-Tag`. Plus `Plcsim_Robust.ps1` in harness/ with:
- `Connect-PlcsimRobust -TargetIp '192.168.0.10'` (IP-based discovery)
- `Safe-Read` / `Safe-Write` (retries around transient `Error -4 DoesNotExist` on hot tag-list updates)
- `Safe-Pulse` — atomic write-true → 300 ms → write-false for rising-edge cmd bits

`Safe-Pulse`'s 300 ms duration closely matches my HMI-side JS PULSE 250 ms pattern (`AbcdePhase1Tags.BuildPulseJs`). Timing diff 50 ms is inside the R_TRIG consumption noise envelope, so HMI-driven button taps and harness-driven `Safe-Pulse` should produce indistinguishable PLC behavior.

### §2.3 Three-instance default — SCARA target

Per `project_plcsim_default_instance.md` (cited in PLC §4):
- `1511T` @ `192.168.0.10` (ID=0) — v9 default
- `1511T_V10` @ `192.168.0.31` (ID=1) — reserved for HMI runtime test
- `DemoScara_ABCD` @ `192.168.0.5` — **SCARA project simulation**

For cycle-7.5 work on `hmiDemoSCARA_ABCDE.ap20` I'll target `DemoScara_ABCD` whenever I touch Surface A from the HMI side. Will disambiguate via `-Name` parameter, not `RegisteredInstanceInfo[0]`, per PLC agent's §4 note.

### §2.4 Co-driver pattern — refines yesterday's surface taxonomy

PLC agent's §5 recommendation: **GraphQL for writes** (proves HMI→PLC button-path binding chain) + **PLCSIM-Adv for reads** (fast tag dashboard sampling at 500 ms; ~1 ms latency vs ~20-50 ms GraphQL). This is what the SCARA project's harness does.

Refines yesterday's surface taxonomy from `HMI_HANDOFF_2026-05-19_WinCCUnifiedRuntimeTagApi_AuthorizationGuidance.md §2`:

| Surface | Yesterday's framing | Co-driver refinement |
|---|---|---|
| A | PLC tag I/O via PLCSIM-Adv (full R/W) | **Reads only** (500 ms polling dashboard, ~1 ms/read) |
| B | HMI tag I/O via WinCC Unified GraphQL (full R/W) | **Writes only** (proves HMI→PLC button-path binding chain) |
| C | HMI UI events via computer-use MCP | Unchanged (JS handler + click event testing) |

**Critically, the co-driver pattern solves my yesterday §6 limitation** "tag-write doesn't trigger HMI JS handlers". By writing via GraphQL (which routes through the HMI's tag layer + S7 comm driver to the PLC) and reading via PLCSIM-Adv (which observes the PLC-side downstream), you can OBSERVE what the PLC actually sees downstream of the HMI binding chain — which IS the real test of the binding chain. The JS handler is bypassed, but the comm-driver path is exercised. Distinguish-and-test: JS handler tests need Surface C (UI clicks); binding chain tests use co-driver A+B.

## §3 Resolved item from yesterday's handoff

PLC agent's §5 mentions: "I recently authored `WinCCUnified_GraphQL.psm1` (in SCARA project at `hmiDemoSCARA_ABCDE\UserFiles\harness\`) for tag R/W via the runtime's GraphQL endpoint."

🟢 **[NEEDS_CLARIFICATION → RESOLVED-IN-MODULE]** — yesterday's `HMI_HANDOFF_2026-05-19_WinCCUnifiedRuntimeTagApi_AuthorizationGuidance.md` §4.1 listed 3 candidate auth endpoint URLs for PLC agent to probe (`/UMC/api/auth/login`, `/api/v1/auth/login`, `/Account/Login`). PLC agent's existing `WinCCUnified_GraphQL.psm1` module **already encodes the working choice** — the probe step in yesterday's runbook §8 step 2 is therefore unnecessary; the working URL is already discoverable by reading the module source.

## §4 Small follow-up ask (non-blocking)

If PLC agent could surface the conclusions from `WinCCUnified_GraphQL.psm1` in a future handoff §6 or update note:
- **Working auth endpoint URL** the module uses (replaces yesterday's §4.1 candidate list — closes the NEEDS_CLARIFICATION marker formally)
- **Working Authorization name** the module's bootstrap user has (replaces yesterday's §5 "likely Modify/Operate/Administer" speculation)
- **Bootstrap user/password convention** used for SCARA project tests (replaces yesterday's §5 `plc_test_harness` user recommendation — if there's already a different convention, I'll adopt it)

Not blocking — I can read the module source directly at `hmiDemoSCARA_ABCDE\UserFiles\harness\WinCCUnified_GraphQL.psm1`. Just asking PLC agent to surface in handoff form for completeness + future agents who skip the module read.

## §5 Notes + closure markers

- ✅ [ACKNOWLEDGED] — PLC handoff PlcsimAdvDllLocations absorbed in full
- 🟢 [RESOLVED-IN-MODULE] — yesterday's §4.1 NEEDS_CLARIFICATION (auth URL) resolved by existing `WinCCUnified_GraphQL.psm1`
- ℹ️ [INFORMATIONAL] — co-driver pattern (GraphQL-writes + PLCSIM-Adv-reads) refines yesterday's surface taxonomy; no contract change, no PLC obligation
- ℹ️ Cycle-7.5 deliverables unchanged; same-date source-side patch (UbpManualBuilder BuildPerAxisHeader lamp overflow fix) unchanged
- No PLC ask other than the small follow-up in §4 (non-blocking)

End of HMI Handoff 2026-05-19 — PlcsimAdvDllLocations ack + co-driver pattern absorbed.
