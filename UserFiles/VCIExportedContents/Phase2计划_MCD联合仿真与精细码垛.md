# Phase 2 计划 — 码垛全链路联合仿真 + 配方/示教/双托盘/参数化（人工开发任务分解）

_本计划由 scara-PM 对照杨子楠 5/17 周计划结构续写，并依据 PLC 侧 handoff 与 PROJECT_STATUS 现状重排。目标经郑老板 2026-05-21 拍板定为 6 项。**本版面向纯人工开发**：每个任务给出具体人工操作方法与工时估算，按模块标注负责角色，供 PLC / HMI / 仿真 工程师领取执行。_

## 目标 ( 6 件)

1. **传送带 + 纸盒产生源联合仿真** — 纸盒由 MCD 产生源真实生成、随传送带运动、到位传感器检测；HMI 按启动 → PLC 驱动带速 + 节奏化触发生箱 → MCD 跟动
2. **更精细的码垛逻辑** — SCARA 从带末端真实抓取（吸盘夹爪握手）→ 码放到计算位 → 单箱 6 阶段状态机 → 满箱自动收尾、分层码放
3. **配方驱动箱体尺寸** — 配方系统存箱体长宽高 / 每层箱数 / 层数 / 速度；码垛路径按当前配方实时计算，不再硬编码
4. **示教功能** — 操作员手动 jog 机械臂到目标点 → 一键捕获 TCP 位置写入点表；码垛 / ABCDE 路径可选用示教点
5. **双托盘切换** — Pallet 1 码满后自动切换到 Pallet 2 继续；两托盘全满收尾
6. **参数化 FB** — 关键 FB 硬编码值外提为输入参数 / GDB 引用，接口规范化（配方注入的前置）

**不做** (推迟 Phase 3+): 真实硬件下装（仅 PLCSIM-Adv 仿真）/ 多工位多机器人 / pallet 满料后纸盒物理清盘（Object Sink）
**保留不动**: Phase 1 的 ABCDE 5 点循环、C71 HMI 状态门面、报警、IO
**不用任何的库**: 延续 Phase 1，只用 MC_MoveLinearAbsolute 等 TO 内置标准 FB
**关键不变式**: 每扫描周期 ScaraArm3D 上只有 1 个 MC_MoveLinearAbsolute 实例在跑（OB91 安全）

## 必备学习 (开工前通读)

| 参考 | 用途 | 位置 |
|---|---|---|
| `PLC_HANDOFF_2026-05-19_FullSimulationFitOut_*.md` | V3.0 完整设计 + NX 探测坐标 + 部署 runbook + 15 关冒烟清单 | `VCIExportedContents/` |
| `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_*.md` | MCD 15 信号清单 + GDB 映射 runbook | `VCIExportedContents/` |
| `FB_AutoCtrl_ABCDE.scl` V8 | 4 REGION 状态机 + progress blending 范式 | `PLC_1/.../500_AutoCtrl/` |
| `FB_AutoCtrl_Palletizing.scl` | 码垛 FB（V2.0 基线 / V3.0 在改）| 同上 |
| `FB_ManualCtrl.scl`（Phase G）| 示教功能的手动 jog 底座 | 同上 |
| NX MCD 信号适配器机制 | Object Source / Transport Surface / 碰撞传感器 / SignalAdapter | NX 工程 + `E:/RAG` motion-control-rag |

## 开发现状 (人工开发的起点 — 不要重做已完成项)

| 项 | 状态 | 说明 / 接手模块 |
|---|---|---|
| Phase 1（ABCDE 5 点循环 + MCD 联动）| ✅ 完成验证 V1–V9 | 保留不动 |
| Phase G 手动控制（FB_ManualCtrl）| ✅ 代码完成、冒烟 16/16 | 待接 HMI；示教（§7）直接复用 |
| 码垛 V2.0（48 点 place-only）| ✅ 验证 12/12 | V3.0 的改造基线 |
| C71 HMI 状态门面 | ✅ 验证 9/9 | 保留不动 |
| J2 取模修复（[0,360°)）| ✅ 端到端验证 | 保留不动 |
| V3.0 箱体编排码垛源码 | 🚧 已落地、5/20–21 测试中、尚无验证收尾 | §3 接手部署 + 调试收尾 |
| FB_ConveyorCtrl 带速 FB | 🚧 已草拟、未编译验证 | §2 接手 |
| GDB_MCDData +5 信号 | 🚧 源码已扩、未导入 TIA + 未映射 | §1 + §2 部署 |
| 配方 / 示教 / 双托盘 / 参数化 | ⬜ 未开始 | §4 – §7 |

