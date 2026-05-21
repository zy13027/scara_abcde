# Phase 2 计划 · Agent 版 — 码垛全链路联合仿真 + 配方/示教/双托盘/参数化

_本计划由 scara-PM 制定，供 **scara-PLC agent**（PLC SCL/XML/GDB 代码）、**scara-HMI agent**（HMI 画面）、**scara-PM agent**（handoff / 记账 / 跟踪）三方共同执行。同一份 Phase 2 另有《人工版》(`Phase2计划_杨子楠.md`) 供操作员杨子楠执行（NX 搭建 / TIA 部署 / 决策 / 验收）。**两份计划独立、对等，覆盖同一 Phase 2 —— 同样 6 目标、8 模块、V1–V20。** 本版只列 agent 侧的代码与跟踪任务。_

## 目标 ( 6 件)

1. **传送带 + 纸盒产生源联合仿真** — 纸盒由 MCD 产生源真实生成、随传送带运动、到位传感器检测；HMI 启动 → PLC 驱动带速 + 节奏化触发生箱 → MCD 跟动
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
| `PLC_HANDOFF_2026-05-19_FullSimulationFitOut_*.md` | V3.0 完整设计 + NX 探测坐标 + 15 关冒烟清单 | `VCIExportedContents/` |
| `PLC_HANDOFF_2026-05-19_MCDSignalAdditions_*.md` | MCD 15 信号清单 + GDB 结构 | `VCIExportedContents/` |
| `FB_AutoCtrl_ABCDE.scl` V8 | 4 REGION 状态机 + progress blending 范式 | `PLC_1/.../500_AutoCtrl/` |
| `FB_AutoCtrl_Palletizing.scl` | 码垛 FB（V2.0 基线 / V3.0 在改）| 同上 |
| `FB_ManualCtrl.scl`（Phase G）| 示教功能的手动 jog 底座 | 同上 |
| `TiaUnifiedAuto/Builders/Ubp/` | scara-HMI 的 C# Openness 画面 builder | `E:\VS_Code_Proj\` |

## 开发现状 (起点 — 不要重做已完成项)

| 项 | 状态 | 接手模块 |
|---|---|---|
| Phase 1 / Phase G 手动 / 码垛 V2.0 / C71 门面 / J2 取模 | ✅ 已验证 | 保留不动 |
| V3.0 箱体编排码垛源码 | 🚧 已落地、未走完部署验证 | §3 补全 + 调试 |
| FB_ConveyorCtrl 带速 FB | 🚧 已草拟、未编译验证 | §2 接手 |
| GDB_MCDData +5 信号 | 🚧 源码已扩、未部署 | §2（操作员部署）|
| 配方 / 示教 / 双托盘 / 参数化 | ⬜ 未开始 | §4 – §7 |

## 开工前输入 (操作员杨子楠提供)

agent 写代码前需操作员定 **D1–D7 设计决策** + 完成 **§1 MCD 环境搭建（V1）**。决策值见《人工版》「开工前决策」，由操作员填好后转 agent —— agent 据此填对应 GDB 的 StartValue。决策未到位 / V1 未达成前，§2 起的代码不开工。

## 1. MCD 侧仿真准备

本模块全部为操作员 NX / TIA 工作（见《人工版》§1）。**agent 侧无代码任务** —— 等操作员完成 MCD 搭建、V1 达成后，§2 起开工。scara-PM 跟踪 V1 状态。

## 2. 传送带 + 生箱 PLC 逻辑　（scara-PLC agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 2.1 | FB_ConveyorCtrl 校验 | 带速驱动 FB 已草拟，检查 + 编译 | 通读 FB_ConveyorCtrl.scl：抓取下降 BeltVelocity→0，其余=设定速；编译 0E/0W；挂 Main | 🟡 中 | 4h |
| 2.2 | 生箱节奏脉冲 | 码垛 FB 收尾段脉冲 SpawnContainerCmd | 上升沿契约：脉冲 1 扫描后自动清零 | 🟡 中 | 3h |
| 2.3 | 到位传感器门 | PalletizingSensor 上升沿 = 抓取门 | FB 内 `R_TRIG(CLK:=GDB_MCDData.PalletizingSensor)` | 🟡 中 | 3h |
| 2.4 | §2 handoff | scara-PM 写 §2 PLC handoff | 状态线 + 验收点 + 给操作员的部署 runbook | 🟢 简单 | 2h |

