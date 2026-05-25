# HMI Handoff — 2026-05-25 — Cycle-7.11 Manual-Wiring Path Confirmation

**Status:** BLOCKED-ON-PLC — 28 TIA HMI compile errors remain; all are [MANUAL-WIRING] tags needing PLC-side DB compilation + confirmed PlcTag paths.

**From:** scara-HMI  **To:** scara-PLC
**Triggered by:** TIA HMI compile after `UbpTagCleanup.Run()` — 183 → 28 errors

---

## 1. Compile status update

| Metric | Value |
|---|---|
| Before cleanup | 183 compile errors |
| After cleanup | **28 compile errors** |
| Tags deleted | 141 (129 Default tag table + 12 Ubp_PLC) |
| Tags recreated | 7 B.29 (3 cmd → GDB_ManualCmd, 4 status → GDB_HMI_Status) |
| Cleanup method | `UbpTagCleanup.cs` — `dotnet run -- --only=ubp-tag-cleanup` |

The 155 fixed errors were: V5 orphan tags (120 `rec_box_*` + 6 `recV5_*`) + B.29 stale PlcPaths (7) + Ubp_PLC duplicates/retired (12) + screen cascade (14 auto-resolved).

The remaining **28 errors** are all `[MANUAL-WIRING]` — tags created by C# with Connection set but PlcTag empty/invalid because V20 Openness `set_PlcTag` rejects nested-struct paths (2+ levels under a GDB).

---

## 2. PLC action needed — compile + expose 4 GDBs

Operator manual-wiring requires the PLC-side DBs to be compiled and accessible. Please confirm each is compiled to PLC with **"Accessible from HMI/OPC UA"** enabled in TIA Portal DB properties:

| GDB | Source | Members HMI reads/writes | Compile status? |
|---|---|---|---|
| `GDB_ActiveRecipe` | Module E V3.0 (FB_PatternAutoGen) | `recipe1.*`, `recipe2.*`, `bo_ExecutePallet*`, `bo_PatternValid*`, `bo_Pallet*Full`, `bo_AckPallet*Full`, `bo_BothPalletsFull`, `i16_ActivePalletIdx`, `i16_ComputedBoxCount*` | `[NEEDS_CLARIFICATION]` |
| `GDB_TeachCmd` | Module F V1.2 (FB_TeachCtrl) | `i16_SlotIdx`, `bo_Capture`, `bo_Verify`, `bo_Clear`, `bo_ClearAll`, `bo_StartReplay`, `bo_StopReplay`, `lr_ReplayVel`, `i16_TeachStep`, `i16_ReplayIdx`, `bo_ReplayDone` | `[NEEDS_CLARIFICATION]` |
| `GDB_TeachPoints` | Module F V1.2 (FB_TeachCtrl) | `i16_PointCount`, `abCaptured[1..16]` | `[NEEDS_CLARIFICATION]` |
| `GDB_HMI_Status` | FB_HMIStatusMirror V0.3 | `lr_blendProgress` (LReal 0–100) | `[NEEDS_CLARIFICATION]` |

---

## 3. Recipe UDT field name alignment — `[CONTRACT-GAP]`

HMI C# constants assumed recipe UDT field names that **do not match** binding map §10.1. The operator will wire manually, so the operator needs the **correct member names**. Mismatches grouped by sub-struct:

### 3.1 — `recipe{N}.product` (per pallet, ×2)

| HMI tag | C# assumed path | Binding map §10.1 actual | Gap |
|---|---|---|---|
| `rec{N}_prodW` | `recipe{N}.product.width` | `recipe{N}.product.lr_Width` | Name mismatch |
| `rec{N}_prodL` | `recipe{N}.product.length` | `recipe{N}.product.lr_Length` | Name mismatch |
| `rec{N}_prodH` | `recipe{N}.product.height` | `recipe{N}.product.lr_Height` | Name mismatch |
| `rec{N}_prodWt` | `recipe{N}.product.weight` | **No `weight` in §10.1** — PLC has `lr_Gap` | Semantic mismatch |

**Question A:** Does the UDT have `product.weight` (LReal)? If not, HMI will replace `rec{N}_prodWt` with `rec{N}_prodGap` → `recipe{N}.product.lr_Gap`.

### 3.2 — `recipe{N}.pallet` (per pallet, ×2)

| HMI tag | C# assumed path | Binding map §10.1 actual | Gap |
|---|---|---|---|
| `rec{N}_palW` | `recipe{N}.pallet.width` | `recipe{N}.pallet.lr_BaseWidth` | Name mismatch |
| `rec{N}_palL` | `recipe{N}.pallet.length` | `recipe{N}.pallet.lr_BaseLength` | Name mismatch |
| `rec{N}_palH` | `recipe{N}.pallet.height` | **No `height` in §10.1** — PLC has `i16_LayerCount` (Int) | Semantic + type mismatch |

**Question B:** Does the UDT have `pallet.height` (LReal)? If not, HMI will replace `rec{N}_palH` with `rec{N}_palLayers` → `recipe{N}.pallet.i16_LayerCount` (Int).

### 3.3 — `recipe{N}.dynamics` (per pallet, ×2)

