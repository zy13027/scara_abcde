# PLC_HANDOFF — 2026-05-23 — Bundle notification for scara-HMI: Modules D + E + F PLC-side VERIFIED

**Status:** INFORMATIONAL — 3 PLC modules feature-complete, 3 HMI screens unblocked

This is a **pointer doc** for the scara-HMI agent's next session. The actual binding contracts + PSC handshake details + mutex semantics live in the three individual module handoffs and in `HMI_BINDING_MAP.md` §10 / §11. Read this first to get oriented; then dive into the per-module handoffs as needed.

---

## What landed today (2026-05-23)

Three Phase 2 PLC modules shipped + 离线功能调试 verified on PLCSIM-Adv `DemoScara_ABCDE`:

| Module | Phase 2 § | Scope | Smoke | Handoff |
|---|---|---|---|---|
| **D** | §3.4 / §5 | Recipe-driven box sizes — single recipe slot, PSC-bound, auto-grid from product + pallet dims | 14/14 PASS | `PLC_HANDOFF_2026-05-23_ModuleD_Recipe.md` |
| **E V3.0** | §3.5 / §6 | Dual-pallet operator-driven manual switching (recipe1 + recipe2; 万尔芯客户项目 as design reference; V3.0 added 3 bug fixes via critical review) | 27/27 PASS | `PLC_HANDOFF_2026-05-23_ModuleE_DualPallet.md` |
| **F V1.2** | §3.6 / §7 | Teach mode 第 4 互斥模式 (4-way mutex: ABCDE / 码垛 / 手动 / 示教); TCP + joint angle capture per §7.1 spec; replay walks captured slots | 24/24 PASS | `PLC_HANDOFF_2026-05-23_ModuleF_Teach.md` |

**Total: 65 / 65 离线功能调试 检查项 PASS.**

Module E supersedes Module D's data shape (`recipe` → `recipe1` + `recipe2`); rebind map for the singular→dual transition lives in Module E handoff §10.4 (Section 9 of binding map is marked DEPRECATED).

---

## 3 HMI screens to author

### 1. Recipe PSC (Parameter Set Control) — covers V11 + V12

**Binding contract:** `HMI_BINDING_MAP.md` §10.1 + Module E handoff §3.1.

- Two **Parameter Set Controls** (one per pallet) — OR one PSC with two parameter-set groups (vendor UX choice).
- Each PSC binds member-for-member to `GDB_ActiveRecipe.recipe1.*` (pallet 1, LEFT) / `recipe2.*` (pallet 2, RIGHT).
- **PSC handshake (MANDATORY)** per pallet — atomic mid-write race protection:
  1. Write `recipeN.bo_Valid := FALSE`
  2. Write all `recipeN.product.*` + `.pallet.*` + `.dynamics.*` + `.sName`
  3. Write `recipeN.bo_Valid := TRUE`
- Multi-recipe library = HMI panel storage (SD/USB per WinCC Unified PSC pattern); the PLC holds only the active recipe slots.

**Field list** (per pallet — 14 fields each):
- `recipe{N}.sName` (String[32])
- `recipe{N}.bo_Valid` (Bool, handshake)
- `recipe{N}.product.{lr_Length, lr_Width, lr_Height, lr_Gap}` (LReal mm)
- `recipe{N}.pallet.{lr_BaseLength, lr_BaseWidth, i16_LayerCount}` (LReal / LReal / Int)
- `recipe{N}.dynamics.{lr_Velocity, lr_Acceleration, lr_Deceleration, lr_Jerk}` (LReal)

**Per-pallet status echoes** (read-only, display):
- `bo_PatternValid{N}` / `bo_PatternError{N}` (Bool — validation lamps)
- `i16_ComputedGridColsX{N}` / `i16_ComputedGridRowsY{N}` / `i16_ComputedBoxCount{N}` (Int — auto-fit results)

**Ceiling**: per-pallet `LayerCount × Cols × Rows ≤ 22` (path aCmd[200] / 9-cmds-per-box). Over-ceiling recipes get `bo_PatternError{N} := TRUE` + `GDB_PalletizingCmd` untouched.

---

### 2. 双盘 operator UI — covers V13 + V14

**Binding contract:** `HMI_BINDING_MAP.md` §10.2 + §10.3 + §10.6 (V3.0 additions) + Module E handoff §3.2.

**Operator-driven manual switch** (设计参考万尔芯客户项目, not auto-advance):

