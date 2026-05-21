**Status:** PENDING_VERIFICATION → operator + scara-PLC. Added 5 new GDB_MCDData Members (BeltVelocity / SpawnContainerCmd / SinkContainer[1..2] / PackingSensor / PalletizingSensor) to receive the 7 currently-unmapped MCD signals (conveyor belt velocity + 2 reach-position sensors + spawn trigger + 2 sink triggers). Operator runbook: VCI import → Compile → PLCSIM-Adv Memory Reset (GDB shape change) → Download → TIA Portal Hardware Configuration → kinematic group external signal mapping. No FB code change in this cycle; FB_ConveyorCtrl + container-arrival-gated cycle gating deferred to next cycle.

# PLC_HANDOFF — MCD signal additions: conveyor + reach-position sensors + spawn/sink triggers (2026-05-19)

**Project:** `hmiDemoSCARA_ABCDE`
**Audience:** operator (runbook) + scara-PLC agent (next-cycle FB integration)
**Predecessors:**
- `PLC_HANDOFF_2026-05-17_C71_Phase2_HmiStatusFacade_Verified.md` — Phase C HMI facade landed; GDB_MCDData already used for axis kinematic data
- `PLC_HANDOFF_2026-05-19_HMI_Followups_HeaderStripAndIOFieldRendering.md` — earlier tonight; HMI follow-ups documented

## 1. Context — what's unmapped

Operator's TIA Portal external-signal-mapping dialog for `PLCSIM Adv.DemoScara_ABCD` shows **15 MCD signals** total, but only **8 are currently mapped** (4 axis positions + 4 axis velocities). The remaining **7 MCD signals** have no PLC binding:

| MCD Signal | Owner | IO Type | Datatype | Purpose |
|---|---|---|---|---|
| `sContainerBeltVel` | saContainerBe... | Input | double | PLC commands belt velocity (mm/s) |
| `sActivateSpawnContainer` | saContainerBe... | Input | bool | PLC pulses → MCD spawns one container |
| `sContainerBeltPackingSensor` | saContainerBe... | Output | bool | MCD writes → PLC reads (container at packing position) |
| `sContainerBeltPalletizingSensor` | saContainerBe... | Output | bool | MCD writes → PLC reads (container at palletizing position) |
| `sSinkContainer` (×2) | saContainerPa... | Input | bool | PLC pulses → MCD removes container at sink |

IO Type convention (MCD signal-side): **Input** = MCD reads it (PLC writes); **Output** = MCD writes it (PLC reads).

## 2. PLC tag additions (5 new Members in GDB_MCDData)