## 3. 精细码垛逻辑 — FB_AutoCtrl_Palletizing V3.0　（scara-PLC agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 3.1 | FB V3.0 状态机补全 | 单箱 6 阶段状态机（源码已落地，补全 + 调试支持）| 按 FullSimulationFitOut §3–4 骨架补全 `// ...` 段 | 🔴 难 | 1.5d |
| 3.2 | iDB + GDB 对齐 | instFB +10 / GDB_PalletizingCmd +16 / GDB_Control +2 | XML Member 与 FB VAR 对齐 | 🟡 中 | 4h |
| 3.3 | 调试支持 | 配合操作员定位 6 阶段卡点 | 看操作员回传的 Watch Table / trace，改 SCL 再交 | 🔴 难 | 1d |
| 3.4 | V3 冒烟脚本 | SmokeTest_PalletizeOrchestrated_V3.ps1 — 15 关 | PowerShell + PLCSIM-Adv API，按 handoff §6 | 🟡 中 | 1d |
| 3.5 | §3 handoff | scara-PM 写 handoff | 状态线 + 验收 + 部署 runbook | 🟢 简单 | 2h |

## 4. 参数化 FB（配方注入的前置）　（scara-PLC agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 4.1 | 硬编码盘点 | 列码垛 FB 所有硬编码常量（箱数 / 层数 / 速度 / 间距）| 通读 FB_AutoCtrl_Palletizing.scl 列清单 | 🟢 简单 | 2h |
| 4.2 | 常量外提 | 改 VAR_INPUT / GDB_PalletizingCmd 引用 | 补 config Member，FB 内替换硬编码 | 🟡 中 | 4h |
| 4.3 | 路径计算参数化 | REGION 1 pts[] 用 层数 / 每层箱数 / 间距 参数 | FOR 循环上下界 + 步距改参数表达式 | 🔴 难 | 1d |
| 4.4 | 接口规范化 + 回归 | VAR_INPUT/OUTPUT 整理注释；重跑 V3 冒烟 | 整理 + SmokeTest 回归不退步 | 🟡 中 | 4h |

## 5. 配方驱动箱体尺寸　（scara-PLC + scara-HMI agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 5.1 | UDT_Recipe + 配方表 DB | scara-PLC：箱尺寸 / 层数 / 速度 字段 + 多组配方表 | 新建 UDT XML + GDB_ActiveRecipe + 配方表 DB | 🟡 中 | 5h |
| 5.2 | 配方加载逻辑 | scara-PLC：选配方号 → 拷贝到 GDB_ActiveRecipe | FB / Main：`MOVE_BLK` 配方表[n] → ActiveRecipe | 🟡 中 | 4h |
| 5.3 | 码垛读配方 | scara-PLC：路径计算读 GDB_ActiveRecipe | §4 参数源指向 ActiveRecipe 字段 | 🔴 难 | 1d |
| 5.4 | 配方画面 | scara-HMI：配方号选择 + 字段显示 / 编辑 | C# Openness builder 新增配方画面 | 🟡 中 | 1d |
| 5.5 | §5 handoff | scara-PM 写 handoff | 状态线 + 验收 + 部署 runbook | 🟢 简单 | 2h |

## 6. 双托盘切换　（scara-PLC agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 6.1 | 双托盘路径 | Pallet 1(+Y) / Pallet 2(-Y) 两套 pts[] | pts 扩 2 组，或路径计算加 Y 偏置参数 | 🟡 中 | 4h |
| 6.2 | 切换逻辑 | statActivePallet；Pallet 1 满 → 自动切 2 续码 | 码满判断 → 切托盘 → 重置 boxIdx | 🔴 难 | 1d |
| 6.3 | 全满收尾 | 双盘满 → bo_AllPalletsDone | 收尾分支 + 完成灯 | 🟢 简单 | 3h |
| 6.4 | 冒烟扩展 + handoff | SmokeTest 加双盘用例；scara-PM 写 handoff | 扩 SmokeTest；handoff 状态线 + 验收 | 🟡 中 | 5h |

