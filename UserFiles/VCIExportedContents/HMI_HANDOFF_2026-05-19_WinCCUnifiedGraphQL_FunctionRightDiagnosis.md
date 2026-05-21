**Status:** ACKNOWLEDGED — empirical findings absorbed; closes 3 of 3 NEEDS_CLARIFICATION items from v21; new [NEEDS_HUMAN] surfaced for SCARA remediation

# HMI Handoff 2026-05-19 — Ack PLC `WinCCUnifiedRuntimeTagApi_EmpiricalFindings` + diagnoses the missing function right gating GraphQL tag access (`Openness Runtime - read and write access`)

## §1 Read receipt

Read `PLC_HANDOFF_2026-05-19_WinCCUnifiedRuntimeTagApi_EmpiricalFindings.md` (Status: INFORMATIONAL; closes 2 of 3 NEEDS_CLARIFICATION items from my v21 handoff; opens [NEEDS_HMI_DIAGNOSIS]) in full. 7 sections: §1 ACK + executive summary; §2 empirical answers; §3 3 V20 gotchas (trailing slash / Apollo CSRF / localhost-only); §4 ready-to-reuse `WinCCUnified_GraphQL.psm1` wrapper at `hmiDemoSCARA_ABCDE/UserFiles/harness/`; §5 still-open FORBIDDEN blocker with diagnosis recommendation; §6 test patterns concurrence; §7 closure markers.

## §2 Empirical corrections to my v21 handoff

### §2.1 Auth is a GraphQL mutation, not a REST endpoint

My v21 `_WinCCUnifiedRuntimeTagApi_AuthorizationGuidance.md` §4.1 candidate URLs (`/UMC/api/auth/login`, `/api/v1/auth/login`, `/Account/Login` legacy) were ALL WRONG. The real auth flow is a GraphQL `login` mutation POSTed to the SAME GraphQL endpoint:

```graphql
mutation {
  login(username: "...", password: "...") {
    token
    expires
    user { id name fullName }
    error { code description }
  }
}
```

→ Bearer token in response → use as `Authorization: Bearer <token>` header on subsequent calls.

🟢 **[RESOLVED]** v21 §4.1 NEEDS_CLARIFICATION (auth endpoint URL).

### §2.2 Bearer header in subsequent calls — confirmed

v21 §4.2 confirmed correct. ✅

### §2.3 MTP1000 Basic GraphQL availability — confirmed via Sim Runtime

🟢 **[RESOLVED]** v21 §7 `🟡 NEEDS_CLARIFICATION` (Basic SKU GraphQL availability). PC Sim Runtime exposes full GraphQL surface regardless of target SKU. The simulated `MTP1000 Unified Basic` device works identically to a `MTP1000 Unified Comfort` simulation for GraphQL endpoint behavior.

### §2.4 Three V20 gotchas absorbed (NEW knowledge from PLC empirical testing)

Three V20-specific gotchas surfaced by PLC agent that my v21 didn't cover. Absorbing into HMI-side memory for cross-session reference:

| # | Gotcha | Symptom | Fix |
|---|---|---|---|
| 1 | Trailing slash MANDATORY on `/graphql/` | POST without slash → 301 → IIS degrades to GET → 405 Method Not Allowed | Always POST to `/graphql/` (with slash) |
| 2 | Apollo CSRF preflight header | POST without `apollo-require-preflight: true` → 400 BAD_REQUEST "potential Cross-Site Request Forgery..." | Add header `apollo-require-preflight: true` (or any non-empty custom header) on every POST |
| 3 | `https://localhost/` only (.NET TLS) | Hostname-based URL (`https://desktop-9988rob/`) → .NET TLS handshake fails "Received an unexpected EOF or 0 bytes from the transport stream" | Use `https://localhost/graphql/` from harness scripts (self-signed cert is issued for `localhost`) |

These 3 gotchas would have wasted ~hours of harness debugging if not surfaced. Saved by PLC agent empirical work.

## §3 Diagnosis of PLC agent's [NEEDS_HMI_DIAGNOSIS] (§5)

PLC agent's recommendation (§5 step 1): operator extracts v9's `WebPageAPI` role function rights from TIA UI. Operator delivered **4 screenshots** of v9 Security settings → Users and roles. Analysis below.

### §3.1 Confirmation of PLC agent's hypothesis

**Screenshot 1** (Users tab → Admin selected → Assigned roles): v9's Admin user has BOTH user-defined roles ticked:
- ✅ `WebPageAPI` (User-defined role)
- ✅ `WebPageAPI_Anyonoums` (User-defined role; typo for "Anonymous" preserved as authored)

Alongside the system roles: ✅ Drive Administrator / ✅ HMI Administrator / ✅ HMI Operator / ✅ HMI Monitor / ✅ HMI Online Configuration Engineer / ✅ PLC administrator / ✅ PLC F administrator / ✅ NET Administrator / ✅ NET Standard / ✅ NET Diagnose. The user-defined roles add capability beyond system roles.

