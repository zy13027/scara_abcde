**Status:** INFORMATIONAL

# HMI Handoff 2026-05-19 — WinCC Unified Runtime Tag API: authorization model + how PLC agent can drive tag writes for HMI functional testing

## §1 Context

Operator directive (2026-05-19): "tell plc agent how to use wincc unified
api to control tags in runtime to test hmi functionality."

Refined focus per operator follow-up: **"plc agent needs to know
authorization to change the tags in wincc unified"** — i.e., the missing
primitive is not the GraphQL syntax (that's mechanical) but the
auth model that gates every write. This handoff leads with the
authorization story.

No HMI source change. No PLC ask. Pure test-harness guidance.

Backdrop: cycle-7.5 delivered the palletizing screen + 3-way mode mutex
+ C71 facade reads. Pending operator gates: TIA HMI Compile Rebuild All,
Phase 2.2 runtime smoke per C70 §6, C71 PLC-side deploy.

Environment probe this date confirmed:
- PLCSIM-Adv V8.0 RUNNING (`Siemens.Simatic.PlcSim.Advanced.UserInterface`
  pid=117072) with 2 Runtime instances
  (`Siemens.Simatic.Simulation.Runtime.Instance.x64` pid=43420 + 142632)
- 2 TIA Portal processes — one with v9 PM project, one with
  `hmiDemoSCARA_ABCDE.ap20` HMI_1 attached
- PLCSIM-Adv Runtime API DLL at
  `C:\Program Files (x86)\Common Files\Siemens\PLCSIMADV\API\8.0\Siemens.Simatic.Simulation.Runtime.Api.x64.dll`
  (7 prior versions 3.0..7.0 alongside; V8 is the one to link against)

## §2 The auth problem in one paragraph

Unlike the PLCSIM-Adv Runtime API (which has no user/auth model — any
process on the host can read/write any DB), the WinCC Unified Runtime
gates every API operation behind **a JWT issued by the runtime's auth
service, tied to a user defined in TIA User Administration, with a
specific TIA-defined Authorization assigned**. Without a valid JWT, the
GraphQL endpoint returns 401. Without the right Authorization on the
authenticated user, write mutations return permission-denied errors
even with a valid JWT.

The PLC agent's first task is therefore not "call writeTagValues"; it's
"obtain a user identity that the runtime accepts AND that has tag-write
authorization."

## §3 The four-layer authorization stack

WinCC Unified's authorization model is configured top-to-bottom in TIA
Portal. PLC agent's test user must traverse all four layers to land
write capability:

| Layer | What it is | Where in TIA | Who edits it |
|---|---|---|---|
| **L1: Authorizations** | Named privilege primitives (e.g. "Operate", "Modify", "Administer") | HMI_1 → User administration → Authorizations | Operator (TIA) |
| **L2: User Groups** | Named role bundles; each group holds a SET of Authorizations | HMI_1 → User administration → User groups | Operator (TIA) |
| **L3: Users** | Named accounts (username + password); each user belongs to one or more User Groups | HMI_1 → User administration → Users | Operator (TIA) |
| **L4: Runtime auth call** | Bootstrap a JWT by POSTing user credentials to the runtime's login endpoint; the JWT carries the user's effective Authorizations | API call at runtime | PLC agent |

**Default seed**: TIA typically creates an `Administrator` user group +
`Administrator` authorization at project create time but does NOT
auto-create a user. The operator must define at least one user (e.g.
`admin` with a password) and assign it to the Administrator group
**before** the runtime can be programmatically driven.

## §4 The runtime auth flow

### §4.1 Bootstrap the JWT (one-time per session)

```http
POST https://<sim-runtime-host>:<port>/api/auth/login
Content-Type: application/json

{ "username": "admin", "password": "<admin-pw>" }
```

Response (shape — verify exact JSON via PLC agent probe):
```json
{ "access_token": "eyJhbGciOi...", "expires_in": 3600, "token_type": "Bearer" }
```

🟡 **NEEDS_CLARIFICATION** — exact endpoint path varies by V19/V20 and
by runtime SKU. PLC agent first-run probe options to try (in order of
likelihood for V20 Sim Runtime on PC):
1. `POST /UMC/api/auth/login`
2. `POST /api/v1/auth/login`
3. `POST /Account/Login` (legacy WinCC Comfort form)

Capture the working URL from Sim Runtime startup logs (typically printed
when "Start Simulation" launches the runtime). Document in next PLC
handoff so future cycles skip the probe.

### §4.2 Use the JWT in every subsequent API call

```http
POST https://<sim-runtime-host>:<port>/graphql
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{ "query": "mutation { writeTagValues(input: [
  { name: \"palMode\", value: true },
  { name: \"bo_Mode\", value: false },
  { name: \"bo_ManualMode\", value: false }
]) { name error { code description } } }" }
```

If the JWT is missing → HTTP 401. If the JWT is valid but the user lacks
"Modify" (or equivalent) Authorization → HTTP 200 with `error.code:
"PermissionDenied"` in the per-tag result.

### §4.3 JWT refresh

Tokens expire (default 1h). Either re-login when expired, or use a
refresh endpoint if exposed. For test harness sessions <1h, just
re-login on 401.

## §5 Which Authorization does tag write need?

🟡 **NEEDS_CLARIFICATION** — operator must confirm by inspecting the
default Authorizations in the project's User administration. Most
likely candidates for tag write:
- `"Modify"` — direct tag write privilege (most common name)
- `"Operate"` — interactive control (may also permit tag writes via the
  same channel HMI buttons use)
- `"Administer"` — superset of all rights (always works but
  inappropriate for non-admin test scenarios)

Recommended bootstrap user for test harness:
```
Username:    plc_test_harness
Password:    <operator-chosen>
Groups:      [Administrator]   ← simplest path; refine to Modify-only later
```

Operator creates this user via TIA HMI_1 → User administration → Users
→ New User → assigns to Administrator group → re-fires/downloads
runtime. PLC agent then uses these credentials in §4.1 login.

## §6 Concrete test patterns (cycle-7.5 deliverables)

Once §4 auth is bootstrapped, the patterns are:

### §6.1 3-way mode mutex (PLC contract verification)

Atomic 3-tag write — bypasses the HMI Tapped event but exercises the
PLC contract:

```graphql
mutation {
  writeTagValues(input: [
    { name: "palMode", value: true },
    { name: "bo_Mode", value: false },
    { name: "bo_ManualMode", value: false }
  ]) { name error { code description } }
}
```

Then via PLCSIM-Adv: assert all 3 PLC tags reflect the write. Repeat
for the other 2 modes. Negative test: write two modes TRUE, then attempt
Start — PLC FB START gate must reject (defense-in-depth).

### §6.2 Palletizing cycle 1→48 + facade echo

1. Auth + write `palMode := TRUE` + clear other mode bits (atomic)
2. Write `bo_InitPallet := TRUE`; wait 250ms; write `bo_InitPallet := FALSE`
3. Subscribe to `hmiCurrentStep` + `hmiPalletInitialed` + `hmiActiveMode`:
   ```graphql
   subscription {
     tagValues(names: ["hmiCurrentStep","hmiActiveMode","hmiTargetX",
                       "hmiTargetY","hmiTargetZ","hmiTargetA"]) {
       name value { value timestamp }
     }
   }
   ```
4. Write `bo_Start := TRUE`; wait 250ms; write `bo_Start := FALSE`
5. Log each step transition + target X/Y/Z/A at each step
6. Expect 1→48 progression, wrap to 1, per the 4-layer × 12-box grid

### §6.3 BackColor dyn echo verification

Tag-value verification only (widget BackColor is not API-readable):
- Drive `hmiCurrentStep = 15` via PLCSIM-Adv (PLC writes facade)
- Read `hmiCurrentStep` via GraphQL — should equal 15 within 1 cycle
- Range dyn correctness is implicit: cardLayerStack row 2 bound on
  Range "13:24" SHOULD activate. Visual confirmation requires
  Surface C UI screenshot (out of scope for PLC agent — HMI agent's
  surface).

## §7 Limitations + caveats

| Limit | Workaround / note |
|---|---|
| Tag write does NOT trigger HMI JS handlers | OK for PLC-contract testing; for JS-handler testing the HMI agent owns Surface C (computer-use MCP click automation) |
| JWT-based auth required for every call | One-time bootstrap per session; harness should handle 401 → re-login |
| Sim Runtime endpoint config is operator-environment-specific | PLC agent first-run probe documents URL + auth path in next reply |
| Self-signed cert trust on Sim Runtime HTTPS | Test harness can bypass cert validation in dev; document if production-bound |
| MTP1000 Basic hardware: GraphQL availability 🟡 NEEDS_CLARIFICATION | Sim Runtime path is the test target regardless of hardware SKU |
| C71 facade reads (`hmiCurrentStep`, etc.) require C71 PLC-side deploy | Verify C71 §6 #4-#5 deploy steps complete before §6.2 facade tests |

## §8 Recommended PLC-agent runbook

1. **Operator step** — create test user in TIA User administration:
   - Username `plc_test_harness`, assign to `Administrator` group,
     download runtime config to Sim Runtime.
2. **PLC agent probe** — first-run probe Sim Runtime to discover:
   - Auth endpoint URL (try §4.1 candidates in order)
   - GraphQL endpoint URL (typically same host:port + `/graphql`)
   - WebSocket subscription URL
   - Document in next PLC handoff reply.
3. **PLC agent harness wire-up** — extend existing PLCSIM-Adv .NET test
   harness with HttpClient + JWT-bearer GraphQL POST helper. Cache JWT,
   refresh on 401.
4. **Smoke validation** — read a single known tag (e.g. `bo_Mode`) via
   GraphQL to confirm channel + auth alive.
5. **Run §6.1 mutex test** — atomic 3-tag write, assert PLC echoes via
   PLCSIM-Adv. Capture pass/fail per mode.
6. **Run §6.2 palletizing cycle test** — full Init→Start→48-step→wrap
   with subscription log. Persist CSV for cycle-7.5 verification.
7. **Run §6.3 facade echo test** — drive `hmiCurrentStep` from PLC side,
   read via GraphQL, verify round-trip. Repeats for all 36 C71 facade
   members under all 3 modes.
8. **Report back** — PLC handoff reply close cycle-7.5 PENDING_VERIFICATION
   → VERIFIED on the PLC-contract side. Surface C (UI smoke) remains
   open until HMI agent / operator drives it.

## §9 Notes for the HMI agent + closure markers

- 🟡 [NEEDS_CLARIFICATION] — auth endpoint URL on Sim Runtime (PLC agent probes per §4.1).
- 🟡 [NEEDS_CLARIFICATION] — exact name of the Authorization that gates `writeTagValues` (default project may use "Modify", "Operate", or custom name).
- 🟡 [NEEDS_HUMAN] — operator creates `plc_test_harness` user in TIA User administration before §6 tests can run.
- ℹ️ [INFORMATIONAL] — handoff opens no contract gap and adds no PLC ask. Pure guidance for PLC agent test-harness extension.
- ℹ️ Cycle-7.5 deliverables unchanged. Source-side patch this date: `Builders/Ubp/UbpManualBuilder.cs` `BuildPerAxisHeader` per-axis lamp strip overflow fix (caption width 220→120, spacing 110→160, lampStartX 960→760, order Homed→Ready→Error per operator's TIA hand-correction; Property Inspector showed Position left=799 Size width=120). Build 0W/0E. Awaits next operator re-fire of `--only=ubp-manual`.
- ℹ️ Reference cycle-7.5: `HMI_HANDOFF_2026-05-18_Cycle7_5_PalletScreen_C71_FacadeAdoption.md`

End of HMI Handoff 2026-05-19 — WinCC Unified Runtime Tag API authorization guidance.
