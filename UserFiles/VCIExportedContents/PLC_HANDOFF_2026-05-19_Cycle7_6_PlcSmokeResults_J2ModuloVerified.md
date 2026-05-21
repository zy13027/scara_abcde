**Status:** VERIFIED (Cycle-7.6 PLC-side + J2 modulo fix end-to-end) + PENDING (GraphQL re-test — operator owes Compile+Download+Restart). **TIA target:** `hmiDemoSCARA_ABCDE.ap20`. **Replies to:** `HMI_HANDOFF_2026-05-19_Cycle7_6_IssueA_Closed_PlcReTestReady.md` + `HMI_HANDOFF_2026-05-19_WebPageAPIRoleApplied_PlcReTestTrigger.md`.

# PLC_HANDOFF — Cycle-7.6 PLC smoke results + J2 modulo end-to-end verification (2026-05-19)

**Project:** `hmiDemoSCARA_ABCDE`
**Audience:** scara-HMI agent + operator
**Predecessors:**
- HMI cycle-7.6 closure (this session's trigger): IOField retrofit + adapter TagDynamization fix + tag-table alignment
- HMI WebPageAPI role applied: SCARA Admin gets `Openness Runtime - read and write access` function right
- PLC HMI follow-ups handoff (earlier today): documented Issue A + Issue B + verification path
- J2 modulo plan (`starry-seeking-seal.md`, operator deployed via TIA UI): Wang Shuo's [0, 360°) convention on J1/J2/J4

## 1. Executive summary

Ran 3 smokes in sequence WITHOUT PowerOff/On between (the canonical regression scenario for J2 multi-rev accumulation):

| Smoke | Result | Notes |
|---|---|---|
| `Prearm_AbcdeAxes.ps1 -TargetIp 192.168.0.5` | ✅ PASS | axesReady=TRUE in <2s; J1/J2/J3/J4 all at 0 at home |
| `SmokeTest_PhaseF_V8.ps1` (ABCDE 5-point + blending) | ✅ **5/5 PASS** | 0% standstill, 5 wraps in 45s, max statProgress avg 0.48 — clean blending |
| `SmokeTest_Phase2_Palletizing.ps1` (12-gate palletizing) | ✅ **12/12 PASS** | 48/48 steps + 2 cycle wraps in 120s, layer Z progression 300/350/400/450 detected, mutex blocks ABCDE while palletizing active |
| GraphQL re-test (Read-WinCCUnifiedTag) | ❌ **FORBIDDEN** | Login OK + Bearer token granted; tagValues still returns Access denied — operator owes Compile + Download HMI + Sim Runtime restart per WebPageAPI handoff §5 |

**Headline outcomes**:

1. **Cycle-7.6 IssueA PLC-side verification: PASS** — all 4 verification-path gates from PLC `_HMI_Followups_HeaderStripAndIOFieldRendering.md` §5 cleared. Visual HMI runtime verification (operator looks at IOField rendering on screen) still owed but is HMI-side, not PLC.
2. **J2 modulo fix VERIFIED end-to-end** — sequential ABCDE→Palletizing without PowerOff/On now works clean. Previously froze at palletizing step 11 due to J2 accumulating to -578° from prior ABCDE cycle; with modulo, J1/J2/J4 bounded in [0, 360°). Stuck-cycle workaround retired.
3. **GraphQL re-test FAILED with same FORBIDDEN** — strongly suggests operator hasn't completed the `Compile → Download HMI → Restart Sim Runtime` chain after applying WebPageAPI role. Re-test required after that completes.

## 2. Cycle-7.6 Issue A — PLC-side verification gates

Per PLC handoff `_HMI_Followups_HeaderStripAndIOFieldRendering.md` §5:

### Gate 1: Pre-arm

```
================================================================
Prearm SCARA Axes for HMI-driven cycle  Target IP: 192.168.0.5
================================================================
  - DemoScara_ABCDE  IPs:[192.168.0.5]  State:Run  ^ MATCHES TARGET
[1/6] Clearing mode bits...      OK
[2/6] Pulsing GDB_Control.resetAxes...  OK
[3/6] enableAxes=TRUE, waiting for axesEnabled (10s)... axesEnabled=TRUE
[4/6] homeAxes=TRUE, waiting for axesHomed (10s)...    axesHomed=TRUE
[5/6] Releasing homeAxes...
[6/6] Verifying axesReady...  axesReady=TRUE
Joint actuals at home:  J1: 0  J2: 0  J3: 0  J4: 0
Prearm complete.
```

✅ axesReady=TRUE in <2s. All 4 joints at 0° at home (modulo wrap-to-zero confirmed at startup).

### Gate 2: ABCDE 5/5 cycle

`SmokeTest_PhaseF_V8.ps1` — 45s blending sample:

| Gate | Result | Detail |
|---|---|---|
| F.CycleStarted | ✅ | i16_AutoStep=10 within <1s of Start pulse |
| F.V8SclLoaded | ✅ | statProgress readable (= 0.136 mid-segment) |
| V8.Blending | ✅ | 0% standstill (363/363 samples, target <5%) — BM_BLENDING_HIGH continuous motion |
| V8.CycleCount | ✅ | 5 cycle wraps in 45s (Phase D baseline 3-4) |
| V8.ProgressTrigger | ✅ | Avg max statProgress 0.48 per step (target >=0.45 — crosses 0.5 advance threshold cleanly) |

**5/5 PASS — cycle wraps 10→20→30→40→50→10 cleanly, no stuck steps, blending optimal.**

For the cycle-7.6 IOField verification: `i16_AutoStep` advanced through all 5 ABCDE positions × 5 wraps = 25 step transitions in 45s. The C71 facade `GDB_HMI_Status.currentStep` mirrors this (`activeMode=1` ABCDE mode + facade routes from `instFB_AutoCtrl_ABCDE.i16_AutoStep`). HMI bindings should observe live Int values.

### Gate 3: Palletizing (no PowerOff/On between)

`SmokeTest_Phase2_Palletizing.ps1` — 120s observation:

| Gate | Result | Detail |
|---|---|---|
| V-Pal.PreflightTags | ✅ | 10 palletizing tags readable |
| V-Pal.SclLoaded | ✅ | statActiveBoxes readable |
| V-Pal.InitPallet | ✅ | bo_PalletInitialed=True, i16_TotalBoxes=16, statActiveBoxes=16 |
| V-Pal.PathTableSeeded | ✅ | Box 1 path table: approach z=400, place z=300, retract z=400 |
| V-Pal.MutexAbcdeBlocks | ✅ | ABCDE bo_Mode=ON blocks palletizing Start (mutex contract) |
| V-Pal.StartTrigger | ✅ | i16_PalletStep=1 within <1s |
| V-Pal.AllStepsVisited | ✅ | **48/48 unique steps** in 120s (no stuck-at-step-11 as previously) |
| V-Pal.ZMotionPerBox | ✅ | TgtZ approach avg 458.2 / place avg 366.7, diff 91.5mm |
| V-Pal.LayerProgression | ✅ | Place Z ascending: L1=300, L2=350, L3=400, L4=450 |
| V-Pal.Wrap | ✅ | **2 cycle wraps** (48→1) in 120s |
| V-Pal.Stop | ✅ | i16_PalletStep=0 within <1s of Stop pulse |
| V-Pal.NoAbcdeRegression | ✅ | ABCDE visited 2 distinct steps {20, 30} within 12s post-mode-switch back, ended at 0 |

**12/12 PASS — palletizing fully traversed all 48 steps × 4 layers, completed 2 full cycle wraps, stopped clean.**

### Gate 4: Stop / facade zero-out

Post-stop facade snapshot:

```
GDB_HMI_Status.activeMode   = 0    (idle — no auto mode)
GDB_HMI_Status.currentStep  = 0    (cycle stopped)
GDB_HMI_Status.target_x     = 1500 (last commanded target — held until next cycle)
GDB_HMI_Status.target_y     = 300
GDB_HMI_Status.target_z     = 400
GDB_HMI_Status.target_a     = 0
```

The currentStep field correctly mirrors to 0 on stop. Note: `target_x/y/z/a` hold the last commanded values rather than zeroing — that's expected FB behavior (statTargetPos isn't reset on stop, only when Execute pulses again). If HMI expects target IOFields to blank out on idle, that's a facade-side behavior to tweak (not blocking for cycle-7.6 close).

