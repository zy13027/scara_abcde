**Status:** INFORMATIONAL → scara-HMI agent. Two follow-up surfacings from tonight's HMI testing session: (a) header strip with Axes Enable/Home/Reset buttons + 4 status lamps visible across all UBP screens (NEW REQUEST); (b) IOField rendering issue on `02_Auto_Ubp` cardProgress (acknowledges scara-HMI's cycle-7.6+ planning question Option 1). Both items are CONFIRMED PLC-side ready — facade tags + GDB_Control writes already deployed and 9/9 smoke-verified (C71). No PLC code change. No contract gap.

# PLC_HANDOFF — HMI follow-ups: header strip + IOField rendering (2026-05-19)

**Project:** `hmiDemoSCARA_ABCDE` (UBP screens on HMI_1, MTP1000 1024×600)
**Audience:** scara-HMI agent (cycle-7.6+ + cycle-7.7+ planning)
**Predecessors:**
- `PLC_HANDOFF_2026-05-18_Cycle7_5_PalletScreen_C71_FacadeAdoption.md` — C71 facade introduction + §4.2 retrofit recommendations (Option 1 / 2 / 3 referenced in scara-HMI's question)
- `PLC_HANDOFF_2026-05-18_C71_Phase2_HmiStatusFacade_Verified.md` — C71 9/9 smoke-PASS, facade tags live on PLC side
- `PLC_HANDOFF_2026-05-18_C70_PalletizingHmiSurfaceProposal.md` — C70 §3 visualization recommendation (not the subject of this handoff)

## 1. Context — what tonight's session surfaced

Operator ran ABCDE 5/5 + Palletizing 7/7 successfully using `PLCSIM-Adv direct write + computer-use screenshot` pattern (after Siemens AKG bot definitively closed off the GraphQL route on Basic Panel SKU — see `PLC_HANDOFF_2026-05-19_WinCCUnifiedRuntimeTagApi_EmpiricalFindings.md`). Two HMI-side issues were observed during the run; both are HMI-authoring follow-ups, neither blocks PLC verification, but together they significantly degrade the operator UX during testing.

**Issue A — Numeric IOFields show binding-path strings as text instead of LReal values.** On `02_Auto_Ubp` cardProgress, the 5 IOFields meant to display `i16_AutoStep` / `statTargetPos.x` / `.y` / `.z` / `.a` render literally as path strings (e.g., the screen shows `instFB_AutoCtrl_ABCDE.statTargetPos.x` as text instead of a number). Probable root causes (HMI agent to confirm):
- HMI IOField "Process value" property binds to a path the runtime can't resolve (typo, missing iDB "Accessible from HMI" flag, or stale tag-table entry)
- OR the IOField "Format" property is set to "String" instead of "Decimal" / "Floating-point"

**Issue B — No header strip with axis controls visible across all UBP screens.** Axes Enable / Home / Reset are NOT bound on any active UBP screen — they only existed on the now-STAGED `02_Manual_Kin_Ubp` from cycle-7.x (pending re-bind). When operator wants to switch between modes (ABCDE / Palletizing / Manual) and needs to reset stuck motion or arm the axes, they have no HMI surface — must drop to TIA Watch Table or PowerShell direct writes. Tonight's pre-arm was done via `Prearm_AbcdeAxes.ps1` for this reason.

## 2. Status of each issue

| Issue | Acknowledged by | Status | Cycle target |
|---|---|---|---|
| A. IOField rendering | scara-HMI cycle-7.6+ planning Option 1 ("Retrofit 02_Auto_Ubp cardProgress to C71 facade reads") | scara-HMI agreed to plan in cycle-7.6+ per scara-PLC's recommendation tonight | cycle-7.6+ |
| B. Header strip + Axes controls | NEW — surfaced tonight, no prior HMI acknowledgement | NEEDS scara-HMI agent to ack + scope | cycle-7.7+ (after #1 lands) |

## 3. PLC-side ready surface (no PLC code change needed for either issue)

### For Issue A (IOField retrofit — facade reads)

C71 `GDB_HMI_Status` facade is LIVE + 9/9 smoke-verified. Bind 5 IOFields on `02_Auto_Ubp` cardProgress to:

| IOField "Process value" path | Datatype | Direction | Notes |
|---|---|---|---|
| `GDB_HMI_Status.currentStep` | Int | R | Facade mirrors `i16_AutoStep` (ABCDE) OR `i16_PalletStep` (Palletizing) based on `activeMode` |
| `GDB_HMI_Status.totalSteps` | Int | R | =50 for ABCDE; =48 for palletizing; facade auto-selects |
| `GDB_HMI_Status.target_x` | LReal | R | Mirrors active FB's statTargetPos.x |
| `GDB_HMI_Status.target_y` | LReal | R | Same |
| `GDB_HMI_Status.target_z` | LReal | R | Same |
| `GDB_HMI_Status.target_a` | LReal | R | Same |

**Suggested HMI tag-table aliases** (if scara-HMI prefers them over direct PLC paths):

| HMI tag | PLC path | Direction |
|---|---|---|
| `hmiCurrentStep` | `GDB_HMI_Status.currentStep` | R |
| `hmiTotalSteps` | `GDB_HMI_Status.totalSteps` | R |
| `hmiTargetX` | `GDB_HMI_Status.target_x` | R |
| `hmiTargetY` | `GDB_HMI_Status.target_y` | R |
| `hmiTargetZ` | `GDB_HMI_Status.target_z` | R |
| `hmiTargetA` | `GDB_HMI_Status.target_a` | R |

**IOField Format property** — must be set to Decimal (Int) or Floating-point (LReal); NOT String. This is likely the root cause of Issue A independent of the binding path itself.

### For Issue B (header strip — Axes Enable / Home / Reset)

PLC tags already in tree — no PLC code change needed:

| Header strip element | PLC binding | Direction | Behavior |
|---|---|---|---|
| `btnAxesEnable` (TOGGLE switch) | `GDB_Control.enableAxes` | W Bool LEVEL | TRUE → all 4 axes power on via `FB_AxisCtrl`; FALSE → power off. Latches. |
| `btnAxesHome` (PULSE button) | `GDB_Control.homeAxes` | W Bool PULSE 300ms | Rising edge → `MC_Home` on all 4 axes via FB_AxisCtrl; FB clears request after homing complete |
| `btnAxesReset` (PULSE button) | `GDB_Control.resetAxes` | W Bool PULSE 300ms | Rising edge → `MC_Reset` on all axes (clears any latched error) |
| `lampAxesEnabled` | `GDB_HMI_Status.axesEnabled` | R Bool | Lit (green) when all 4 axes report `MC_Power.Status = TRUE` |
| `lampAxesHomed` | `GDB_HMI_Status.axesHomed` | R Bool | Lit (blue/teal) when all 4 axes report `MC_Home.Done = TRUE` |
| `lampAxesError` | `GDB_HMI_Status.axesError` | R Bool | Lit (red) when ANY axis `ErrorID > 0` |
| `lampAxesReady` | `GDB_HMI_Status.axesReady` | R Bool | Lit (overall green) when (enabled AND homed AND NOT error) |

**Suggested HMI tag-table aliases:**

| HMI tag | PLC path | Direction |
|---|---|---|
| `hmiAxesEnableCmd` | `GDB_Control.enableAxes` | W |
| `hmiAxesHomeCmd` | `GDB_Control.homeAxes` | W |
| `hmiAxesResetCmd` | `GDB_Control.resetAxes` | W |
| `hmiAxesEnabled` | `GDB_HMI_Status.axesEnabled` | R |
| `hmiAxesHomed` | `GDB_HMI_Status.axesHomed` | R |
| `hmiAxesError` | `GDB_HMI_Status.axesError` | R |
| `hmiAxesReady` | `GDB_HMI_Status.axesReady` | R |

### Mutex / arbitration rules

**Critical for the header strip — these 3 commands must work in ANY active mode** (ABCDE, Palletizing, Manual, or no mode). They are NOT gated by the 3-way mode mutex (`GDB_MachineCmd.bo_Mode` / `GDB_PalletizingCmd.bo_Mode` / `GDB_ManualCmd.bo_Mode`):

- `enableAxes` write: always accepted; `FB_AxisCtrl` honors it regardless of mode
- `homeAxes` write: accepted in non-AUTO modes; if an auto cycle is running, gated by mode-arbiter (operator must stop the cycle first — that's a contract, not a bug)
- `resetAxes` write: ALWAYS accepted, never gated — this is the panic/recovery primitive

**Recommendation: do NOT add HMI-side mutex grey-out logic on these 3 buttons.** They are operator's safety/recovery surface and must remain clickable at all times, including (especially) when something is stuck.

## 4. Suggested HMI layout for the header strip

| Surface | Placement | Visibility | Implementation hint |
|---|---|---|---|
| Header strip (~40-50px tall) | Top of every UBP screen | Persistent across screen switches | Either: (a) shared screen-window slot reused across screens; (b) per-screen replication with copied widgets. HMI agent picks. |
| Auto-mode dependent body | Mid-section | Per screen (Home/Auto/Pallet/Manual/Diag/Config) | Existing screen-window swap pattern from cycle-7.5 |
| Bottom nav | Existing 6-tab | Persistent | No change |

Header strip content (left-to-right, ~1024px canvas):
- **Title area** (~150px): static text "SCARA SCM Demo" or active-mode label
- **Button group** (~280px): `btnAxesEnable` | `btnAxesHome` | `btnAxesReset` (each ~80-90px wide)
- **Lamp group** (~280px): `lampAxesEnabled` (green) | `lampAxesHomed` (blue) | `lampAxesError` (red) | `lampAxesReady` (green overall)
- **Active-mode indicator** (optional, ~150px): displays "ABCDE" | "Palletizing" | "Manual" | "Idle" derived from `GDB_HMI_Status.activeMode` (Int 0-3 enum)

## 5. Verification expected post-cycle-7.6 landing (Issue A)

After scara-HMI lands cycle-7.6 (IOField retrofit), operator + PLC agent run:

1. `.\harness\Prearm_AbcdeAxes.ps1 -TargetIp 192.168.0.5` → expect `axesReady=TRUE`
2. ABCDE smoke 5/5 + visually observe `hmiCurrentStep` IOField in `02_Auto_Ubp` advancing 0→10→20→30→40→50→10 cleanly + `hmiTargetX/Y/Z/A` updating per step
3. Without PowerOff/On (J2 modulo enabled tonight; previously needed it), switch to palletizing mode → observe `hmiCurrentStep` advancing 0→1→2..→48→1 + `hmiTargetX/Y/Z/A` per box
4. Manual stop click → return to 0 + all IOFields zero out

If all 4 steps PASS, Issue A is closed. Issue B (header strip) remains as cycle-7.7+ work.

## 6. Companion ask — J2 modulo accumulation fix (tonight, OPERATIONAL CONTEXT, not a scara-HMI ask)

Operator just deployed (via TIA UI) the J1/J2/J4 Modulo Enable fix per Wang Shuo's WeChat confirmation:
- All 3 rotary SCARA joints (J1 shoulder, J2 elbow, J4 wrist) now have `Modulo.Enable = true` + `Length = 360.0` + `StartValue = 0.0` → range [0, 360°)
- J1 / J2 SW limits disabled (modulo wraps; no longer needed as accumulation buffer)
- J3 (linear Z prismatic) unchanged (-1850 / +600)
- Compile + PLCSIM-Adv Memory Reset + Download complete

Verification pending: sequential ABCDE → Palletizing → ABCDE without PowerOff/On between (previously froze at palletizing step 11 due to multi-rev J2 accumulation from prior ABCDE cycle leaving J2 at -578°; with modulo enabled, j2_actualPos bounded [0, 360°) so the inverse kinematics planner always starts from a sensible angle).

This is NOT a scara-HMI ask — it's PLC-agent verification work. Listed here for situational awareness only. **The Issue A IOField retrofit (cycle-7.6) materially helps this verification** because operator can observe step transitions from the HMI in real time instead of polling PLCSIM Watch Table.

## 7. Closure markers

- `[NEEDS_HMI]` Issue B header strip — scara-HMI agent acks + scopes for cycle-7.7+ (PLC side has no further obligation; bindings ready)
- `[ACKNOWLEDGED]` Issue A IOField rendering — scara-HMI agent picked Option 1 in cycle-7.6+ planning (per tonight's question + scara-PLC's recommendation)
- `[INFORMATIONAL]` Companion §6 — J2 modulo fix deployed via TIA UI tonight; verification pending PLC-side smoke
- `[INFO]` C71 facade bindings (9/9 smoke-verified per C71 verified handoff) — no further PLC change required for either issue
- `[BLOCKS-ON]` none — both issues are purely HMI-authoring; PLC waits for scara-HMI cycle landings

End of HMI follow-ups handoff 2026-05-19.
