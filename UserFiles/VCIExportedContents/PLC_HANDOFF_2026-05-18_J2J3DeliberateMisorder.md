**Status:** INFORMATIONAL → HMI agent (cycle-7.2 binding decisions) + future scara-PLC agent (regression-prevention). The J2/J3 swap between TO_Axis direct view and kinematic-group view is **deliberate by-design**, not a bug. Documenting once here so no one tries to "fix" it.

# PLC_HANDOFF — J2/J3 Deliberate Misorder (TO_Axis ↔ Kinematic-Group Axis Mapping)

**Project:** `hmiDemoSCARA_ABCDE`
**Date:** 2026-05-18
**Cycle:** C67 follow-up (topical addendum)
**Predecessors:**
- `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` §6.1 (first documentation of the swap during V6 smoke discovery)
- `HMI_BINDING_MAP.md` §6.3 (binding-table version of the same mapping)
- `PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md` §3 (Phase G mirror tags consume per-joint TO names → no swap concerns at the mirror layer)

---

## 1. The fact

`ScaraArm3D` (TO_Kinematics, TypeOfKinematics=10 SCARA-3D) declares its kinematic axes in a specific order that does NOT match the human-readable joint naming. Specifically:

| Joint (human / TO_Axis name) | Kinematic-group index (`ScaraArm3D.AxesData.A[i]`) |
|---|---|
| J1 (column base shoulder) | A[1] |
| **J2 (elbow rotation)** | **A[3]** — NOT A[2] |
| **J3 (vertical prismatic z)** | **A[2]** — NOT A[3] |
| J4 (wrist) | A[4] |

So `ScaraArm3D.AxesData.A[2].Position` is actually J3's position, and `ScaraArm3D.AxesData.A[3].Position` is J2's. The kinematic group sees the axes in the order [J1, J3, J2, J4] (Z-prismatic indexed before elbow rotation).

This is fixed in the TO XML (`PLC_1/Technology objects/ScaraArm3D.xml`) per Siemens canonical SCARA configuration — the kinematic solver expects the Z-prismatic axis at A[2] and the elbow axis at A[3] for its inverse-kinematics math to produce correct TCP solutions. **Reordering the TO would break the IK solver.**

## 2. Where the misorder appears

| Source path | Ordering | Notes |
|---|---|---|
| `J1_SCARA_Arm3D.ActualPosition` | Joint-name order (J1, J2, J3, J4) | TO_Axis direct binding |
| `J2_SCARA_Arm3D.ActualPosition` | (J2) | TO_Axis direct binding |
| `J3_SCARA_Arm3D.ActualPosition` | (J3) | TO_Axis direct binding |
| `J4_SCARA_Arm3D.ActualPosition` | (J4) | TO_Axis direct binding |
| `ScaraArm3D.AxesData.A[1].Position` | J1 | Kinematic-group view |
| `ScaraArm3D.AxesData.A[2].Position` | **J3** ⚠️ | Kinematic-group view (swapped) |
| `ScaraArm3D.AxesData.A[3].Position` | **J2** ⚠️ | Kinematic-group view (swapped) |
| `ScaraArm3D.AxesData.A[4].Position` | J4 | Kinematic-group view |

The two views show identical numeric values for J1 and J4. They differ for J2/J3 because they're literally different sources.

## 3. Bindings that consume each view

### Joint-name order (no swap concern)

These reach the per-joint TO directly, so HMI / mirror tags read in joint-name order naturally:

- HMI `J{n}_SCARA_Arm3D.ActualPosition` IOFields on `02_Manual_Axis_Ubp_J{1..4}` deep-drill screens — HMI runtime via S7 driver reads J{n}_SCARA_Arm3D directly
- `GDB_MCDData.J{1..4}_ActualPosition` / `J{1..4}_ActualVelocity` — the 8 explicit-named members added in Phase C.0 (rev 0.2 of FB_MCDDataTransfer publishes from `J{n}_SCARA_Arm3D.ActualPosition`)
- `GDB_ManualStatus.bo_J{1..4}_*` (Phase G) — FB_ManualCtrl REGION 5 reads `J{n}_SCARA_Arm3D.StatusWord.%X{1,5,7}` per joint
- `instFB_AxisCtrl.instPower_J{n}.Status` — FB_AxisCtrl declares MC_Power per joint by joint TO name
- `instFB_ManualCtrl.instJog_J{n}` — FB_ManualCtrl declares MC_MoveJog per joint by joint TO name

**Implication:** any tag whose name contains `J{n}` (where the index comes from a joint name) is in joint-name order. No swap.

### Kinematic-group order (J2/J3 swapped)

These read from the kinematic group itself, so they expose the IK-solver's internal axis order:

- `GDB_MCDData.Position[1..4]` / `Velocity[1..4]` (back-compat array; FB_MCDDataTransfer publishes from `ScaraArm3D.AxesData.A[i]`)
- `ScaraArm3D.Tcp.{x, y, z}` (TCP world coordinates — kinematic, NOT joint indexed; no swap, but only meaningful through IK)
- NX MCD signal adapter — receives axes in kinematic-group order (J1, J3, J2, J4)