### §3.2 v9's WebPageAPI role — full function rights inventory

**Screenshots 2 + 3** (`WebPageAPI` / `WebPageAPI_Anyonoums` → Runtime rights → **WinCC Unified Comfort Panel devices V…** category): both user-defined roles have IDENTICAL ticked rights:

| Function right | Ticked? | Likely gates |
|---|---|---|
| User management | ✅ | UMC user CRUD via API |
| Monitor | ✅ | HMI monitoring/observation ops |
| Activate HMI Monitor Client | ❌ | (not needed) |
| Operate | ✅ | Interactive HMI control ops |
| Remote access | ❌ | (not needed) |
| Remote access - Monitor only | ❌ | (not needed) |
| **`Openness Runtime - read and write access`** | ✅ | **🎯 GraphQL `tagValues` query + `writeTagValues` mutation** |
| OPC UA - read and write access | ✅ | OPC UA protocol tag R/W (separate from GraphQL) |
| Import and export users | ✅ | UMC user import/export |
| Reset UMC password | ✅ | UMC password reset |
| Control Panel access | ✅ | Runtime control panel UI |
| First electronic signature | ❌ | (not needed) |
| Second electronic signature | ❌ | (not needed) |

**Screenshots 4 + 5** (same roles → Runtime rights → **S7-1500 V4.0** category): all PLC-side web-server / OPC UA / process-data rights ticked (HMI access / Read access / Full access / OPC UA server access / Manage certificates / Change operating mode / Change web server default page / Read diagnostics / Acknowledge alarms / Read syslog / Flash LEDs / Update firmware / Change time / Backup + Restore CPU / Download service data / Read process data). These are PLC-side rights — NOT relevant to HMI GraphQL.

### §3.3 The gating right

🎯 **The function right that gates WinCC Unified Runtime GraphQL `tagValues` query + `writeTagValues` mutation is:**

> **`Openness Runtime - read and write access`**

Located in: TIA → Security settings → Users and roles → Roles tab → select role → Runtime rights tab → Function rights categories tree → expand the device-category subtree for the target HMI SKU.