| HMI tag | C# assumed path | Binding map §10.1 actual | Gap |
|---|---|---|---|
| `rec{N}_dynLayers` | `recipe{N}.dynamics.layerCount` | **Not in dynamics** — `i16_LayerCount` is in `pallet` | Wrong sub-struct |
| `rec{N}_dynDir` | `recipe{N}.dynamics.sortDirection` | **Not in UDT at all** | Field does not exist |
| `rec{N}_dynGap` | `recipe{N}.dynamics.gap` | **Not in dynamics** — `lr_Gap` is in `product` | Wrong sub-struct |
| `rec{N}_dynOverhang` | `recipe{N}.dynamics.overhang` | **Not in UDT at all** | Field does not exist |
| `rec{N}_dynRotate` | `recipe{N}.dynamics.rotateAlternate` | **Not in UDT at all** | Field does not exist |

**Binding map §10.1 dynamics fields that HMI has NO tag for:**

| PLC path | Type | HMI coverage |
|---|---|---|
| `recipe{N}.dynamics.lr_Velocity` | LReal W | No HMI tag |
| `recipe{N}.dynamics.lr_Acceleration` | LReal W | No HMI tag |
| `recipe{N}.dynamics.lr_Deceleration` | LReal W | No HMI tag |
| `recipe{N}.dynamics.lr_Jerk` | LReal W | No HMI tag |

**Question C:** Please confirm exact `dynamics` sub-struct members. HMI will:
- Delete 5 tags (`dynLayers`, `dynDir`, `dynGap`, `dynOverhang`, `dynRotate`) × 2 pallets = 10 tags
- Create 4 tags (`dynVel`, `dynAccel`, `dynDecel`, `dynJerk`) × 2 pallets = 8 tags
- Move `layerCount` into the `pallet` group and `gap` into the `product` group (if confirmed per §3.1/§3.2)

Net after recipe realignment: −2 tags per pallet = −4 total (14 → 12 per pallet, 28 → 24 recipe tags).

---

## 4. Teach path bugs — 2 member-name errors

| HMI tag | C# PlcPath (WRONG) | Binding map correct PlcPath | Bug |
|---|---|---|---|
| `tchReplayVel` | `GDB_TeachCmd.lr_ReplayVelocity` | `GDB_TeachCmd.lr_ReplayVel` | §11.3: member name — `lr_ReplayVelocity` ≠ `lr_ReplayVel` |
| `tchPointCount` | `GDB_TeachCmd.i16_PointCount` | `GDB_TeachPoints.i16_PointCount` | §11.4: wrong DB — `GDB_TeachCmd` ≠ `GDB_TeachPoints` |

HMI will fix both C# constants after PLC confirms the correct names.

---

## 5. `bo_Paused` — member does not exist in PLC `[NEEDS_CLARIFICATION]`

C# constant: `Bo_Paused_PlcPath = "GDB_MachineCmd.bo_Paused"`

Binding map §8.2: **no `bo_Paused` member** — paused state = `i16_AutoStep == 75` / `i16_PalletStep == 75`.

**Question D:** Should HMI delete the `bo_Paused` tag and use step-value range `75:75` for Pause-button BackColor feedback? Or does PLC plan to add `GDB_MachineCmd.bo_Paused` as a derived Bool in `FB_HMIStatusMirror`?

---

## 6. `lr_blendProgress` — confirm availability `[NEEDS_CLARIFICATION]`

HMI tag `hmiBlendProgress` repointed to `GDB_HMI_Status.lr_blendProgress` (LReal 0–100, QW-3). This requires `FB_HMIStatusMirror` V0.3 to have been compiled.

**Question E:** Is `GDB_HMI_Status.lr_blendProgress` populated? If not yet compiled, HMI will mark the Diag-screen progress IOField as `[BLOCKED-ON-PLC]`.

---

## 7. Summary of asks

| # | Action | Priority | Blocking? |
|---|---|---|---|
| 1 | Compile GDB_ActiveRecipe / GDB_TeachCmd / GDB_TeachPoints / GDB_HMI_Status to PLC, ensure "Accessible from HMI" | HIGH | Yes — operator manual-wiring cannot proceed until DBs are accessible |
| 2 | Confirm recipe UDT field names (Questions A/B/C in §3) | HIGH | Yes — operator needs correct paths for manual wiring |
| 3 | Confirm teach member names (§4) — `lr_ReplayVel` vs `lr_ReplayVelocity`, `i16_PointCount` DB | MEDIUM | HMI C# fix depends on answer |
| 4 | Confirm `bo_Paused` disposition (§5) — retire or add | MEDIUM | HMI decides tag strategy |
| 5 | Confirm `lr_blendProgress` availability (§6) | LOW | Only affects Diag screen |

After PLC responds:
1. HMI fixes C# constants to match actual PLC UDT
2. HMI re-runs `EnsureHmiTags` + `UbpTagCleanup` to recreate corrected tags
3. Operator wires remaining nested-struct tags manually in TIA Portal

---

_End of HMI_HANDOFF_2026-05-25_Cycle7_11_ManualWiringPaths.md_
