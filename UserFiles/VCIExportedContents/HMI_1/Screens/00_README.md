# HMI_1/Screens — Build Specifications

**Target device:** MTP1000 Unified Basic Panel 10" (6AV2123-3KB32-0AW0, 1280×800)
**HMI driver:** WinCC Unified Basic (NOT Comfort)
**Binding source-of-truth:** `../../HMI_BINDING_MAP.md`
**Operator workflow:** `../../OPERATOR_PHASE_C_HANDOFF.md`
**Plan:** Phase C — `C:\Users\Admin\.claude\plans\zazzy-mixing-hammock.md`
**Date authored:** 2026-05-17

---

## Why this directory contains markdown specs (not screen XML)

WinCC Unified Basic Panel screens are authored via TIA Portal V20's HMI screen editor (or via the HMI agent's C# Openness builder when one is established for this sibling project). External authoring of UBP screen XML is **not currently practical** for this project — no working template, and UBP `.xml` format differs from WinCC Unified Comfort (the format the HMI agent works against in `hmiDemoMomoryCapacity_v10`).

So these `.md` files are **durable build specifications**: widget-by-widget instructions that the operator (or a future HMI agent invocation for this project) follows in TIA Portal to author each screen consistently. When TIA Portal authoring completes, the VCI bi-directional sync will drop the actual `.xml` files into this directory alongside the specs.

---

## 4-screen index

| # | Screen | Spec file | Controls | Purpose |
|---|---|---|---|---|
| 1 | **Home_Screen** | [`Home_Screen.md`](Home_Screen.md) | 5 + 2 nav | Mode + InitPath + Start + Stop + step display |
| 2 | **Target_Screen** | [`Target_Screen.md`](Target_Screen.md) | 4 + 1 nav | Currently commanded TCP target (XYZA) |
| 3 | **Actual_Pos_Screen** | [`Actual_Pos_Screen.md`](Actual_Pos_Screen.md) | 4 + 1 nav | Live kinematic-group TCP position |
| 4 | **Actual_Joints_Screen** | [`Actual_Joints_Screen.md`](Actual_Joints_Screen.md) | 4 + 1 nav | Live per-joint angles |

Total: **20 controls** (15 functional IOFields/switches/buttons + 5 nav buttons), split per UBP's documented 5-control-per-screen cap. If TIA Portal compile is more permissive empirically, collapse toward fewer screens.

---

## Build order

1. **Home_Screen first** — establishes the navigation root. The other 3 screens have `btnHome` or `btnToJoints` referring back to it.
2. **Target_Screen** — once `instFB_AutoCtrl_ABCDE.statTargetPos.{x,y,z,a}` are exposed as HMI tags, this proves V6 partial (target visible).
3. **Actual_Pos_Screen** — uses `ScaraArm3D.Position[1..4]` direct from the kinematic group.
4. **Actual_Joints_Screen** — uses `J1..J4_SCARA_Arm3D.ActualPosition` per joint.

---

## Conventions (apply across all 4 screens)

### Color palette (default TIA HMI palette is fine; this is for consistency)

| Element | Color | Use |
|---|---|---|
| Background | Light gray (`#F0F0F0`) | Screen background |
| Title bar | Siemens teal (`#009999`) | Top 60px strip with screen title |
| Button (action) | Siemens green (`#76B900`) | btnStart, btnInitPath |
| Button (stop) | Siemens red (`#E60028`) | btnStop |
| Button (nav) | Light blue (`#5BA8E5`) | btnHome, btnToJoints, btnToTarget, btnToActualPos |
| IOField label | Dark gray text on white | Field labels (X:, Y:, Z:, A:, Step:) |

### Font

- Title: **Siemens Sans 24pt** (default Title font)
- Labels: **Siemens Sans 14pt**
- IOField values: **Siemens Sans 18pt monospace** (for stable digit alignment on LReal values)
- Button text: **Siemens Sans 16pt bold**

### Layout grid (1280×800)

```
+--------------------------------------------------+
| Title bar — 60px high                            |  ← y=0..60
+--------------------------------------------------+
|                                                  |
|  Main content area — 5 controls in a grid       |  ← y=80..700
|  (typical 2-column or 1-column based on screen) |
|                                                  |
+--------------------------------------------------+
| Footer — nav buttons / status, 80px high        |  ← y=720..800
+--------------------------------------------------+
```

Per-screen specs give exact x/y/width/height for each widget within this grid.

### PROFINET tag connection

All 4 screens reference PLC tags via the default PROFINET S7 connection (auto-created when PLC↔HMI link added in Phase A Step 4). Each spec lists the exact PLC-side tag path; HMI tags should be auto-discovered from the PLC via Project Tree → HMI_1 → HMI tags → Discover from PLC.

If discovery doesn't auto-populate, add HMI tags manually via HMI tags → Default tag table → New tag → set Connection = HMI_Connection_1, PLC tag = `<paste path from spec>`, Acquisition cycle = 100ms (read tags) or 0ms / event (write tags).

### PULSE button JavaScript pattern (UBP-specific)

WinCC Unified Basic does NOT support the `ToggleTag` system function. Implement PULSE buttons via JavaScript on the `Press` event:

```javascript
// Generic PULSE template — replace TAGNAME with the actual HMI tag name
HMIRuntime.Tags("TAGNAME").Write(true);
setTimeout(() => HMIRuntime.Tags("TAGNAME").Write(false), 250);
```

250ms is well within 1 PLC scan time for reliable R_TRIG rising-edge detection by `FB_AutoCtrl_ABCDE`. Used for `btnStart`, `btnStop`, `btnInitPath`.

---

## Verification checklist (apply after authoring each screen)

| # | Check | How |
|---|---|---|
| 1 | All widgets present with correct binding | Compare against spec table |
| 2 | PULSE buttons fire on press → release | Online HMI runtime → press button → Watch Table sees PLC tag flicker TRUE then FALSE within 300ms |
| 3 | IOField formats display LReal cleanly | 5.3f or similar; no overflow or NaN |
| 4 | Nav buttons land on the intended screen | Click each nav button in runtime → verify screen change |
| 5 | Screen compiles 0W/0E | TIA Portal → right-click HMI_1 → Compile → only changes |

V6 verification (target position display) passes when **Target_Screen** has all 4 IOFields binding correctly to `instFB_AutoCtrl_ABCDE.statTargetPos.{x,y,z,a}` and they update live during a Phase D smoke-test cycle.
