# HMI Runtime Co-Driver Manifest — ABCDE end-to-end

**Purpose:** drive the HMI via WinCC Unified Runtime UI clicks (Claude in Chrome MCP) while simultaneously monitoring PLCSIM-Adv facade tags, to verify the full HMI → comm driver → PLC path end-to-end.

**Plan:** `C:\Users\Admin\.claude\plans\starry-seeking-seal.md`

## Pre-conditions

| Item | Required state |
|---|---|
| PLCSIM-Adv instance | `DemoScara_ABCD` running at `192.168.0.5`, OperatingState=Run |
| WinCC Unified Runtime | Serving `hmiDemoSCARA_ABCDE` at `https://desktop-9988rob/WebRH` |
| Chrome browser | Open + connected to Claude in Chrome MCP |
| TIA program | C71 facade deployed (`GDB_HMI_Status` + `FB_HMIStatusMirror` live, 9/9 facade smoke PASS) |
| J2 SW limits | -1060/+800° (wide range — see C69 §11 — narrow ±160° breaks IK) |
| J3 SW limits | -1850/+600 mm (wide range — see C69 §11) |
| L1 geometry | 1028.48 mm (column height; see C69 §10) |

## Files

| Path | Role |
|---|---|
| `harness/Prearm_AbcdeAxes.ps1` | Idempotent: clear modes, reset, enable, home, verify axesReady=TRUE |
| `harness/Monitor_GDB_HMI_Status.ps1` | Live dashboard + JSON log of all 40 facade tags + 8 cmd-side correlator tags |
| `VCIExportedContents/smoke_logs/hmiRuntimeCoDriver_<ts>.log` | Output: one JSON snapshot per `RefreshMs` |

## Run sequence

```
[T-3s]    Run: .\harness\Prearm_AbcdeAxes.ps1 -TargetIp 192.168.0.5
          Expect: "Prearm complete." + exit 0

[T+0s]    Start (background): .\harness\Monitor_GDB_HMI_Status.ps1 -DurationSeconds 60
          Records: snapshot every 500ms to hmiRuntimeCoDriver_<ts>.log

[T+2s]    Chrome MCP:  mcp__Claude_in_Chrome__list_connected_browsers  → pick active
[T+3s]    Chrome MCP:  navigate to https://desktop-9988rob/WebRH/
[T+5s]    Chrome MCP:  read_page → find bottom-nav Auto tab ref
[T+6s]    Chrome MCP:  computer left_click → Auto tab
[T+8s]    Chrome MCP:  read_page → confirm 02_Auto_Ubp loaded (btnAutoStart visible)
[T+9s]    Chrome MCP:  find btnAutoMode → computer left_click
          Expected in monitor within 1s:  GDB_MachineCmd.bo_Mode  FALSE→TRUE
                                          GDB_HMI_Status.activeMode  0→1
                                          GDB_HMI_Status.totalSteps  0→5
[T+11s]   Chrome MCP:  find btnAutoInitPath → computer left_click
          Expected within 1s:  GDB_MachineCmd.bo_PathInitialed  FALSE→TRUE
                               GDB_HMI_Status.pathInitialed  FALSE→TRUE
[T+13s]   Chrome MCP:  computer screenshot → save "post_init.png"
[T+14s]   Chrome MCP:  find btnAutoStart → computer left_click
          Expected within 1s:  GDB_MachineCmd.i16_AutoStep  0→10
                               GDB_HMI_Status.currentStep  0→10
[T+15-45s] Observation window (30s)
          Expected: i16_AutoStep advances 10→20→30→40→50→10... at least one full wrap
                    target_x/y/z/a change per ABCDE point
                    j*_actualPos sweeping during motion
[T+30s]   Chrome MCP:  computer screenshot → save "mid_cycle.png"
[T+45s]   Chrome MCP:  find btnAutoStop → computer left_click
          Expected within 1s:  GDB_MachineCmd.i16_AutoStep  →0
                               GDB_HMI_Status.currentStep  →0
[T+47s]   Chrome MCP:  computer screenshot → save "post_stop.png"
[T+60s]   Monitor exits cleanly. Read log file.
```

## V-HMI verification gates

| Gate | Criterion | Source of truth |
|---|---|---|
| V-HMI.RuntimeReachable | navigate to WebRH/ returned no error | Chrome MCP result |
| V-HMI.AutoScreenLoaded | read_page after Auto-tab click contains btnAutoStart marker | Chrome MCP read_page |
| V-HMI.ModeToggleSync | `GDB_MachineCmd.bo_Mode` flipped FALSE→TRUE within 1s of click; `activeMode` simultaneously routed to 1 | JSON log: scan for first cmd.GDB_MachineCmd.bo_Mode=true after click timestamp |
| V-HMI.InitPathSync | `bo_PathInitialed` flipped FALSE→TRUE within 1s | JSON log |
| V-HMI.StartSync | `i16_AutoStep` went 0→10 within 1s | JSON log |
| V-HMI.CycleAdvance | ≥ 4 distinct steps in {10,20,30,40,50} seen during 30s window | JSON log: distinct values of cmd.i16_AutoStep where 10≤v≤50 |
| V-HMI.FacadeMirrors | `facade.currentStep == cmd.i16_AutoStep` at every sample | JSON log: per-sample equality |
| V-HMI.StopSync | `i16_AutoStep` returned to 0 within 1s of Stop click | JSON log |

## Failure diagnostic chain

| Failed gate | Likely cause |
|---|---|
| RuntimeReachable | Runtime not serving SCARA; check `https://desktop-9988rob/WebRH` in browser manually |
| AutoScreenLoaded | Nav-tab selector wrong; use `read_page` to inspect actual DOM markers |
| ModeToggleSync | HMI button JS PULSE handler not firing OR comm driver not connected to PLCSIM |
| InitPathSync | bo_InitPath button bound wrong tag OR R_TRIG in FB not detecting edge |
| StartSync | Start gate in `FB_AutoCtrl_ABCDE` REGION 2 rejecting (check bo_Mode + bo_ESTOP_LOCK + bo_PathInitialed + 3-way mutex) |
| CycleAdvance | Motion stuck — re-check J2/J3 SW limits (C69 §11 — narrow limits break IK) |
| FacadeMirrors | C71 FB_HMIStatusMirror not running, or Main.scl REGION HMI_Status_Mirror missing from cyclic schedule |
| StopSync | Stop button bound wrong tag OR FB STOP REGION not active |

## Re-run procedure

1. Confirm pre-conditions (esp. PLCSIM running, runtime serving SCARA)
2. `cd E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles`
3. `.\harness\Prearm_AbcdeAxes.ps1` — wait for exit 0
4. Start monitor in background: `.\harness\Monitor_GDB_HMI_Status.ps1 -DurationSeconds 60`
5. Have the agent (or operator) execute the Chrome click sequence above
6. After monitor exits, post-process the JSON log to compute V-HMI gates

## Notes

- The **monitor reads the C71 facade** so a single GDB suffices for the dashboard. If the facade is ever stale, the cmd-side reads (`GDB_MachineCmd.*`) still work as a cross-check.
- **J2 large angles** (e.g., 33000°+) accumulate from the SCARA elbow not unwrapping. Don't be alarmed by big numbers in `j2_actualPos`; they only matter if motion stalls (see C69 §11).
- **Screenshots are agent-side** via Chrome MCP `computer action=screenshot`. They land in the runtime smoke_logs dir for the post-run handoff.
- **No PLC code changes**. This harness is read-only on the PLC side except for the Prearm direct writes to GDB_Control (which are equivalent to what the STAGED `02_Manual_Kin_Ubp` would do).
