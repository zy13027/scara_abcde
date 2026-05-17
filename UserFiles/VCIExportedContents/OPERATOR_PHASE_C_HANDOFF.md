# OPERATOR_PHASE_C_HANDOFF — TIA Portal HMI Screen Authoring

**Project:** `hmiDemoSCARA_ABCDE`
**Plan:** `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md` (Phase C)
**Predecessor:** Phase D PASSED 9/9 gates 2026-05-17 + Phase F V8 PASSED 5/5 gates 2026-05-17
**Date:** 2026-05-17
**Status:** READY FOR OPERATOR (or HMI agent) — 4 screen specs staged on disk; TIA Portal HMI screen editor work needed
**Verification gate covered:** **V6** (target position display) + partial V7 (live TCP visible)

---

## Why this handoff exists

PLC side is fully verified end-to-end on PLCSIM-Adv: Phase D 9/9 + Phase F V8 5/5 (commits `79cae9a` + `c2d4f86`). The SCARA cycles ABCDE continuously with blending; cycle count 5 wraps in 45s; 0% standstill samples. PLC half of the plan goal #1 is **DONE**.

What remains for plan goal #2 ("HMI shows current target position XYZA"): the 4 MTP1000 UBP screens need to be authored in TIA Portal. This handoff lists the manual TIA UI steps + verification checklist.