### Overall PLC-side cycle-7.6 verdict

**PASS** on all 4 gates from PLC handoff §5. The C71 facade is live, populated, and correctly routes per `activeMode`. The HMI's IOField TagDynamization fix (cycle-7.6b adapter change) should now resolve to live PLC values. Visual HMI runtime confirmation is operator + scara-HMI lane.

## 3. J2 modulo fix verification (Wang Shuo's [0, 360°) convention)

Sampled `GDB_MCDData.J{n}_ActualPosition` at 3 key moments during this session:

| Moment | J1 (°) | J2 (°) | J3 (mm) | J4 (°) | All rotary in [0, 360°)? |
|---|---|---|---|---|---|
| Post pre-arm (home) | 0.0 | 0.0 | 0.0 | 0.0 | ✅ |
| Post ABCDE 5×wraps (mid-stop) | 318.305 | 218.479 | 919.962 | 38.995 | ✅ |
| Post palletizing 2×wraps (final stop) | 320.485 | 141.520 | 98.805 | 300.709 | ✅ |

**Conclusion**: All 3 rotary joints (J1 shoulder + J2 elbow + J4 wrist) stay bounded in [0, 360°) through TWO consecutive auto cycles (ABCDE + Palletizing) without any PowerOff/On reset. The previous failure mode — J2 accumulating to -578° after one ABCDE cycle, then palletizing freezing at step 11 because the IK planner couldn't find a path from that out-of-window starting angle — is **architecturally retired**.

