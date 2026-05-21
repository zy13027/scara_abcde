**Status:** INFORMATIONAL → scara-PLC. **TIA target:** `hmiDemoSCARA_ABCDE.ap20`. **Predecessor:** `HMI_HANDOFF_2026-05-19_WinCCUnifiedGraphQL_FunctionRightDiagnosis.md` §4 (action plan); `PLC_HANDOFF_2026-05-19_WinCCUnifiedRuntimeTagApi_EmpiricalFindings.md` §5 (FORBIDDEN diagnosis recommendation).

# HMI Handoff 2026-05-19 — SCARA WebPageAPI role applied; scara-PLC trigger to re-run GraphQL smoke

## §1 Trigger

Operator completed the §4 remediation steps from `_FunctionRightDiagnosis.md` on `hmiDemoSCARA_ABCDE.ap20` and provided 3 TIA screenshot confirmations (HMI agent verified config 2026-05-19). The WebPageAPI role + the `Openness Runtime - read and write access` function right are now in place on SCARA's Admin user. scara-PLC's smoke against `Read-WinCCUnifiedTag` / `Write-WinCCUnifiedTag` is now unblocked.

## §2 What was applied (verified from operator screenshots)

| Step (per `_FunctionRightDiagnosis.md` §4) | State on SCARA project |
|---|---|
| Create `WebPageAPI` user-defined role | ✅ created (visible in Roles tab) |
| Open Runtime rights → `WinCC Unified Basic Panel devices V1…` → HMI_1 | ✅ |
| ✅ **`Openness Runtime - read and write access`** ticked | ✅ ticked (the gating right) |
| All other HMI_1 rights ticked (v9-parity option) | ✅ all 9/9 ticked (Control Panel access / Remote access / Monitor / Operate / User management / Remote access - Monitor only / Openness Runtime - read and write access / OPC UA - read and write access / Reset UMC password) |
| S7-1500 V4.0 rights (PLC_1, not strictly required for GraphQL) | ✅ 26/27 ticked (only `User authentication of the OPC UA client` left unticked — OPC UA client-cert auth, irrelevant to GraphQL HMI tag access) |
| Users tab → Admin → Assigned roles → tick `WebPageAPI` | ✅ ticked |

The configuration is **more complete than v9's WebPageAPI** proportionally — Basic Panel SKU has 9 rights total (vs Comfort's 13); all 9 are ticked. Nothing more to add at this scope.

## §3 scara-PLC next-step trigger (unambiguous)

**Re-run the smoke that previously returned FORBIDDEN.** The PLC handoff `_EmpiricalFindings.md` §5 reproduced this on SCARA before today's remediation:

```
mutation login(username: "Admin", password: "12345678")   → ✅ Bearer token (75-min expiry)
{ session { user { groups { name } } } }                  → ✅ all 3 system HMI roles
{ tagValues(names: ["bo_Start"]) { ... } }                → ❌ FORBIDDEN
mutation { writeTagValues(input: [{name: "bo_Mode", value: true}]) { ... } } → ❌ FORBIDDEN
```

**Expected post-remediation outcome:**

```
mutation login(username: "Admin", password: "12345678")   → ✅ Bearer token (unchanged)
{ tagValues(names: ["bo_Start"]) { ... } }                → ✅ tag value returned
mutation { writeTagValues(input: [{name: "bo_Mode", value: true}]) { ... } } → ✅ success / no error in per-tag result
```

If FORBIDDEN persists, candidate fallback causes (in priority order):
1. **TIA Compile + Download not yet executed** — operator step 10-11 of `_FunctionRightDiagnosis.md` §4 (Compile → Download HMI → restart Sim Runtime). Without download, the new role config doesn't reach the runtime image. Verify by checking Sim Runtime restart timestamp post-config.
2. **Sim Runtime cached old config** — full stop + start cycle needed (not just download). Try `Online → Simulation → Stop`, wait 5 sec, `Start Simulation`.
3. **Role not actually assigned** — TIA's role assignment in Users tab needs a save before Compile picks it up. Operator re-confirms by clicking `WebPageAPI` checkbox in Admin's Assigned roles + re-Compile.
4. **Different Authorization name than expected** — unlikely given screenshot confirmation, but if persisting, surface here and I'll spawn an Openness probe of v9's working WebPageAPI rights export for byte-level comparison.

## §4 Test pattern stance (carry-over from `_FunctionRightDiagnosis.md` §5)

Once §3 smoke confirms tag R/W is working, run the cycle-7.5 verification suite in order:

1. **§6.1 from `_AuthorizationGuidance.md`** — 3-way mode mutex atomic 3-tag write (`palMode` + `bo_Mode` + `bo_ManualMode`); assert PLC echoes via PLCSIM-Adv co-driver pattern
2. **§6.3 facade echo** — drive `hmiCurrentStep` from PLC side, read via GraphQL, verify round-trip on C71's 36 facade members under all 3 modes (requires C71 PLC-side deploy completed)
3. **§6.2 palletizing 1→48 cycle** — needs WebSocket subscription extension (deferred per `_AuthorizationGuidance.md` §5; out of scope for this trigger)

Once §6.1 + §6.3 pass on PLC-contract side, cycle-7.5 PENDING_VERIFICATION → VERIFIED for the PLC contract layer. UI smoke (cycle-7.5 PENDING for Surface C) remains operator + HMI-agent lane.

## §5 Closure markers

- ℹ️ [INFORMATIONAL] no contract change, no source delta, no PLC code obligation
- 🟢 [NEEDS_HUMAN → RESOLVED] operator applied `_FunctionRightDiagnosis.md` §4 step 1-9 (role create + rights tick + Admin assignment) — confirmed by 3 TIA screenshots
- 🟡 [NEEDS_HUMAN] operator still owes steps 10-11 (Compile → Download HMI → restart Sim Runtime) — required before scara-PLC's re-test can use new config
- 🆕 [NEEDS_scaraPLC] re-run `Read-WinCCUnifiedTag` / `Write-WinCCUnifiedTag` smoke after operator confirms steps 10-11 done; report SUCCESS/FORBIDDEN in next PLC handoff
- ℹ️ [INFO] cycle-7.5 deliverables unchanged; same-date source-side patch (UbpManualBuilder BuildPerAxisHeader lamp overflow fix) unchanged
- ℹ️ [INFO] scara-HMI internalized 3-question pre-write checklist this session; this handoff lands directly in SCARA tree (correct path) — no v9-tree drift

End of HMI Handoff 2026-05-19 — SCARA WebPageAPI role applied; scara-PLC trigger to re-run GraphQL smoke.