**Implication:** any tag named `Position[i]` (array indexed) or `AxesData.A[i]` is in kinematic-group order. J2/J3 swap applies.

## 4. Test/smoke implications

`SmokeTest_PhaseG.ps1` uses `GDB_MCDData.Position[1]` as J1 proxy and `Position[4]` as J4 proxy — both correct (no swap on J1/J4).

If a future smoke needs J2 or J3 motion verification via the kinematic-group array, it must read:
- For J2 motion: `GDB_MCDData.Position[3]` (NOT `Position[2]`)
- For J3 motion: `GDB_MCDData.Position[2]` (NOT `Position[3]`)

Alternatively, after Phase C.0 ships, use the joint-name explicit mirror: `GDB_MCDData.J{n}_ActualPosition` — no swap concern.

## 5. HMI cycle-7.2 binding implications

For per-axis HMI bindings:

- **Per-joint cmd/status bindings** (Phase G surface): bind to `GDB_ManualCmd.bo_J{n}_*` / `GDB_ManualStatus.bo_J{n}_*` directly. HMI per-axis screens already use joint-name order (`02_Manual_Axis_Ubp_J1`, `J2`, `J3`, `J4`). No swap.
- **Per-joint IOField bindings** (existing Phase C work): bind to `J{n}_SCARA_Arm3D.ActualPosition` / `ActualVelocity` direct. HMI per-axis deep-drill screens already do this. No swap.
- **DO NOT bind HMI to `ScaraArm3D.AxesData.A[i].*`** — this exposes the kinematic-group swap and operator will see J2 values labelled as J3. (No current HMI binding does this; flagging for cycle-7.2+ defensively.)

## 6. PLC-side conventions (regression-prevention for future scara-PLC)

- **Always declare FB MC instances by joint TO name** (e.g., `instJog_J2 ... Axis := "J2_SCARA_Arm3D"`). Don't loop by array index. The joint name unambiguously selects the right axis.
- **GDB_MCDData has two sets** intentionally:
  - `Position[1..4]` (kinematic-group, NX MCD compatibility)
  - `J{n}_ActualPosition` (joint-name, HMI parity + PLCSIM-Adv API parity)
  Both are kept. Don't "deduplicate" — they serve different consumers.
- **If a new FB needs joint-indexed math** (e.g., per-joint configuration arrays), use a fixed mapping table at the top of the FB rather than relying on either convention to "just work":
  ```scl
  // Joint-name -> kinematic-group index map (deliberate misorder)
  CONST
      KG_INDEX_J1 : Int := 1;
      KG_INDEX_J2 : Int := 3;   // NOT 2 (kinematic-group swap)
      KG_INDEX_J3 : Int := 2;   // NOT 3 (kinematic-group swap)
      KG_INDEX_J4 : Int := 4;
  END_CONST;
  ```

## 7. Why deliberate (the by-design rationale)

The Siemens SCARA-3D TO_Kinematics expects its 4 axes to follow a specific order that lets the IK solver express the SCARA geometry as a chain:
1. A[1] = column base rotation (azimuth) — REVOLUTE
2. A[2] = vertical translation (Z) — PRISMATIC
3. A[3] = elbow rotation — REVOLUTE
4. A[4] = wrist rotation — REVOLUTE

This order (R-P-R-R) is what makes the IK matrix solvable analytically for SCARA. The joint-name convention (J1=base, J2=elbow, J3=Z, J4=wrist) is the human/operator naming derived from the mechanical assembly order.

Renaming the joints to match kinematic-group order (e.g., calling the Z-axis "J2") would propagate confusion across documentation, training materials, NX MCD, and operator panels. The TO_Axis names (`J1_SCARA_Arm3D` etc.) are aliases that keep the joint-name convention while the kinematic group uses its own internal order. The two views coexist forever.

## 8. Closure markers

- [INFORMATIONAL → HMI] — bindings in cycle-7.2 should follow joint-name convention (Phase G surface) and avoid `ScaraArm3D.AxesData.A[i]` for per-axis display
- [INFORMATIONAL → future PLC] — when adding new FBs, declare MC instances by joint TO name; if joint-indexed math needed, use explicit `KG_INDEX_J{n}` constants
- [DELIBERATE BY DESIGN] — the J2/J3 swap is a Siemens SCARA-3D kinematic-solver requirement, NOT a bug to fix

---

## Cross-references

- `PLC_HANDOFF_2026-05-17_C66_PhaseC_HMI_Verified.md` §6.1 — first observation during Phase C V6 smoke
- `HMI_BINDING_MAP.md` §6.3 — binding-table form of the same map
- `PLC_HANDOFF_2026-05-18_C67_PhaseG_ManualCtrlImplemented.md` §3 — Phase G per-joint mirror tags use joint-name convention (no swap)
- `PLC_1/Technology objects/ScaraArm3D.xml` — TO_Kinematics XML defining the A[1..4] kinematic-group order (the source of truth for the deliberate misorder)
- `harness/SmokeTest_PhaseC_V6.ps1` — V7-partial.MirrorMatchInfo gate logs the swap as INFO, not a fail
- `harness/SmokeTest_PhaseG.ps1` — uses `Position[1]` for J1 and `Position[4]` for J4 (no-swap joints); avoided J2/J3 via array index in this round