| Widget | Binding | Type | Notes |
|---|---|---|---|
| "执行托盘 1" 按钮 | `GDB_ActiveRecipe.bo_ExecutePallet1` | W Bool (MAINTAINED) | Hold while pallet 1 is the active target |
| "执行托盘 2" 按钮 | `GDB_ActiveRecipe.bo_ExecutePallet2` | W Bool (MAINTAINED) | Hold while pallet 2 is the active target |
| 当前活动托盘 IOField | `GDB_ActiveRecipe.i16_ActivePalletIdx` | R Int | 0 = idle / stalemate / active-side full; 1 / 2 = active pallet |
| 托盘 1 满垛 lamp + alarm | `GDB_ActiveRecipe.bo_Pallet1Full` | R Bool | Latched on bo_PalletDone for **in-flight pallet** (V3.0: snapshotted at bo_InitPallet rising edge — mid-cycle swaps cannot mis-attribute) |
| 托盘 2 满垛 lamp + alarm | `GDB_ActiveRecipe.bo_Pallet2Full` | R Bool | Mirror |
| 托盘 1 复位 Ack 按钮 (V3.0) | `GDB_ActiveRecipe.bo_AckPallet1Full` | W Bool (MAINTAINED) | While TRUE, FB clears bo_Pallet1Full. For "physically refilled, ready to re-use" gesture WITHOUT having to swap to pallet 2 |
| 托盘 2 复位 Ack 按钮 (V3.0) | `GDB_ActiveRecipe.bo_AckPallet2Full` | W Bool (MAINTAINED) | Mirror |
| 双盘满信号 lamp (V3.0) | `GDB_ActiveRecipe.bo_BothPalletsFull` | R Bool | FB-computed = pallet1Full AND pallet2Full; HMI single-status for "both pallets need unloading, robot should idle" |

**Mutex rules** (enforced by FB_PatternAutoGen V3.0):
- Both flags FALSE → idle (idx 0)
- Both flags TRUE → idle (stalemate; HMI should ideally prevent via XOR UX)
- One flag TRUE AND that side not full → that pallet active
- One flag TRUE AND that side full → idle (operator must press OTHER side to swap, OR press Ack button to clear satisfied)

**WanErXin-style swap-clear** (level-driven): pressing the OPPOSITE side's button while THIS side's button is released auto-clears this side's full bit ("I emptied this pallet" gesture). V3.0 Ack reset is the alternative path.

---

### 3. 示教 point table screen — covers V15 + V16 + V17

**Binding contract:** `HMI_BINDING_MAP.md` §11 + Module F handoff §3.

**4-mode radio selector** (atop screen or in TopBar):

| Mode | Binding | Notes |
|---|---|---|
| ABCDE | `GDB_MachineCmd.bo_Mode` | Phase 1 5-point cycle (transitional) |
| 码垛 (Palletizing) | `GDB_PalletizingCmd.bo_Mode` | Modules C/D/E |
| 手动 (Manual) | `GDB_ManualCmd.bo_Mode` | Cartesian jog + KinGo |
| **示教 (Teach)** | `GDB_TeachCmd.bo_Mode` | **NEW Module F** |

HMI should radio-button these — exactly one active. PLC mutex enforces — but the HMI's XOR UX avoids confusion. **When teach mode is active**, FB_TeachCtrl mirrors the manual mode's jog interface (`GDB_ManualCmd.bo_J{1..4}_JogForward/Backward`) so operator can use the same jog buttons.

**Slot table view** (16 rows; per-row display):

| Column | Binding | Type | Notes |
|---|---|---|---|
| Slot # | (1..16, static label) | — | |
| 名字 (optional) | `GDB_TeachPoints.aPoints[i].sName` — wait, this UDT doesn't have sName. Skip column or operator fills externally | — | LKinCtrl_typePoint has `name : WString` — bind as String |
| TCP X | `GDB_TeachPoints.aPoints[i].position[0]` | R LReal | mm in WCS |
| TCP Y | `GDB_TeachPoints.aPoints[i].position[1]` | R LReal | mm |
| TCP Z | `GDB_TeachPoints.aPoints[i].position[2]` | R LReal | mm |
| TCP A | `GDB_TeachPoints.aPoints[i].position[3]` | R LReal | deg (wrist) |
| 已捕获 icon | `GDB_TeachPoints.abCaptured[i]` | R Bool | filled / empty visual |
| **(V1.1 optional) J1-J4 secondary view** | `GDB_TeachPoints.aJointAngles[i, 1..4]` | R LReal | J1/J2/J4 deg, J3 mm |

**Slot selector + status:**
| Widget | Binding | Type |
|---|---|---|
| 当前槽位 selector | `GDB_TeachCmd.i16_SlotIdx` | W Int (1..16) |
| 已用槽数 IOField | `GDB_TeachPoints.i16_PointCount` | R Int (0..16) |