This right is **NOT** included in any of the 3 system-defined HMI roles (per PLC agent's empirical test confirming Admin with all 3 system HMI roles still got FORBIDDEN):
- `HMI Administrator` (description: "User management, Monitor, Oper...")
- `HMI Operator` (description: "Web access, Operate, HMI read an...")
- `HMI Monitor` (description: "Web access, Monitor, HMI read ac...")

It must be **explicitly assigned via a user-defined role**. v9's previous setup did this (the `WebPageAPI` + `WebPageAPI_Anyonoums` roles); SCARA's project never had it — hence FORBIDDEN result on SCARA's Admin user despite having all 3 system HMI roles.

### §3.4 Semantic note — why "Openness Runtime"

Siemens nomenclature for V20:
- **TIA Portal Openness** = design-time `.NET` API for project authoring (`Siemens.Engineering.*` — what `TiaUnifiedAuto` uses every cycle)
- **Openness Runtime** = runtime-side counterpart — programmatic access at runtime, surfaced via the WinCC Unified Runtime's HTTPS/GraphQL endpoint

So "Openness Runtime - read and write access" is precisely the right that gates programmatic tag R/W via the GraphQL endpoint. The naming is semantically consistent across the engineering/runtime split.

🟢 **[RESOLVED]** PLC agent's [NEEDS_HMI_DIAGNOSIS] from §5 — gating right identified.

## §4 Action plan for SCARA project remediation

Per PLC agent's §5 step 4 + the diagnosis above. Per operator's earlier choice in this session, action plan opens as a **[NEEDS_HUMAN]** for the operator to execute in SCARA TIA.

🟡 **[NEEDS_HUMAN]** — operator steps to unblock GraphQL tag access on SCARA Sim Runtime:

| # | Step | Detail |
|---|---|---|
| 1 | Open SCARA TIA project | `hmiDemoSCARA_ABCDE.ap20` |
| 2 | Navigate to Security settings | Project tree → `Security settings` → `Users and roles` |
| 3 | **Roles** tab → **Add new role** | Name: `WebPageAPI` (mirrors v9 naming for consistency) |
| 4 | Select the new role | → **Runtime rights** tab |
| 5 | Expand device category subtree | **"WinCC Unified Basic Panel devices V1…"** (NOT Comfort — SCARA's HMI_1 is `MTP1000 Unified Basic` per cycle-7.0 plans, article `6AV2 123-3KB32-0AW0`) |
| 6 | Tick the gating right | ✅ **`Openness Runtime - read and write access`** (minimum required for GraphQL) |
| 7 | (Optional v9-parity) | Tick User management / Monitor / Operate / OPC UA - read and write access / Import and export users / Reset UMC password / Control Panel access. Skip Activate HMI Monitor Client / Remote access / electronic signatures. |
| 8 | Switch to **Users** tab | → select `Admin` (v9 SCARA's existing admin user with password `12345678`) |
| 9 | **Assigned roles** sub-tab | → tick the new `WebPageAPI` role |
| 10 | Compile + Download HMI | Compile changes + download to Sim Runtime instance |
| 11 | Restart Sim Runtime | Stop + Start Simulation again to reload user/role config |
| 12 | PLC agent re-runs smoke | `Read-WinCCUnifiedTag` + `Write-WinCCUnifiedTag` → expect SUCCESS (no more FORBIDDEN) |

### §4.1 Hedge — verify right exists in Basic Panel category

I'm extrapolating from the Comfort Panel category screenshots that `Openness Runtime - read and write access` exists under the **Basic Panel V1…** category with the same name. Siemens typically uses consistent right names across SKU families, but a small chance exists that:
- The right has a different name under Basic (e.g., shortened, or with a different prefix)
- The right doesn't exist under Basic (Basic SKU may have a constrained rights surface)

**Operator verification at step 5**: if `Openness Runtime - read and write access` is not listed under the Basic Panel category, look for an analogous right with one of these substring matches:
- `"Openness"` (most likely)
- `"Runtime API"` / `"Web API"`
- `"read and write"` (paired with HMI tag context)

If none of these exist under Basic, fall back to a system role that DOES include tag R/W via API — but per PLC agent's empirical test, none of the 3 system HMI roles do. In that scenario, escalate back as a [NEEDS_CLARIFICATION].

### §4.2 Minimal vs full parity

- **Minimal** (just unblock GraphQL): step 6 only. Saves ~5 sec of clicking. Test harness gets exactly what it needs. **RECOMMENDED** for the immediate unblock.
- **Full v9 parity** (steps 6 + 7): documents the operator's prior intent. Recommended if SCARA project may eventually grow features needing user mgmt / OPC UA / Control Panel access.

## §5 Test patterns — HMI agent stance

Concur with PLC agent §6:
- **§6.1 3-way mode mutex** (atomic 3-tag write): ✅ wrapper's `Write-WinCCUnifiedTag -Tags @{palMode=$true; bo_Mode=$false; bo_ManualMode=$false}` does this in one mutation → atomic. Once §4 unblocks, this test runs first.
- **§6.2 palletizing 1→48 + subscription**: needs WebSocket transport extension to wrapper. **Adding as cycle-7.6+ HMI-side candidate** alongside existing items (cardProgress facade retrofit / Manual screens facade retrofit / 2D pallet view / 6 Cartesian Kin widgets / BuildContentStub idempotency / mcSetTool_Active orphan repair / per-axis Enable mutex review). Subscription is nice-to-have; 500ms polling via PLCSIM-Adv reads (co-driver pattern from `_PlcsimAdvDllLocationsAck` §2.4) is sufficient for cycle-7.5 verification.
- **§6.3 facade echo**: ✅ straightforward; works as soon as §4 unblocks.

## §6 Notes + closure markers

- ✅ [ACKNOWLEDGED] — PLC empirical findings absorbed in full
- 🟢 [RESOLVED] — v21 §4.1 NEEDS_CLARIFICATION (auth URL): auth is a GraphQL `login` mutation POSTed to the same `/graphql/` endpoint, not a separate REST endpoint
- 🟢 [RESOLVED] — v21 §7 NEEDS_CLARIFICATION (MTP1000 Basic GraphQL availability): PC Sim Runtime exposes full surface regardless of target SKU
- 🟢 [RESOLVED] — PLC's [NEEDS_HMI_DIAGNOSIS] from §5: gating right is **`Openness Runtime - read and write access`** under the device-category subtree (Comfort/Basic per target SKU)
- 🟡 [NEEDS_HUMAN] — operator applies §4 remediation steps in SCARA TIA project (create `WebPageAPI` role with `Openness Runtime - read and write access` ticked under "WinCC Unified Basic Panel devices V1…" → assign to Admin → Compile → Download → restart Sim Runtime)
- ℹ️ [INFORMATIONAL] — 3 V20 gotchas folded into HMI agent knowledge (trailing slash on `/graphql/` + Apollo CSRF preflight header `apollo-require-preflight: true` + `https://localhost/` only for self-signed cert TLS handshake)
- ℹ️ §6.2 WebSocket subscription extension added to cycle-7.6+ HMI-side candidates list
- ℹ️ Cycle-7.5 deliverables unchanged; same-date source-side patch (UbpManualBuilder BuildPerAxisHeader lamp overflow fix) unchanged
- No PLC contract ask. Once operator completes §4 steps, PLC agent re-runs §6 test patterns; expect cycle-7.5 PENDING_VERIFICATION → VERIFIED on PLC-contract side.

End of HMI Handoff 2026-05-19 — function-right diagnosis: `Openness Runtime - read and write access` gates GraphQL tag access.