Edit applied to `PLC_1/Program blocks/600_HMI_Comm/GDB_MCDData.xml` (DB#6, Optimized, Memory Reserve 100). Inserted after `J4_ActualVelocity`, before closing `</Section>`:

| New Member | Datatype | Direction | Maps to MCD signal | Initial value |
|---|---|---|---|---|
| `BeltVelocity` | LReal | PLC → MCD (W) | `sContainerBeltVel` | 0.0 (belt stopped) |
| `SpawnContainerCmd` | Bool | PLC → MCD (W) | `sActivateSpawnContainer` | FALSE |
| `SinkContainerLeft` | Bool | PLC → MCD (W) | `sSinkContainer` on saContainerPallet_1 (operator's "left" pick) | FALSE |
| `SinkContainerRight` | Bool | PLC → MCD (W) | `sSinkContainer` on saContainerPallet_2 (operator's "right" pick) | FALSE |
| `PackingSensor` | Bool | MCD → PLC (R) | `sContainerBeltPackingSensor` | FALSE |
| `PalletizingSensor` | Bool | MCD → PLC (R) | `sContainerBeltPalletizingSensor` | FALSE |

**Convention to confirm at mapping step**: operator picks which physical `sSinkContainer` row (saContainerPallet_1 vs _2) corresponds to "left" vs "right" pallet based on actual NX MCD viewport orientation. No fixed PLC-side convention — operator's call.

GDB shape change: +5 Members (1 LReal + 3 Bool + 1 Array[1..2] of Bool = 14 bytes optimized layout). Mandatory PLCSIM-Adv Memory Reset on download.

## 3. Operator runbook

| Step | Action | Expected |
|---|---|---|
| 1 | TIA Portal → close v20 project if open; close any Openness session | Project unlocked for VCI import |
| 2 | PowerShell or TIA VCI dialog → import `VCIExportedContents/PLC_1/Program blocks/600_HMI_Comm/GDB_MCDData.xml` (force overwrite existing DB#6) | DB#6 re-imported with 5 new Members visible in TIA project tree |
| 3 | Right-click `PLC_1` → Compile → Hardware and software (only changes) | 0E / 0W |
| 4 | PLCSIM-Adv Control Panel → DemoScara_ABCD instance → **MRES (Memory Reset)** | State transitions to Stop. **Mandatory** due to GDB shape change. |
| 5 | Right-click `PLC_1` → Download to device → Hardware and software (only changes) | PLCSIM-Adv state → Run |
| 6 | TIA Portal → Devices & Networks → SCARA station → kinematic group → Connection → **External signal mapping** dialog | 5 new MCD-signal-mapping rows possible |
| 7 | Click **Do Auto Mapping** | Likely auto-maps the 5 new tags by name match (`BeltVelocity` ↔ `sContainerBeltVel` may need manual; sensor pair will auto-match) |
| 8 | Manually map any unresolved rows: `sSinkContainer (saContainerPallet_1)` → `GDB_MCDData.SinkContainerLeft`, `sSinkContainer (saContainerPallet_2)` → `GDB_MCDData.SinkContainerRight`, others as needed | All 7 unmapped rows now show ✅ in Mapped Signals (8) → (15) |
| 9 | Click **Check for N->1 Mapping** | Should pass (each MCD signal maps to exactly one PLC tag) |
| 10 | Click **OK** to commit mapping; recompile + download if TIA prompts | Mapping persisted in project |

## 4. Optional verification (operator Watch Table)

After step 10, in TIA Watch Table or via `Plcsim_Helpers.psm1`:

```powershell
# Verify sensor reads (initial: both FALSE since no container at sensors)
Read-Tag 'GDB_MCDData.PackingSensor'        # expect FALSE
Read-Tag 'GDB_MCDData.PalletizingSensor'    # expect FALSE

# Spawn a container, verify packing sensor fires when it arrives
Write-Tag 'GDB_MCDData.BeltVelocity' 100.0  # start belt at 100 mm/s
Write-Tag 'GDB_MCDData.SpawnContainerCmd' $true
Start-Sleep -Milliseconds 500
Write-Tag 'GDB_MCDData.SpawnContainerCmd' $false  # pulse complete

# Wait for container to reach packing position (depends on belt length + velocity)
# Then poll PackingSensor in MCD viewport — should see container at sensor location
```

If `PackingSensor` doesn't fire after the container visibly arrives at the packing position in NX MCD viewport: re-check the mapping for `sContainerBeltPackingSensor` row in step 8.

## 5. Out of scope (next-cycle work for scara-PLC agent)

- **`FB_ConveyorCtrl`** — new FB to drive `BeltVelocity` based on ABCDE / Palletizing cycle state; currently belt runs at constant velocity if operator sets it manually
- **Container-arrival-gated cycle gating** — modify `FB_AutoCtrl_ABCDE` or `FB_AutoCtrl_Palletizing` to wait for `PackingSensor` / `PalletizingSensor` rising edge before issuing pick command (current cycle is free-running, doesn't gate on container presence)
- **Spawn/sink rhythm** — recipe-driven sequence (every N seconds spawn + sink based on cycle phase); requires `FB_ContainerOrchestrator` or equivalent
- **HMI surface** — bind `GDB_MCDData.BeltVelocity` (W LReal) + sensor lamps + container count to HMI (cycle-7.7+ candidate, after IOField retrofit + header strip land)

## 6. Closure markers

- `[PENDING_VERIFICATION]` GDB_MCDData shape change deployed; mapping completion gated on operator runbook §3
- `[NEEDS_HUMAN]` Operator step 7-8 picks which `sSinkContainer` instance maps to `SinkContainerLeft` vs `SinkContainerRight` (based on NX MCD viewport orientation)
- `[NEEDS_SCARA_PLC]` Next-cycle FB integration per §5 (FB_ConveyorCtrl + container-arrival gating + spawn/sink rhythm)
- `[INFO]` No SCL/FB code change in this cycle — pure GDB shape change + operator UI mapping. PLCSIM-Adv Memory Reset is the only material runtime impact.
- `[INFO]` Cross-tree write — v9-PM authored this on operator-routed exception per chat instruction; aligns with tonight's other SCARA-tree handoff (`PLC_HANDOFF_2026-05-19_HMI_Followups_HeaderStripAndIOFieldRendering.md`)
- `[BLOCKS-ON]` operator runbook §3 → flip to VERIFIED after step 9 passes

End of MCD signal additions handoff 2026-05-19.
