# Actual_Joints_Screen — Build Spec

**Order in cycle:** 4th screen (source spec §4.3 second half — per-axis joint angles)
**Resolution:** 1280×800 (MTP1000 UBP)
**Widget count:** 4 IOFields + 1 nav = **5 controls** (at UBP 5-cap)
**Source-spec verification gate:** Per-joint visibility for operator + commissioning debug

---

## Layout (1280×800)

```
+-------------------------------------------------------------+
| [Title bar — teal #009999, white text, 60px high]           |
|   "Joint Angles — Live per-axis from TO_PositioningAxis"    |
+-------------------------------------------------------------+
|                                                             |
|   +-----------------+    +-----------------+                |
|   | J1 (deg):       |    | J2 (deg):       |                |
|   | [ txtJoint1 ]   |    | [ txtJoint2 ]   |                |
|   | (base shoulder) |    | (elbow)         |                |
|   | x=80 y=140      |    | x=680 y=140     |                |
|   | w=520 h=180     |    | w=520 h=180     |                |
|   +-----------------+    +-----------------+                |
|                                                             |
|   +-----------------+    +-----------------+                |
|   | J3 (mm):        |    | J4 (deg):       |                |
|   | [ txtJoint3 ]   |    | [ txtJoint4 ]   |                |
|   | (prismatic Z)   |    | (wrist)         |                |
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

The 4 IOFields show what the per-axis TO_PositioningAxis reports — these are what the inverse kinematic solver derived from the WCS target. Cross-checking these against the TCP position on Actual_Pos_Screen is a useful debug for confirming the kinematic solver is correct.

---

## Widget table (build in this order)

| # | Widget name | Type | Position (x,y,w,h) | Binding (PLC tag) | R/W | Properties |
|---|---|---|---|---|---|---|
| 1 | `txtJoint1` | IOField (Output only, Decimal LReal) | 80, 220, 520, 100 | `J1_SCARA_Arm3D.ActualPosition` | R LReal | Format: 999.99 (deg, signed). Font: monospace 36pt. Foreground dark orange. Acquisition cycle: 100ms. |
| 2 | `txtJoint2` | IOField (Output only, Decimal LReal) | 680, 220, 520, 100 | `J2_SCARA_Arm3D.ActualPosition` | R LReal | Format: 999.99 (deg, signed). Font: monospace 36pt. Foreground dark orange. Acquisition cycle: 100ms. |
| 3 | `txtJoint3` | IOField (Output only, Decimal LReal) | 80, 460, 520, 100 | `J3_SCARA_Arm3D.ActualPosition` | R LReal | Format: 9999.99 (mm, signed — prismatic). Font: monospace 36pt. Foreground dark orange. Acquisition cycle: 100ms. |
| 4 | `txtJoint4` | IOField (Output only, Decimal LReal) | 680, 460, 520, 100 | `J4_SCARA_Arm3D.ActualPosition` | R LReal | Format: 999.99 (deg, signed — wrist rotation). Font: monospace 36pt. Foreground dark orange. Acquisition cycle: 100ms. |
| 5 | `btnHome` | Button | 440, 720, 400, 70 | (system function) | — | Text: "← Home". Background light blue #5BA8E5. Foreground white. Font 16pt bold. **Click event** → `ActivateScreen("Home_Screen")`. |

**Tag-binding fallback:** If TIA refuses direct binding to `J1..J4_SCARA_Arm3D.ActualPosition` (TO axis tags sometimes need explicit subscription), use the mirror published by FB_MCDDataTransfer: `GDB_MCDData.Position[1..4]` does NOT contain joint angles — it contains TCP. For joint angles via mirror, FB_MCDDataTransfer would need to publish `J1..J4.ActualPosition → GDB_MCDData.JointPos[1..4]` (currently NOT done — add only if direct TO binding fails). **Try direct binding first** — TO_PositioningAxis tags usually expose fine through PROFINET to HMI.

---

## Static labels (decorative — not counted toward 5-cap)

| Label | Position | Text | Font |
|---|---|---|---|
| L1 | 80, 140, 520, 60 | "J1 (deg) — Base shoulder" | 20pt gray |
| L2 | 680, 140, 520, 60 | "J2 (deg) — Elbow" | 20pt gray |
| L3 | 80, 380, 520, 60 | "J3 (mm) — Prismatic Z" | 20pt gray |
| L4 | 680, 380, 520, 60 | "J4 (deg) — Wrist rotation" | 20pt gray |
| Title | 0, 0, 1280, 60 | "Joint Angles — Live per-axis from TO_PositioningAxis" | 24pt white on teal |

Color coding (dark orange for joints — distinguishes from blue/green of TCP target/actual).

---

## Expected values during cycle

The 4 joint values depend on the SCARA's inverse kinematic solution for each TCP target. Approximate expected ranges for the hardcoded `pts[1..5]` (within the 1150mm+1200mm arm workspace):

| Step | Target | J1 (deg, ~) | J2 (deg, ~) | J3 (mm) | J4 (deg) |
|---|---|---|---|---|---|
| Home / Idle | (resting) | ~0 | ~30 | ~-30 | ~0 |
| 10 (A: 1800/0/400) | extended forward | small | small | -30 | 0 |
| 20 (B: 1800/300/400) | extended forward+left | small + | mid | -30 | 0 |
| 30 (C: 1500/300/400) | closer + left | larger | larger | -30 | 0 |
| 40 (D: 1500/-300/400) | closer + right | larger - | mirror of step 30 | -30 | 0 |
| 50 (E: 1800/-300/400) | extended + right | small - | mirror of step 20 | -30 | 0 |

Exact values depend on which IK branch the solver picks (left-elbow vs right-elbow). Operator uses these screens to confirm:
- All 4 joints actively move (none stuck at zero)
- Values stay within axis dynamic limits (no fault state)
- J3 stays at -30mm (Z is planar — no prismatic motion needed for ABCDE @ Z=400 + Z-home=-30)
- J4 stays at 0deg (A is constant 0 across all 5 points)

---

## Build sequence in TIA Portal

1. Project tree → HMI_1 → Screens → right-click → **Add new screen** → name `Actual_Joints_Screen`
2. Drag title rectangle (#009999) 0/0/1280/60 + static text "Joint Angles — Live per-axis from TO_PositioningAxis"
3. For each widget #1-5 in the table above:
   - Drag the widget type from the Toolbox
   - Set Position + Size per spec
   - For IOField (#1-4): set Mode = Output only; set Process binding to listed PLC tag (`J1_SCARA_Arm3D.ActualPosition`, etc.)
   - For btnHome (#5): set Events → Click → System functions → ActivateScreen → "Home_Screen"
4. Add static labels L1-L4 per the table
5. Save the screen (Ctrl+S)
6. Compile HMI_1 (right-click → Compile → Software (only changes))

---

## Acceptance criteria

| # | Test | Pass when |
|---|---|---|
| AJ1 | Screen loads from ActualPos navigation | Click btnToJoints on Actual_Pos_Screen → Actual_Joints_Screen displays |
| AJ2 | All 4 IOFields display live (non-frozen) values | Idle: shows current resting joint pose; during cycle: continuously updating |
| AJ3 | J1, J2 swing across cycle (active) | Visible movement of J1 + J2 as TCP moves between A-E |
| AJ4 | J3 stays at constant ~-30mm | No vertical motion (planar ABCDE) |
| AJ5 | J4 stays at constant ~0deg | No wrist motion (constant A=0) |
| AJ6 | No joint shows a fault value (NaN, ±Inf, suspicious huge spike) | Values are bounded by axis dynamic limits |
| AJ7 | `btnHome` navigates back | Click btnHome → Home_Screen displays |
| AJ8 | HMI compile passes 0W/0E | TIA Portal compile reports zero warnings/errors |

---

## Cross-reference: full nav cycle

After this screen authoring, the operator has 4 screens with bidirectional navigation:

```
   Home_Screen ⟷ Target_Screen
       ↓ ↑
   Actual_Pos_Screen ⟷ Actual_Joints_Screen
       ↑
       └─→ btnHome on Actual_Joints loops back to Home
```

Actually: Home has 2 forward links (btnToTarget, btnToActualPos); Target has btnHome; Actual_Pos has btnToJoints; Actual_Joints has btnHome.

So the navigation forms a "Y": Home → Target (back to Home via btnHome) **and** Home → Actual_Pos → Actual_Joints (back to Home via btnHome). No back-link from Actual_Joints → Actual_Pos (operator goes Home first). If the operator wants Actual_Joints → Actual_Pos directly, swap `btnHome` for `btnToActualPos` here.