## 7. 示教功能　（scara-PLC + scara-HMI agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 7.1 | 点位捕获逻辑 | scara-PLC：捕获脉冲 → 当前 TCP/关节 写点表 | FB：脉冲 → MOVE ActualPosition → GDB_TeachPoints[idx] | 🟡 中 | 4h |
| 7.2 | 点表 DB | scara-PLC：GDB_TeachPoints 数组 | 新建 DB XML | 🟡 中 | 3h |
| 7.3 | 示教点应用 | scara-PLC：路径源切换参数 | FB 加路径源选择（硬编码 / 配方 / 示教点表）| 🔴 难 | 1d |
| 7.4 | 点表画面 | scara-HMI：点表看 / 选 / 清 画面 | C# Openness builder | 🟡 中 | 1d |
| 7.5 | §7 handoff | scara-PM 写 handoff | 状态线 + 验收 + 部署 runbook | 🟢 简单 | 2h |

## 8. 端到端联合仿真验证　（scara-PLC / scara-HMI / scara-PM agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 8.1 | HMI 画面收口 | scara-HMI：配方 / 示教 / 双托盘 画面联调 | 各画面绑对应 GDB，TIA HMI 编译 0E/0W | 🟡 中 | 1d |
| 8.2 | 冒烟套件回归 | scara-PLC/HMI 跑全部 SmokeTest | PLCSIM-Adv API；ABCDE / 手动 互斥不退步 | 🟡 中 | 4h |
| 8.3 | 验证 handoff + 收口 | scara-PM 汇总 V1–V20 + 更新 SCOREBOARD / LEDGER | bundle handoff + 跟踪表 | 🟡 中 | 4h |

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

## 任务规模与排期

| 模块 | 负责 agent | 规模估 | 前置依赖 |
|---|---|---|---|
| §1 MCD 准备 | （操作员，agent 不参与）| — | — |
| §2 传送带 + 生箱 | scara-PLC | ~1.5 人天 | §1 操作员 V1 |
| §3 精细码垛 V3.0 | scara-PLC | ~4 人天 | §2 |
| §4 参数化 FB | scara-PLC | ~2.5 人天 | §3 |
| §5 配方驱动 | scara-PLC + scara-HMI | ~3.5 人天 | §4 |
| §6 双托盘切换 | scara-PLC | ~2.5 人天 | §3 §4 |
| §7 示教功能 | scara-PLC + scara-HMI | ~3.5 人天 | Phase G（已就绪）|
| §8 端到端验证 | scara-PLC/HMI/PM | ~2.5 人天 | 全部 |
| **合计** | | **~20 人天** | |

**说明**：scara-PM 全程并行（每模块 1 份 handoff + SCOREBOARD/LEDGER 跟踪，不单列）。agent 代码产出快；真实日历周期由操作员的部署 / 验收节奏决定 —— 见《人工版》。**依赖**：§1→§2→§3 串行；§4 接 §3；§5 §6 接 §4；§7 可早派（依赖已就绪 Phase G）；§8 收尾。每模块"agent 产出 → 操作员部署 → 冒烟绿"后再进下一个。

## 阶段总结

main target 是把 Phase 1 跑通的 ABCDE 单臂循环，升级为一套 **完整、可配置、可示教** 的码垛工作站联合仿真。本版是 agent 侧执行计划：scara-PLC agent 写 PLC SCL/XML/GDB，scara-HMI agent 写 HMI 画面，scara-PM agent 每模块出 handoff + 维护 SCOREBOARD/LEDGER。

代码就绪后移交操作员杨子楠部署、验收（见《人工版》）。两份计划独立对等、覆盖同一 Phase 2。本阶段目标由 2 项扩为 6 项，是杨子楠（本计划负责人）2026-05-21 定的范围决策 —— 有意为之、非自行发散。范围边界仍在：真实硬件下装、多工位、物理清盘 推迟 Phase 3+。Phase 1 成果保留不动；延续不用第三方库、每扫描单 MC 实例两条铁律。