## 1. MCD 侧仿真准备　（负责：NX / 仿真工程师）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 1.1 | 纸盒产生源 | Object Source 被触发时在带源头生成纸盒 | NX MCD → Mechatronics → Object Source；指定纸盒 RigidBody 原型 + 生成位姿 | 🟡 中 | 4h |
| 1.2 | 生箱信号接入 | saContainerBelt 补 sActivateSpawnContainer | 双击 saContainerBelt → Parameters 加一行绑 Object Source 触发参数 → Formulas 加 `pActivateSpawnContainer ← sActivateSpawnContainer` | 🟡 中 | 3h |
| 1.3 | 吸盘信号接入 | sScaraGrip（吸真空）+ sScaraRelease（释放）绑物理 | SignalAdapter → 确认 2 信号有 Formula 绑到吸盘 attach/detach 行为 | 🟡 中 | 4h |
| 1.4 | 第二托盘 | Pallet 2（-Y 镜像位）在场景内 | NX 已探测 PALLET_SOUTH ≈ (-0.5,-1500,-867)；缺则镜像 Pallet 1 | 🟢 简单 | 2h |
| 1.5 | TIA 外部信号映射 | GDB_MCDData 新增信号映射到 MCD 15 信号 | TIA → 设备网络 → SCARA 站 → 运动系统 → 外部信号映射 → Do Auto Mapping + 手动补 → Check N→1 → OK | 🟡 中 | 3h |

## 2. 传送带 + 生箱 PLC 逻辑　（负责：PLC 工程师）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 2.1 | GDB_MCDData 部署 | +5 Member 已加源码，需导入 TIA | VCI 导入 GDB_MCDData.xml → 编译 0E/0W → PLCSIM-Adv MRES（GDB 形状变了，必做）→ 下装 | 🟢 简单 | 2h |
| 2.2 | FB_ConveyorCtrl 校验 | 带速驱动 FB 已草拟，需检查 + 编译 | 通读 FB_ConveyorCtrl.scl：抓取下降时 BeltVelocity→0，其余=设定速；编译 0E/0W；挂 Main 调用 | 🟡 中 | 4h |
| 2.3 | 生箱节奏脉冲 | 每码完一箱脉冲 SpawnContainerCmd 一个扫描 | 码垛 FB 收尾段写 `SpawnContainerCmd:=TRUE`，下一扫描清零（上升沿契约）| 🟡 中 | 3h |
| 2.4 | 到位传感器检测 | PalletizingSensor 上升沿 = 抓取门 | FB 内 `R_TRIG(CLK:=GDB_MCDData.PalletizingSensor)`；触发后停带进入抓取 | 🟡 中 | 3h |
| 2.5 | 单元冒烟 | Watch Table 验证带速 / 生箱 / 传感器 | 按 MCDSignalAdditions handoff §4 脚本：写 BeltVelocity、脉冲 Spawn、NX viewport 观察 | 🟡 中 | 3h |

## 3. 精细码垛逻辑 — FB_AutoCtrl_Palletizing V3.0　（负责：PLC 工程师）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 3.1 | V3.0 源码部署 | FB V3.0 + iDB +10 + GDB_PalletizingCmd +16 + GDB_Control +2 | VCI 导入 4 文件 → 编译 → MRES → 下装（按 FullSimulationFitOut handoff §5 runbook）| 🟡 中 | 3h |
| 3.2 | 6 阶段状态机调试 | 单箱 抓取 3 阶段 + 码放 3 阶段 顺序跑通 | PLCSIM Watch Table 单步：statPhase 1→2→3→4→5→6；每阶段 MC.Done 转步 | 🔴 难 | 1d |
| 3.3 | 吸盘握手调试 | PICK_DESCEND 末闭合 300ms、PLACE_DESCEND 末释放 200ms | 看 bo_gripperGrip/Release 时序 + TON；NX viewport 看纸盒 attach/detach | 🔴 难 | 1d |
| 3.4 | 满箱自动收尾 | 16 箱码完 → bo_PalletDone、带停、循环停 | 验证 statBoxesPlaced 计数 + COMPLETE 分支 | 🟡 中 | 4h |
| 3.5 | 冒烟测试 | SmokeTest_PalletizeOrchestrated_V3.ps1 — 15 关 | 跑脚本，逐关定位失败（参考 handoff §6 失败诊断链）| 🟡 中 | 1d |

## 4. 参数化 FB（配方注入的前置）　（负责：PLC 工程师）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 4.1 | 硬编码盘点 | 列出码垛 FB 所有硬编码常量（16 箱 / 4 层 / 速度 / 间距 / Z 偏置）| 通读 FB_AutoCtrl_Palletizing.scl，列清单 | 🟢 简单 | 2h |
| 4.2 | 常量外提 | 改为 VAR_INPUT 或 GDB_PalletizingCmd 引用 | 补齐缺的 config Member；FB 内引用替换硬编码 | 🟡 中 | 4h |
| 4.3 | 路径计算参数化 | REGION 1 pts[] 计算用 层数 / 每层箱数 / 间距 参数 | FOR 循环上下界 + 步距改成参数表达式 | 🔴 难 | 1d |
| 4.4 | 接口规范化 + 回归 | VAR_INPUT/OUTPUT 整理注释；改完重跑 V3 冒烟不退步 | 整理 + 重新部署 + SmokeTest 回归 | 🟡 中 | 4h |