**Authoring is currently manual** (UBP screen XML format is not Openness-friendly for this project's tooling state). The per-screen specs in `HMI_1/Screens/*.md` give widget-by-widget detail; this doc covers the cross-screen workflow.

---

## What's already on disk

```
E:/TIA_Project_Directory_V20/hmiDemoSCARA_ABCDE/UserFiles/VCIExportedContents/
├── HMI_BINDING_MAP.md                 ← canonical widget→tag mapping (PLC-side source of truth)
├── HMI_1/
│   └── Screens/
│       ├── 00_README.md               ← index + cross-screen conventions (colors, fonts, JS PULSE pattern)
│       ├── Home_Screen.md             ← spec for screen 1 (Mode + InitPath + Start + Stop + step)
│       ├── Target_Screen.md           ← spec for screen 2 (target XYZA 4 IOFields + nav)
│       ├── Actual_Pos_Screen.md       ← spec for screen 3 (live TCP XYZA 4 IOFields + nav)
│       └── Actual_Joints_Screen.md    ← spec for screen 4 (joint angles J1..J4 + nav)
└── OPERATOR_PHASE_C_HANDOFF.md        ← this file (workflow + verification)
```

Each spec contains: a layout sketch, a numbered widget table (with type / position / binding / properties), JS Press event code for PULSE buttons, expected values per cycle step, build sequence in TIA Portal, and acceptance criteria.

---

## Prerequisites — verify before starting

1. **TIA Portal V20 open** with `hmiDemoSCARA_ABCDE.ap20` project loaded
2. **HMI_1 device added** in Phase A Step 3 (MTP1000 Unified Basic, 6AV2123-3KB32-0AW0)
3. **PROFINET PLC↔HMI link** established in Phase A Step 4
4. **PLC compile 0W/0E** with FB_AutoCtrl_ABCDE rev 3.0 already downloaded (Phase D + F passed)
5. **PLCSIM-Adv `1511T_ABCDE` at 192.168.0.5** running in RUN (so HMI runtime can read live tags)

If any of these fail, complete Phase A first (see `OPERATOR_PHASE_A_HANDOFF.md`).

---

## 6-step TIA Portal workflow

### Step 1 — Verify HMI tag table is auto-populated (or manually add)

1. Project tree → HMI_1 → HMI tags → Default tag table → open
2. Verify these PLC tags are reachable (right-click tag table → "Discover from PLC" if empty):
   - `GDB_MachineCmd.bo_Mode` (W Bool, used by swModeAuto)
   - `GDB_MachineCmd.bo_InitPath` (W Bool, used by btnInitPath PULSE)
   - `GDB_MachineCmd.bo_Start` (W Bool, used by btnStart PULSE)
   - `GDB_MachineCmd.bo_Stop` (W Bool, used by btnStop PULSE)
   - `GDB_MachineCmd.i16_AutoStep` (R Int16, used by txtAutoStep)
   - `instFB_AutoCtrl_ABCDE.statTargetPos.x` (R LReal, used by txtTargetX) — and .y/.z/.a
   - `ScaraArm3D.Position[1..4]` (R LReal × 4, used by txtActualX/Y/Z/A)
   - `J1_SCARA_Arm3D.ActualPosition` (R LReal) — through `J4_..` (used by txtJoint1-4)

If auto-discovery missed any, add manually: New tag → Connection = HMI_Connection_1, PLC tag = `<paste path>`, Acquisition cycle = 100ms (reads) or 0ms / event (writes).

**Expected tag count:** ~17 HMI tags (4 W Bool + 1 W Bool + 1 R Int + 4 R LReal target + 4 R LReal actual + 4 R LReal joints = 17 incl. duplicates resolved). Actual count varies based on whether TIA collapses array-index tags to a single base tag.

---

### Step 2 — Author Home_Screen (root navigation)

Follow `HMI_1/Screens/Home_Screen.md` build sequence:

1. Right-click HMI_1 → Screens → Add new screen → name `Home_Screen`
2. Set as start screen: HMI_1 → Runtime settings → Start screen = `Home_Screen`
3. Build all 5 functional controls + 2 nav buttons + 4 static labels per the spec's widget table
4. Paste the JS Press event code for `btnInitPath`, `btnStart`, `btnStop` (3 PULSE buttons)
5. Save (Ctrl+S)

Estimated time: ~20 min for first screen (slower while learning UBP authoring quirks).

---

### Step 3 — Author Target_Screen (V6 gate screen)

Follow `HMI_1/Screens/Target_Screen.md`:

1. Add new screen → name `Target_Screen`
2. Build 4 IOFields + 1 nav button per the spec
3. **Critical**: Process binding for the 4 IOFields must be `instFB_AutoCtrl_ABCDE.statTargetPos.x/y/z/a` (instance DB direct access). If TIA refuses the dotted path, the iDB must be marked "Accessible from HMI" in Properties → Attributes; toggle ON if needed.
4. Save

Estimated time: ~10 min.

---

### Step 4 — Author Actual_Pos_Screen

Follow `HMI_1/Screens/Actual_Pos_Screen.md`:

1. Add new screen → name `Actual_Pos_Screen`
2. Build 4 IOFields + 1 nav button per the spec
3. Primary binding: `ScaraArm3D.Position[1..4]` (TO array indexed [1..6], use [1..4] for X/Y/Z/A)
4. **Fallback** if TIA refuses TO direct access: use `GDB_MCDData.Position[1..4]` (mirror published by FB_MCDDataTransfer.scl)
5. Save

Estimated time: ~10 min.

---

### Step 5 — Author Actual_Joints_Screen

Follow `HMI_1/Screens/Actual_Joints_Screen.md`:

1. Add new screen → name `Actual_Joints_Screen`
2. Build 4 IOFields + 1 nav button per the spec
3. Primary binding: `J1_SCARA_Arm3D.ActualPosition` through `J4_SCARA_Arm3D.ActualPosition`
4. Save

Estimated time: ~10 min.

---

### Step 6 — Compile HMI_1 + download to runtime + smoke test

1. Right-click HMI_1 → **Compile → Software (only changes)** → expect 0W/0E
2. Right-click HMI_1 → **Download to device** → select Runtime (or panel if hardware connected)
3. Start the runtime
4. Walk through acceptance criteria for each screen (see individual specs' "Acceptance criteria" tables)

Estimated time: ~15 min compile + download + walkthrough.

**Grand total Phase C time estimate: ~75 min** (1.25 hrs — under the plan's 1.5 hr Phase C estimate).

---

## Cross-cutting acceptance criteria — V6 + partial V7

When all 4 screens are authored and the HMI runtime is connected to PLCSIM-Adv with the cycle running, this combined behavior must hold:

| # | Test | How | Pass when |
|---|---|---|---|
| **C1** | All 4 screens compile + load | TIA HMI compile + runtime start | 0W/0E + 4 screens accessible |
| **C2** | Home_Screen is start screen | Runtime start | Home_Screen visible without nav click |
| **C3** | btnInitPath fires `bo_PathInitialed` | Click btnInitPath on Home; check `GDB_MachineCmd.bo_PathInitialed` in Watch | Goes TRUE within 1 PLC scan; stays TRUE |
| **C4** | btnStart kicks state machine | Click btnStart on Home; check `i16_AutoStep` | Jumps 0→10 within 1 PLC scan (**V2 ✓**) |
| **C5** | txtAutoStep tracks step | Watch txtAutoStep during cycle | Shows 10, 20, 30, 40, 50, 10... in real time |
| **C6** | Target_Screen IOFields show target | Nav to Target_Screen during cycle | All 4 IOFields display non-zero, cycling per step (**V6 ✓**) |
| **C7** | Actual_Pos_Screen shows live TCP | Nav to Actual_Pos_Screen during cycle | All 4 IOFields update in real time (**V7 partial ✓**) |
| **C8** | Actual_Joints_Screen shows joints | Nav to Actual_Joints_Screen during cycle | J1, J2 actively swing; J3 stays at ~-30; J4 stays at ~0 |
| **C9** | btnStop halts cycle | Click btnStop during cycle | `i16_AutoStep` becomes 0 within 1 PLC scan (**V5 ✓**) |
| **C10** | Navigation between screens works | Click each nav button | Lands on the intended screen |

When C1-C10 all pass, **Phase C is COMPLETE** and **plan goal #2 (HMI shows current target position) is DONE**.

---

## Common issues + diagnosis

| Symptom | Cause | Fix |
|---|---|---|
| HMI compile error "Tag instFB_AutoCtrl_ABCDE.statTargetPos.x not found" | iDB not marked HMI-accessible | Project tree → iDB → Properties → Attributes → "Accessible from HMI" → ON |
| HMI compile error "Tag ScaraArm3D.Position[1] not found" | TO direct access not enabled | Either enable TO HMI access OR use fallback `GDB_MCDData.Position[1]` mirror |
| btnInitPath / btnStart / btnStop has no effect at runtime | JS PULSE didn't execute (UBP runtime might block setTimeout) | Test JS in browser console first; if setTimeout blocked, use TIA's built-in pulse system function instead via Press↑ + Release↓ events |
| HMI tag table doesn't auto-populate from PLC | PLC compile out of sync | Recompile PLC; right-click HMI tags → Update from PLC |
| txtAutoStep shows "??" or static value | Acquisition cycle too long | Set to 100ms (was probably 1000ms or "On change") |
| Screen runs but no live updates | Runtime not connected to PLCSIM-Adv | Check Runtime settings → Communications → Connection state = Online; if not, verify PLC sim is in RUN at IP 192.168.0.5 |
| 5-control-per-screen warning on Home_Screen | UBP enforcement caught the +2 nav buttons | Move btnToTarget + btnToActualPos to status bar as small overlay icons (don't count toward 5-cap), or split Home into 2 screens |

---

## Optional: HMI agent invocation pattern

If you'd rather have an HMI agent author these screens via Openness rather than manual TIA UI work:

1. **Confirm HMI agent applicable to this sibling project.** The v9 HMI agent at `E:\VS_Code_Proj\TiaUnifiedAuto\` is configured for `hmiDemoMomoryCapacity_v10` (Unified Comfort). It would need adaptation for MTP1000 UBP (Unified Basic) screen format.
2. **If adapting:** add a new project profile to the C# builder targeting this project's `.ap20` path + UBP screen XML schema. Significant effort — likely 1-2 cycles of HMI agent work.
3. **Simpler path:** complete Phase C manually here (~75 min) and defer HMI agent invocation until a separate request for advanced features (multilingual / animations / recipe screens).

For now, the manual workflow above is the recommended fastest path to V6 gate passage.

---

## After Phase C success

Once C1-C10 all pass and HMI is verified live:

1. **Update PROJECT_STATUS.md**: Phase C row → ✅; V6 row → ✅; V7 partial → 🚧 (full V7 still needs Phase E NX MCD)
2. **Optional cross-agent handoff**: if HMI agent invoked later for this project, drop a `PLC_HANDOFF_<date>_PhaseC_Complete.md` for them noting which tags they can consume
3. **Plan goals progress:**
   - ✅ Goal 1: ABCDE 5-point continuous cycle (Phase D + F)
   - ✅ Goal 2: HMI shows current target position XYZA (Phase C, this handoff)
   - ⏸️ Goal 3: NX MCD auto-connects on PLC startup (Phase E, separate cycle)

---

## Cross-references

- `HMI_BINDING_MAP.md` — canonical widget-to-tag binding (PLC-side source of truth)
- `HMI_1/Screens/00_README.md` — cross-screen conventions (colors, fonts, JS PULSE pattern)
- `HMI_1/Screens/Home_Screen.md` — screen 1 detailed build spec
- `HMI_1/Screens/Target_Screen.md` — screen 2 detailed build spec (V6 gate)
- `HMI_1/Screens/Actual_Pos_Screen.md` — screen 3 detailed build spec
- `HMI_1/Screens/Actual_Joints_Screen.md` — screen 4 detailed build spec
- `OPERATOR_PHASE_F_HANDOFF.md` — predecessor (V8 blending; complete)
- `PROJECT_STATUS.md` — phase + gate status board
- `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md` — full plan (Phase C details in "Phase C — HMI screens" section)