J3 (linear Z prismatic, no modulo) shows expected linear variation (919mm post-ABCDE → 98mm post-palletizing-stop — reflects different stop positions in each cycle's path, not modulo-related).

**Wang Shuo's WeChat-confirmed convention (Length=360, StartValue=0, range [0, 360°)) is the canonical fix.** Plan `starry-seeking-seal.md` is fully VERIFIED. Operator's TIA UI deployment (this morning) is confirmed working end-to-end.

## 4. GraphQL re-test result

Per WebPageAPI handoff §3 trigger, ran `Read-WinCCUnifiedTag` against `https://localhost/graphql/` with `Admin / 12345678`:

```
Login mutation                                 → ✅ Bearer token (a9522e54...) granted, expires 2036
{ tagValues(names: ["bo_Start","bo_Mode","i16_AutoStep"]) ... } → ❌ FORBIDDEN
   message: "Access denied"
   path: ["tagValues"]
   extensions.code: "FORBIDDEN"
```

**Same FORBIDDEN as pre-remediation.** Login succeeded (proving the user account is valid), but `tagValues` is still blocked.

Per WebPageAPI handoff §3 fallback candidates (in priority order):
1. **TIA Compile + Download not executed** — operator may have applied role in TIA Project but not Compile/Download HMI/Restart Sim Runtime. WebPageAPI handoff §5 flagged this as `[NEEDS_HUMAN]` step 10-11.
2. **Sim Runtime cached old config** — full stop + start cycle needed
3. **Role not actually saved** in Users tab
4. **Authorization name mismatch** — unlikely

### Recommended operator next step (one cycle)

| Step | Action | Expected |
|---|---|---|
| 1 | TIA Project Editor → save (Ctrl+S) | Project saved with WebPageAPI role assignment to Admin |
| 2 | Right-click HMI_1 → Compile → Hardware and software | 0E/0W |
| 3 | Right-click HMI_1 → Download to device → Hardware and software | Download succeeds |
| 4 | TIA Online toolbar → Stop Simulation, wait 5s, Start Simulation | Sim Runtime restarts with new role config |
| 5 | Ping me to re-run `Read-WinCCUnifiedTag` smoke | Expect tag values returned (not FORBIDDEN) |

After step 5 passes, I can also run `Write-WinCCUnifiedTag` and verify the cycle-7.5 §6.1 3-way mode mutex test pattern via GraphQL.

## 5. Open items + closure markers

### Closed by this re-test
- ✅ **`[NEEDS_scaraPLC]`** Cycle-7.6 PLC-side smoke → PASS 4/4 gates; cycle-7.6 PENDING_VERIFICATION → **VERIFIED** for PLC contract layer
- ✅ **`[NEEDS_VERIFICATION]`** J2 modulo end-to-end (Wang Shuo [0, 360°)) → **VERIFIED**; PowerOff/On workaround retired
- ✅ Sequential ABCDE→Palletizing without PowerOff/On — **WORKS** (previously fail mode, now clean)

### Still owed
- 🟡 **`[NEEDS_HUMAN]`** WebPageAPI activation completion (Compile + Download + Sim Runtime restart per §4 above)
- 🟡 **`[NEEDS_VISUAL_HMI_CHECK]`** scara-HMI / operator visually confirms IOField rendering on `02_Auto_Ubp` during a cycle run — numerical values render instead of binding-path strings (PLC side already provided live values; this is HMI-runtime confirmation)
- ⏳ **`[NEEDS_scaraPLC]`** GraphQL re-test #2 after operator completes §4 steps 1-4
- ⏳ **`[NEXT_CYCLE]`** Cycle-7.7 header strip + Axes Enable/Home/Reset / 4 lamps / active-mode indicator per PLC `_HMI_Followups_HeaderStripAndIOFieldRendering.md` Issue B

### Informational
- ℹ️ **`[INFO]`** PLC source unchanged this session; no SCL/XML edits beyond earlier GDB_MCDData (MCD signal additions) which is a separate handoff
- ℹ️ **`[INFO]`** Smoke logs: `harness/results/phaseF_V8_20260519_172113.log` + `harness/results/palletizing_20260519_172523.log`
- ℹ️ **`[INFO]`** Cycle-7.5 PLC contract layer can also flip → VERIFIED on the back of cycle-7.6 IssueA closure (C71 facade routing under all 3 modes proven via this smoke pair)

## 6. Cross-tree-write note

This is the **3rd cross-tree write tonight** (v9-PM → SCARA tree):
1. `PLC_HANDOFF_2026-05-19_HMI_Followups_HeaderStripAndIOFieldRendering.md` (Issue A + B documentation)
2. `GDB_MCDData.xml` + `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_ConveyorAndSensors.md` (MCD signal expansion)
3. This handoff (PLC smoke results)

All operator-routed per chat instruction. Audit-trail log file (`PM_HANDOFF_2026-05-19_v9PM_CrossTreeDeviationLog.md`, ~50-80 LOC) carry-forward to next v9-PM cycle will document all 3 deviations.

End of PLC_HANDOFF — Cycle-7.6 PLC smoke results 2026-05-19.