## 5. 配方驱动箱体尺寸　（负责：PLC + HMI 工程师）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 5.1 | UDT_Recipe 设计 | 箱长宽高 / 每层箱数 / 层数 / 速度 一组字段 | 新建 UDT XML，参考 v9 GDB_ActiveRecipe 字段 | 🟡 中 | 3h |
| 5.2 | 配方表 DB | GDB_ActiveRecipe（当前）+ 配方表 DB（Array of UDT）| 新建 2 个 DB XML，VCI 导入 TIA | 🟡 中 | 3h |
| 5.3 | 配方加载逻辑 | HMI 选配方号 → PLC 拷贝该行到 GDB_ActiveRecipe | FB / Main 段：`MOVE_BLK` 配方表[n] → ActiveRecipe | 🟡 中 | 4h |
| 5.4 | 码垛读配方 | V3.0 路径计算改读 GDB_ActiveRecipe | 把 §4 的参数源指向 ActiveRecipe 字段 | 🔴 难 | 1d |
| 5.5 | HMI 配方画面 | 配方号选择 + 字段显示 / 编辑 | HMI 新增配方画面，绑配方表 DB + ActiveRecipe | 🟡 中 | 1d |

## 6. 双托盘切换　（负责：PLC 工程师）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 6.1 | 双托盘路径 | Pallet 1(+Y) / Pallet 2(-Y) 两套 pts[] | pts 扩 2 组，或路径计算加 Y 偏置参数（接 §4）| 🟡 中 | 4h |
| 6.2 | 切换逻辑 | statActivePallet；Pallet 1 满 → 自动切 2 续码 | 码满判断 → 切托盘 → 重置 boxIdx → 续码 | 🔴 难 | 1d |
| 6.3 | 全满收尾 | 双盘满 → bo_AllPalletsDone | 收尾分支 + 完成灯 | 🟢 简单 | 3h |
| 6.4 | 双托盘冒烟 | Pallet 1→2 切换无停顿错位 | 扩 SmokeTest：连续码满两盘 | 🟡 中 | 4h |

## 7. 示教功能　（负责：PLC + HMI 工程师）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 7.1 | 手动 jog 激活 | Phase G FB_ManualCtrl 接 HMI（代码已就绪）| HMI 手动画面绑 GDB_ManualCmd / GDB_ManualStatus | 🟡 中 | 4h |
| 7.2 | 点位捕获 | "示教"按钮 → 读当前 TCP + 关节 → 写点表 | FB：捕获脉冲 → MOVE ActualPosition → GDB_TeachPoints[idx] | 🟡 中 | 4h |
| 7.3 | 点表管理 | GDB_TeachPoints 数组 + HMI 点表画面（看 / 选 / 清）| 新建 DB + HMI 点表画面 | 🟡 中 | 1d |
| 7.4 | 示教点应用 | 路径源切换：硬编码 / 配方 vs 示教点表 | FB 加路径源选择参数 | 🔴 难 | 1d |
| 7.5 | 示教冒烟 | jog → 捕获 → 回放 验证 | jog 到点、捕获、切示教源、跑路径 | 🟡 中 | 4h |

## 8. 端到端联合仿真验证　（负责：全员）

| # | 内容 | 描述 | 人工操作方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 8.1 | HMI 画面补全 | 配方 / 示教 / 双托盘 画面收尾 | HMI 各画面绑对应 GDB | 🟡 中 | 1d |
| 8.2 | 全链路联调 | HMI 启动 → 生箱→传送→抓取→配方码放→双托盘→收尾 | 端到端，NX viewport 全程观察 | 🟡 中 | 1d |
| 8.3 | 冒烟套件回归 | 各模块冒烟全过 + 无 Phase 1 回归 | 跑全部 SmokeTest，ABCDE / 手动 互斥不退步 | 🟡 中 | 4h |
| 8.4 | 现场可视确认 | NX viewport 完整流程操作员验收 | 操作员现场观察 16 箱码成多层 | 🟢 简单 | 2h |

## 阶段验收标准

