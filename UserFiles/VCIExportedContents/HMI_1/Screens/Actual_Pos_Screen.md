# Actual_Pos_Screen — Build Spec

**Order in cycle:** 3rd screen (source spec §4.3 first half — live TCP position from kinematic group)
**Resolution:** 1280×800 (MTP1000 UBP)
**Widget count:** 4 IOFields + 1 nav = **5 controls** (at UBP 5-cap)
**Source-spec verification gate:** **V7** partial (live position visible; full V7 also needs MCD)

---

## Layout (1280×800)

```
+-------------------------------------------------------------+
| [Title bar — teal #009999, white text, 60px high]           |
|   "Actual TCP Position — Live from Kinematic Group"         |
+-------------------------------------------------------------+
|                                                             |
|   +-----------------+    +-----------------+                |
|   | X (mm):         |    | Y (mm):         |                |
|   | [ txtActualX ]  |    | [ txtActualY ]  |                |
|   | x=80 y=140      |    | x=680 y=140     |                |
|   | w=520 h=180     |    | w=520 h=180     |                |
|   +-----------------+    +-----------------+                |
|                                                             |
|   +-----------------+    +-----------------+                |
|   | Z (mm):         |    | A (deg):        |                |
|   | [ txtActualZ ]  |    | [ txtActualA ]  |                |
|   | x=80 y=380      |    | x=680 y=380     |                |
|   | w=520 h=180     |    | w=520 h=180     |                |
|   +-----------------+    +-----------------+                |
|                                                             |
+-------------------------------------------------------------+
| [Footer — light blue nav, 80px high]                        |
|         [btnToJoints]                                       |
|         x=440 y=720                                         |
|         w=400 h=70                                          |
+-------------------------------------------------------------+
```

Visually identical to `Target_Screen.md` — operator can mentally compare "target vs actual" by toggling between the two screens. Difference: this one is bound to the live TCP, that one to the commanded setpoint.

---

## Widget table (build in this order)

| # | Widget name | Type | Position (x,y,w,h) | Binding (PLC tag) | R/W | Properties |
|---|---|---|---|---|---|---|
| 1 | `txtActualX` | IOField (Output only, Decimal LReal) | 80, 220, 520, 100 | `ScaraArm3D.Position[1]` | R LReal | Format: 9999.99. Font: monospace 36pt. Foreground dark green. Acquisition cycle: 100ms. |
| 2 | `txtActualY` | IOField (Output only, Decimal LReal) | 680, 220, 520, 100 | `ScaraArm3D.Position[2]` | R LReal | Format: 9999.99. Font: monospace 36pt. Foreground dark green. Acquisition cycle: 100ms. |
| 3 | `txtActualZ` | IOField (Output only, Decimal LReal) | 80, 460, 520, 100 | `ScaraArm3D.Position[3]` | R LReal | Format: 9999.99. Font: monospace 36pt. Foreground dark green. Acquisition cycle: 100ms. |
| 4 | `txtActualA` | IOField (Output only, Decimal LReal) | 680, 460, 520, 100 | `ScaraArm3D.Position[4]` | R LReal | Format: 999.99. Font: monospace 36pt. Foreground dark green. Acquisition cycle: 100ms. |
| 5 | `btnToJoints` | Button | 440, 720, 400, 70 | (system function) | — | Text: "→ Joint Angles". Background light blue #5BA8E5. Foreground white. Font 16pt bold. **Click event** → `ActivateScreen("Actual_Joints_Screen")`. |

**Tag-binding note:** `ScaraArm3D.Position[1..4]` is the kinematic-group's WCS TCP position published by the TO directly (TO_Kinematics auto-exposes a 6-element `Position` array indexed [1..6]; we use [1..4] for X/Y/Z/A and ignore [5][6] per UBP 5-cap pruning). If TIA HMI tag discovery doesn't auto-find `ScaraArm3D.Position[1..4]` (TO tags sometimes require explicit subscription), use the mirror published by FB_MCDDataTransfer instead: `GDB_MCDData.Position[1..4]` (LReal mirror, same values).

---

## Static labels (decorative — not counted toward 5-cap)

| Label | Position | Text | Font |
|---|---|---|---|
| L1 | 80, 140, 520, 60 | "X (mm):" | 24pt gray |
| L2 | 680, 140, 520, 60 | "Y (mm):" | 24pt gray |
| L3 | 80, 380, 520, 60 | "Z (mm):" | 24pt gray |
| L4 | 680, 380, 520, 60 | "A (deg):" | 24pt gray |
| Title | 0, 0, 1280, 60 | "Actual TCP Position — Live from Kinematic Group" | 24pt white on teal |

Color coding (dark green for actual, dark blue for target — see Target_Screen.md) helps operator distinguish at-a-glance.

---

## Expected values during cycle

The actual TCP position should **converge toward** the current step's target (compare against the table in Target_Screen.md). Difference between actual + target is the **remaining distance** at any moment:

- Just after step change → actual position is ~ the previous target → diff is large (~300mm)
- Mid-motion → actual halfway between previous and current target → diff ~ half
- At step end (under V8 blending, when statProgress > 0.5) → next step starts; this screen shows blended path

V8 blending behavior is visible here: when running with blending mode (Phase F), the actual position **never stops moving** between steps — it always has nonzero velocity in transit.

---

## Build sequence in TIA Portal

1. Project tree → HMI_1 → Screens → right-click → **Add new screen** → name `Actual_Pos_Screen`
2. Drag title rectangle (#009999) 0/0/1280/60 + static text "Actual TCP Position — Live from Kinematic Group"
3. For each widget #1-5 in the table above:
   - Drag the widget type from the Toolbox
   - Set Position + Size per spec
   - For IOField (#1-4): set Mode = Output only; set Process binding (try `ScaraArm3D.Position[N]` first, fall back to `GDB_MCDData.Position[N]` if TIA refuses TO direct binding)
   - For btnToJoints (#5): set Events → Click → System functions → ActivateScreen → "Actual_Joints_Screen"
4. Add static labels L1-L4 per the table
5. Save the screen (Ctrl+S)
6. Compile HMI_1 (right-click → Compile → Software (only changes))

---

## Acceptance criteria

| # | Test | Pass when |
|---|---|---|
| AP1 | Screen loads from Home navigation | Click btnToActualPos on Home → Actual_Pos_Screen displays |
| AP2 | All 4 IOFields display live (non-frozen) values | Idle: shows current resting TCP position (~ home pose); during cycle: continuously updating |
| AP3 | X/Y/Z/A change in real-time during cycle | Operator sees values walk between targets (e.g., X going 1500 → 1800 as step advances 40→50) |
| AP4 | A stays near 0.00 (per the plan's hardcoded A=0 in pts[1..5]) | Constant ~0.00 +/- numerical noise |
| AP5 | Z stays near 400.00 | Constant 400 +/- noise (planar SCARA = no Z motion) |
| AP6 | At cycle end, position matches target's expected value table | After 1 cycle, actual converges to target's E coords (1800, -300, 400, 0) before wrapping to A |
| AP7 | `btnToJoints` navigates correctly | Click btnToJoints → Actual_Joints_Screen displays |
| AP8 | HMI compile passes 0W/0E | TIA Portal compile reports zero warnings/errors |

**V7 partial passes when AP2-AP3 pass** (live TCP visible). Full V7 also requires Phase E (NX MCD) to confirm the kinematic group is solving correctly end-to-end.
