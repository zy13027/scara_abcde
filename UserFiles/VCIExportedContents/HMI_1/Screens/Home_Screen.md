# Home_Screen — Build Spec

**Order in cycle:** 1st screen (root navigation)
**Resolution:** 1280×800 (MTP1000 UBP)
**Default screen at runtime start:** YES (set HMI_1 → Runtime settings → Start screen = `Home_Screen`)
**Widget count:** 5 functional + 2 nav = **7 controls** (over docs 5-cap; collapse `btnToTarget`/`btnToActualPos` to status-bar overlay if needed)

---

## Layout (1280×800)

```
+-------------------------------------------------------------+
| [Title bar — teal #009999, white text, 60px high]           |
|   "SCARA ABCDE — Home"                                      |
+-------------------------------------------------------------+
|                                                             |
|   +-------------------+    +---------------------+          |
|   | swModeAuto        |    | txtAutoStep         |          |
|   | [ Auto / Manual ] |    |  Step: [  10  ]     |          |
|   | x=80 y=120        |    | x=720 y=120         |          |
|   | w=400 h=80        |    | w=420 h=80          |          |
|   +-------------------+    +---------------------+          |
|                                                             |
|   +-------------------+    +-------------------+            |
|   | btnInitPath       |    | btnStart          |            |
|   |  "Init Path"      |    |  "START"          |            |
|   | green #76B900     |    | green #76B900     |            |
|   | x=80 y=260        |    | x=520 y=260       |            |
|   | w=380 h=100       |    | w=380 h=100       |            |
|   +-------------------+    +-------------------+            |
|                                                             |
|                            +-------------------+            |
|                            | btnStop           |            |
|                            |  "STOP"           |            |
|                            | red #E60028       |            |
|                            | x=520 y=400       |            |
|                            | w=380 h=100       |            |
|                            +-------------------+            |
|                                                             |
+-------------------------------------------------------------+
| [Footer — light blue nav, 80px high]                        |
|   [btnToTarget] [btnToActualPos]                            |
|    x=80 y=720    x=440 y=720                                |
|    w=320 h=70    w=320 h=70                                 |
+-------------------------------------------------------------+
```

---

## Widget table (build in this order)

| # | Widget name | Type | Position (x,y,w,h) | Binding (PLC tag) | R/W | Properties |
|---|---|---|---|---|---|---|
| 1 | `swModeAuto` | Switch (2-state, ON/OFF) | 80, 120, 400, 80 | `GDB_MachineCmd.bo_Mode` | W Bool | Text ON: "AUTO"; OFF: "MANUAL". Default state: ON (Startup OB sets `bo_Mode := TRUE`). Acquisition cycle: 100ms (read-back). |
| 2 | `txtAutoStep` | IOField (Input/output, Decimal Int) | 720, 120, 420, 80 | `GDB_MachineCmd.i16_AutoStep` | R Int16 | Format: 999 (3-digit). Font 24pt. Prefix label "Step:" via static text. Acquisition cycle: 100ms. |
| 3 | `btnInitPath` | Button | 80, 260, 380, 100 | `GDB_MachineCmd.bo_InitPath` | W Bool (PULSE) | Text: "Init Path". Background green #76B900. Foreground white. Font 16pt bold. **Press event** → JS PULSE (see below). |
| 4 | `btnStart` | Button | 520, 260, 380, 100 | `GDB_MachineCmd.bo_Start` | W Bool (PULSE) | Text: "START". Background green #76B900. Foreground white. Font 16pt bold. **Press event** → JS PULSE. |
| 5 | `btnStop` | Button | 520, 400, 380, 100 | `GDB_MachineCmd.bo_Stop` | W Bool (PULSE) | Text: "STOP". Background red #E60028. Foreground white. Font 16pt bold. **Press event** → JS PULSE. |
| 6 | `btnToTarget` | Button | 80, 720, 320, 70 | (system function) | — | Text: "→ Target Pos". Background light blue #5BA8E5. **Click event** → System function `ActivateScreen("Target_Screen")`. |
| 7 | `btnToActualPos` | Button | 440, 720, 320, 70 | (system function) | — | Text: "→ Actual Pos". Background light blue #5BA8E5. **Click event** → System function `ActivateScreen("Actual_Pos_Screen")`. |

---

## JS Press event handlers (paste into TIA Portal's Events tab)

### btnInitPath.Press

```javascript
HMIRuntime.Tags("bo_InitPath").Write(true);
setTimeout(() => HMIRuntime.Tags("bo_InitPath").Write(false), 250);
```

### btnStart.Press

```javascript
HMIRuntime.Tags("bo_Start").Write(true);
setTimeout(() => HMIRuntime.Tags("bo_Start").Write(false), 250);
```

### btnStop.Press

```javascript
HMIRuntime.Tags("bo_Stop").Write(true);
setTimeout(() => HMIRuntime.Tags("bo_Stop").Write(false), 250);
```

---

## Static labels (decorative — not counted toward 5-cap)

| Label | Position | Text | Font |
|---|---|---|---|
| L1 | 80, 90, 400, 30 | "Mode" | 14pt gray |
| L2 | 720, 90, 420, 30 | "Current Auto Step" | 14pt gray |
| L3 | 80, 230, 380, 30 | "One-time path init" | 12pt italic gray |
| Title | 0, 0, 1280, 60 | "SCARA ABCDE — Home" | 24pt white on teal |

---

## Build sequence in TIA Portal

1. Project tree → HMI_1 → Screens → right-click → **Add new screen** → name `Home_Screen`
2. Set as start screen: HMI_1 → Runtime settings → Start screen = `Home_Screen`
3. Drag title rectangle (#009999) 0/0/1280/60 + static text "SCARA ABCDE — Home"
4. For each widget #1-7 in the table above:
   - Drag the widget type from the Toolbox
   - Set Position + Size per spec
   - Set Properties → Process → Binding to the listed PLC tag (HMI tag auto-creates on first reference)
   - For widgets #3-5: set Events → Press → JavaScript → paste the JS block above
   - For widgets #6-7: set Events → Click → System functions → ActivateScreen → enter the target screen name
5. Add static labels L1-L3 per the table
6. Save the screen (Ctrl+S)
7. Compile HMI_1 (right-click → Compile → Software (only changes))

---

## Acceptance criteria

| # | Test | Pass when |
|---|---|---|
| H1 | Screen loads at runtime start | Runtime launches; Home_Screen is visible |
| H2 | `swModeAuto` starts in ON state | Toggle reads `GDB_MachineCmd.bo_Mode` = TRUE on first scan after Startup OB |
| H3 | `txtAutoStep` shows current step | Pre-cycle value = 0; during cycle = 10/20/30/40/50 |
| H4 | `btnInitPath` PULSE works | Press → Watch Table sees `bo_InitPath` flicker TRUE→FALSE; `bo_PathInitialed` goes TRUE within 1 scan; remains TRUE |
| H5 | `btnStart` PULSE triggers cycle | Press → `i16_AutoStep` jumps 0→10 within 1 PLC scan |
| H6 | `btnStop` PULSE halts cycle | Press during cycle → `i16_AutoStep` becomes 0 within 1 PLC scan |
| H7 | `btnToTarget` navigates correctly | Click → Target_Screen displays |
| H8 | `btnToActualPos` navigates correctly | Click → Actual_Pos_Screen displays |
| H9 | HMI compile passes 0W/0E | TIA Portal compile reports zero warnings/errors |

H1-H9 collectively cover V2 + V5 gates (Start triggers state machine + Stop responsiveness). V6 (target display) covered by Target_Screen.