**Operator action buttons** (all edge-triggered PULSE 250ms via HMI JS):
| 按钮 | Binding | Notes |
|---|---|---|
| 捕获 (Capture) | `GDB_TeachCmd.bo_Capture` | Writes BOTH TCP + joint angles into aPoints[idx] + aJointAngles[idx] |
| 移到此点 (Verify) | `GDB_TeachCmd.bo_Verify` | Drives robot to aPoints[idx] via Cartesian linear move |
| 清单点 (Clear) | `GDB_TeachCmd.bo_Clear` | Zeros aPoints[idx] + aJointAngles[idx] + abCaptured[idx] |
| 清全部 (ClearAll) | `GDB_TeachCmd.bo_ClearAll` | Wipes all 16 slots atomically |
| 启动回放 (StartReplay) | `GDB_TeachCmd.bo_StartReplay` | FSM walks aPoints in slot-index order, skipping !abCaptured |
| 停止回放 (StopReplay) | `GDB_TeachCmd.bo_StopReplay` | Aborts mid-replay; clears bo_execute |
| 回放速度 IOField | `GDB_TeachCmd.lr_ReplayVel` | W LReal mm/s |

**Status echoes:**
| 字段 | Binding | Type |
|---|---|---|
| TeachStep state | `GDB_TeachCmd.i16_TeachStep` | R Int (0/10/30/100-120) |
| 回放索引 | `GDB_TeachCmd.i16_ReplayIdx` | R Int (0..16) — current replay slot |
| 回放完成 lamp | `GDB_TeachCmd.bo_ReplayDone` | R Bool — latched at end of replay |

**Live TCP IOFields** (for jog feedback while teaching) — bind to `GDB_AxisCtrl.LKinCtrl.output.actualposition.{x,y,z,a,b,c}` — populated by FB_AxisCtrl's new `MirrorTCP` REGION from `ScaraArm3D.TcpInWcs.{x,y,z,a,b,c}.Position` (Siemens-canonical TO_Kinematics member). Mirror runs every OB30 scan (~10ms).

---

## What scara-HMI should do next session

Recommended order:

1. **Read this bundle handoff** (you're here).
2. **Read `HMI_BINDING_MAP.md` §10 + §11 in full** — authoritative binding contract.
3. **Read the 3 individual PLC handoffs** for details on PSC handshake / mutex semantics / replay state machine: `PLC_HANDOFF_2026-05-23_Module{D,E,F}_*.md`.
4. **Decide screen layout** for the 3 new screens — fitting within UBP 5-control-per-screen budget (Module E + Module F may each need their own dedicated screen; recipe PSC could share with Module E's 双盘 UI if widget-budget allows).
5. **Author screens** using C# Openness builders at `E:\VS_Code_Proj\TiaUnifiedAuto\Builders\Ubp\`.
6. **Write a response handoff** when done: `HMI_HANDOFF_2026-05-23_Cycle7_X_Phase2_ModulesDEF_Response.md` (or whatever cycle # is next) ACKing the 3 modules + reporting screens authored + flagging any binding gaps you found.

---

## Followups (not blocking screen authoring)

1. **Carry-forward `[BLOCKED-ON-PLC]` from HMI_HANDOFF_2026-05-22_GDB_Control_Replacement.md** — 7 broken PLC paths (3 W commands `enableAxes/homeAxes/resetAxes` + 4 R status `axesEnabled/Homed/Error/Ready`). PLC side owes a flat-facade response (B.29). Independent of D/E/F work — separate track.
2. **Pre-existing FB_ManualCtrl quirk** (NOT a regression — long-standing): auto-disables axis when `statManualOK = TRUE` + no enable button held. May surface as "axis silently disables during mode-switch" in HMI smoke. Workaround: ensure enable button is held during the mode-switch transition.
3. **V1.1 joint capture is archival only** for now. If you want a separate joint-PTP replay path, that's a future V1.3 PLC extension (per-slot `bo_IsPTP` flag routing into `movelinear.bo_isPTP`); flag it via HMI handoff and PLC will scope.

---

## Cross-references

- `PLC_HANDOFF_2026-05-23_ModuleD_Recipe.md` — Module D (recipe-driven box sizes)
- `PLC_HANDOFF_2026-05-23_ModuleE_DualPallet.md` — Module E V3.0 (dual-pallet + 万尔芯 review fixes)
- `PLC_HANDOFF_2026-05-23_ModuleF_Teach.md` — Module F V1.2 (teach mode + V1.1 joint extension + V1.2 jog-gate fix)
- `HMI_BINDING_MAP.md` §10 (Module E) + §11 (Module F) — binding contract
- `Phase2计划_杨子楠.md` — operator plan (V1-V20 acceptance + 现状 rows per module)
- `PM_Workspace/PM_HANDOFF_2026-05-23_Phase2_ModulesDEF_Verified.md` — PM-side consolidated session summary
- `PM_Workspace/SCOREBOARD_PLC.md` B.30 / B.31 / B.32 / B.33 / B.34 rows — tracker entries

---

_End of PLC_HANDOFF_2026-05-23_HMI_BundleNotification_ModulesDEF.md_
