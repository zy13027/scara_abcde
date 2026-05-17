# Target_Screen — Build Spec

**Order in cycle:** 2nd screen (source spec §4.2 — current commanded target visible to operator)
**Resolution:** 1280×800 (MTP1000 UBP)
**Widget count:** 4 IOFields + 1 nav = **5 controls** (at UBP 5-cap)
**Source-spec verification gate:** **V6** (target position display)

---

## Layout (1280×800)

```
+-------------------------------------------------------------+
| [Title bar — teal #009999, white text, 60px high]           |
|   "Current Target Position — TCP Setpoint"                  |
+-------------------------------------------------------------+
|                                                             |
|   +-----------------+    +-----------------+                |
|   | X (mm):         |    | Y (mm):         |                |
|   | [ txtTargetX ]  |    | [ txtTargetY ]  |                |
|   | x=80 y=140      |    | x=680 y=140     |                |
|   | w=520 h=180     |    | w=520 h=180     |                |
|   +-----------------+    +-----------------+                |
|                                                             |
|   +-----------------+    +-----------------+                |
|   | Z (mm):         |    | A (deg):        |                |
|   | [ txtTargetZ ]  |    | [ txtTargetA ]  |                |
|   | x=80 y=380      |    | x=680 y=380     |                |
|   | w=520 h=180     |    | w=520 h=180     |                |
|   +-----------------+    +-----------------+                |
|                                                             |
+-------------------------------------------------------------+
| [Footer — light blue nav, 80px high]                        |
|         [btnHome]                                           |
|         x=440 y=720                                         |
|         w=400 h=70                                          |
+-------------------------------------------------------------+
```

The 4 IOField boxes are large (520×180) so the LReal values are clearly visible from across a control room. Each "box" contains: a label "X (mm):" at the top, then the IOField on the bottom showing the value in a big font.

---

## Widget table (build in this order)

| # | Widget name | Type | Position (x,y,w,h) | Binding (PLC tag) | R/W | Properties |
|---|---|---|---|---|---|---|
| 1 | `txtTargetX` | IOField (Output only, Decimal LReal) | 80, 220, 520, 100 | `instFB_AutoCtrl_ABCDE.statTargetPos.x` | R LReal | Format: 9999.99 (signed, 2 decimal places). Font: monospace 36pt. Foreground dark blue. Acquisition cycle: 100ms. |
| 2 | `txtTargetY` | IOField (Output only, Decimal LReal) | 680, 220, 520, 100 | `instFB_AutoCtrl_ABCDE.statTargetPos.y` | R LReal | Format: 9999.99. Font: monospace 36pt. Foreground dark blue. Acquisition cycle: 100ms. |
| 3 | `txtTargetZ` | IOField (Output only, Decimal LReal) | 80, 460, 520, 100 | `instFB_AutoCtrl_ABCDE.statTargetPos.z` | R LReal | Format: 9999.99. Font: monospace 36pt. Foreground dark blue. Acquisition cycle: 100ms. |
| 4 | `txtTargetA` | IOField (Output only, Decimal LReal) | 680, 460, 520, 100 | `instFB_AutoCtrl_ABCDE.statTargetPos.a` | R LReal | Format: 999.99 (degree, signed, 2 dp). Font: monospace 36pt. Foreground dark blue. Acquisition cycle: 100ms. |
| 5 | `btnHome` | Button | 440, 720, 400, 70 | (system function) | — | Text: "← Home". Background light blue #5BA8E5. Foreground white. Font 16pt bold. **Click event** → `ActivateScreen("Home_Screen")`. |

---

## Static labels (decorative — not counted toward 5-cap)

| Label | Position | Text | Font |
|---|---|---|---|
| L1 | 80, 140, 520, 60 | "X (mm):" | 24pt gray |
| L2 | 680, 140, 520, 60 | "Y (mm):" | 24pt gray |
| L3 | 80, 380, 520, 60 | "Z (mm):" | 24pt gray |
| L4 | 680, 380, 520, 60 | "A (deg):" | 24pt gray |
| Title | 0, 0, 1280, 60 | "Current Target Position — TCP Setpoint" | 24pt white on teal |

---

## Expected values per cycle step

Per the hardcoded `pts[1..5]` in `FB_AutoCtrl_ABCDE.scl` (rev 3.0, V8 blending):

| Step | Point | X (mm) | Y (mm) | Z (mm) | A (deg) |
|---|---|---|---|---|---|
| 10 | A | 1800.00 | 0.00 | 400.00 | 0.00 |
| 20 | B | 1800.00 | 300.00 | 400.00 | 0.00 |
| 30 | C | 1500.00 | 300.00 | 400.00 | 0.00 |
| 40 | D | 1500.00 | -300.00 | 400.00 | 0.00 |
| 50 | E | 1800.00 | -300.00 | 400.00 | 0.00 |

Operator visually verifies: as the cycle advances 10→20→30→40→50, the 4 IOFields walk through these values. V6 gate passes when **observed values match expected for at least 1 complete cycle**.

---

## Build sequence in TIA Portal

1. Project tree → HMI_1 → Screens → right-click → **Add new screen** → name `Target_Screen`
2. Drag title rectangle (#009999) 0/0/1280/60 + static text "Current Target Position — TCP Setpoint"
3. For each widget #1-5 in the table above:
   - Drag the widget type from the Toolbox
   - Set Position + Size per spec
   - For IOField (#1-4): set Mode = Output only; set Process binding to listed PLC tag; set Display format
   - For btnHome (#5): set Events → Click → System functions → ActivateScreen → "Home_Screen"
4. Add static labels L1-L4 per the table
5. Save the screen (Ctrl+S)
6. Compile HMI_1 (right-click → Compile → Software (only changes))

---

## Acceptance criteria — covers V6 gate

| # | Test | Pass when |
|---|---|---|
| T1 | Screen loads from Home navigation | Click btnToTarget on Home → Target_Screen displays |
| T2 | All 4 IOFields display non-zero values (during cycle) | After btnStart, IOFields show actual coordinates per current step |
| T3 | X cycles 1800 → 1800 → 1500 → 1500 → 1800 across steps 10→20→30→40→50 | Visually walk through one cycle; coords match expected table |
| T4 | Y cycles 0 → 300 → 300 → -300 → -300 across steps | Same |
| T5 | Z stays at 400.00 throughout cycle | Same |
| T6 | A stays at 0.00 throughout cycle | Same |
| T7 | `btnHome` navigates back | Click btnHome → Home_Screen displays |
| T8 | HMI compile passes 0W/0E | TIA Portal compile reports zero warnings/errors |

**V6 gate passes when T2-T6 all pass** (target position displayed correctly across at least 1 full cycle).