| # | 验收点 | 通过条件 |
|---|---|---|
| V1 | MCD 信号接通 | saContainerBelt 4 信号 + 吸盘 2 信号 + 双托盘位 + TIA 映射全部完成 |
| V2 | HMI 启动生箱 | 按 HMI 启动 → MCD 源头出现第一个纸盒 |
| V3 | 传送带运行 | BeltVelocity = 设定值，纸盒随带运动 |
| V4 | 到位停带 | 纸盒到带末端 → 传感器触发 → 带速 1s 内归 0 |
| V5 | 真实抓取 | SCARA 下降、吸盘闭合、纸盒附着到 TCP 抬起 |
| V6 | 真实码放 | SCARA 趋近码放位、下降、吸盘释放、回退 |
| V7 | 单箱 6 阶段 | statPhase 按 1→2→3→4→5→6 顺序推进 |
| V8 | 满箱自动收尾 | 码满当前配方箱数 → bo_PalletDone、带速 0、循环停 |
| V9 | 多层堆叠成型 | NX viewport 可视：箱按配方层数 × 每层箱数 整齐码上 |
| V10 | 参数化生效 | 仅改 GDB 参数（不改代码）→ 层数 / 箱数 / 速度随之变 |
| V11 | 配方切换 | 选不同配方 → 箱体尺寸 / 层数 / 速度 实时生效 |
| V12 | 配方常驻 | 多组配方存表，可重复切换、可重复加载 |
| V13 | 双托盘切换 | Pallet 1 码满 → 自动切 Pallet 2 续码，无停顿错位 |
| V14 | 双托盘收尾 | 两托盘全满 → bo_AllPalletsDone、循环停 |
| V15 | 示教捕获 | 手动 jog 定位 → 一键捕获 → 点位正确写入点表 |
| V16 | 示教点应用 | 路径切到示教点表 → 机械臂走示教点 |
| V17 | 模式互斥 | 码垛 / ABCDE / 手动 / 示教 多模式互不串扰 |
| V18 | 冒烟测试 | 各功能冒烟脚本全部 PASS |
| V19 | 联合仿真可视 | NX viewport 完整跑通：生箱→传送→抓取→配方码放→双托盘→收尾 |
| V20 | 代码量受控 | 单 FB ≤ ~600 行不臃肿；总 SCL ≤ 3000 行（wc -l 自查），不用第三方库 |

## 工时与排期

| 模块 | 负责 | 工时估 | 前置依赖 |
|---|---|---|---|
| §1 MCD 侧仿真准备 | NX / 仿真工程师 | ~2 人天 | 无（最先做）|
| §2 传送带 + 生箱 PLC | PLC 工程师 | ~2 人天 | §1 |
| §3 精细码垛 V3.0 | PLC 工程师 | ~4 人天 | §1 §2 |
| §4 参数化 FB | PLC 工程师 | ~2.5 人天 | §3 |
| §5 配方驱动 | PLC + HMI 工程师 | ~3.5 人天 | §4 |
| §6 双托盘切换 | PLC 工程师 | ~2.5 人天 | §3 §4 |
| §7 示教功能 | PLC + HMI 工程师 | ~3.5 人天 | Phase G（已就绪）|
| §8 端到端验证 | 全员 | ~2.5 人天 | 全部 |
| **合计** | | **~22 人天** | |

**排期建议**：§1→§2→§3 为部署链，必须串行；§4 接 §3；§5、§6 接 §4（可并行）；**§7 示教相对独立**（复用已就绪的 Phase G），可在 §4–§6 期间并行开工；§8 收尾。2 人团队（1 PLC + 1 HMI）+ NX/操作员支持，含并行，预计 **2.5–3 周** 日历周期。每个模块产出独立冒烟验证后再进下一步，避免一次性大改难以定位问题。

## 阶段总结

main target 是把 Phase 1 跑通的 ABCDE 单臂循环，升级为一套 **完整、可配置、可示教** 的码垛工作站联合仿真：纸盒由 MCD 产生源真实生成、随传送带到位，SCARA 用吸盘真实抓放，单箱 6 阶段精细控制；箱体尺寸与堆叠方式由 **配方** 驱动，路径点支持 **示教** 录入，托盘满后 **双托盘自动切换**，关键 FB **参数化** 以便复用。

本阶段目标由 2 项扩为 6 项，是郑老板 2026-05-21 拍板的范围决策 —— 属经授权的范围扩展。范围边界仍在：真实硬件下装、多工位、物理清盘 推迟 Phase 3+。Phase 1 的 ABCDE 循环、报警、IO **保留不动**。延续 Phase 1 两条铁律：不用第三方库、每扫描单 MC 实例。

本计划已按现状重排：§1–§3 大部分是"部署 + 验证已落地源码"（V3.0 码垛 + 传送带 FB + MCD 信号已写好，未走完部署链），§4–§7 为新建功能。开发团队按上表领模块、对照「人工操作方法」列执行、用「阶段验收标准」逐项收口。
