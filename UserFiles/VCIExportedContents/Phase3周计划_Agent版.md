# Phase 3 计划 · Agent 版 — 垛型编辑

**最近更新:** 2026-05-23 — Phase 2 §3.4 §3.5 §3.6 Module D / E / F PLC 侧全部 VERIFIED（D 14/14 + E V3.0 27/27 + F V1.2 24/24）；Phase 3 开工前提：Phase 2 §4（NX-MCD 联仿 Module G）收尾 + scara-HMI 完成 Phase 2 三块画面 + D1/D2 决策定型。**当前状态：agent 侧未开工**。

_本计划由 scara-PM 制定，供 **scara-PLC agent**（PLC SCL/XML/GDB 代码）、**scara-HMI agent**（HMI 画面 + Web 编辑器）、**scara-PM agent**（handoff / 记账 / 跟踪）三方共同执行。同一份 Phase 3 另有《人工版》(`Phase3计划_杨子楠.md`) 供操作员杨子楠执行。**两份计划独立、对等，覆盖同一 Phase 3 —— 同样 4 目标、5 模块、V1–V8。** 本版只列 agent 侧的代码与跟踪任务。_

## 目标 ( 4 件)

1. **手动垛型编辑** — 在 Web 运行时拖拽摆箱，编辑每层 pattern；移植 v9 现成的 WebEditor
2. **自动垛型生成** — HMI 输入箱 / 垛参数 → 自写轻量排样算法生成垛型
3. **逐层编辑** — 手动 / 自动生成的垛型，每一层 pattern 可在 HMI 上单独查看、修改
4. **垛型存取** — 编辑完的垛型存入 HMI 存储介质（PSC 或 LJDM），可重新加载

**不做** (推迟以后): 多机型垛型库 / 在线垛型寻优 / 垛型 3D 预览
**保留不动**: Phase 1 + Phase 2 的全部成果（ABCDE 循环、码垛、配方、双托盘、示教等）
**不用任何的库**: 自写排样算法，不用 LPallPatt 等第三方库

## 必备学习 (开工前通读)

| 参考 | 用途 | 位置 |
|---|---|---|
| v9 `WebEditor/`（TypeScript + Vite 拖拽编辑器）| 手动侧移植样板 | v9 `UserFiles/WebEditor/` |
| v9 `1302_PatternEditor` 屏 + `DB_WebPalletEditor` | HMI 内嵌 + 数据交换样板 | v9 HMI screens + PLC 程序块 |
| v9 `Pattern_Module.hmi.js` | pattern 可视化脚本样板 | v9 `HMI_1/Scripts/` |
| `FB_AutoCtrl_Palletizing`（Phase 2 码垛 FB）| §5 接入码垛的对接点 | `PLC_1/.../500_AutoCtrl/` |

## 开发现状 (起点 — 不要重做已完成项)

| 项 | 状态 | 接手模块 |
|---|---|---|
| Phase 1 / Phase 2 全部成果 | ✅ 已验证 | 保留不动 |
| v9 WebEditor（手动拖拽编辑器）| 现成、可移植 | §2 移植 |
| 自动排样算法 / 逐层编辑 / 垛型存取 | ⬜ 未开始 | §3 §4 |

## 开工前输入 (操作员杨子楠提供)

agent 写代码前需操作员定 **D1 排样模式**、**D2 保存机制**（见《人工版》§1）。决策未到位前 §2 起的代码不开工。

## 1. 开工前设计决策

本模块是操作员决策（D1 排样模式、D2 保存机制）。**agent 侧无代码任务** —— 等操作员定完 D1 / D2 后，§2 起开工。scara-PM 跟踪决策状态。

## 2. 手动 Web 拖拽编辑器　（scara-HMI + scara-PLC agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 2.1 | Web 编辑器移植 | scara-HMI：把 v9 WebEditor 移植到 SCARA | 复制 WebEditor 工程 → 改 PLC 标签路径 / 项目参数 → Vite 重新打包 | 🔴 难 | 3d |
| 2.2 | HMI 屏内嵌 | scara-HMI：新建 PatternEditor 屏，HmiWebControl 内嵌 | 参照 v9 `1302_PatternEditor` | 🟡 中 | 1d |
| 2.3 | 数据交换块 | scara-PLC：建 `DB_WebPalletEditor`（header / boxes / 命令握手 / 状态）| 参照 v9 同名块；编译下载 | 🟡 中 | 1d |
| 2.4 | §2 handoff | scara-PM 写 handoff | 状态线 + 验收点 + 给操作员的部署 runbook | 🟢 简单 | 2h |

## 3. 自动垛型生成算法　（scara-PLC + scara-HMI agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 3.1 | 排样算法 | scara-PLC：自写轻量排样算法 | SCL 实现 D1 定的排样模式，输出每层 box 坐标 | 🔴 难 | 2.5d |
| 3.2 | 参数输入画面 | scara-HMI：箱长宽高 / 垛尺寸 / 间距 输入画面 | C# Openness builder 新增画面，绑 GDB | 🟢 简单 | 4h |
| 3.3 | 生成结果回填 | scara-PLC：算法结果写入交换块 | 结果写 DB_WebPalletEditor，编辑器 / HMI 可显示 | 🟡 中 | 4h |
| 3.4 | §3 handoff | scara-PM 写 handoff | 状态线 + 验收 + 部署 runbook | 🟢 简单 | 2h |

## 4. 逐层编辑 + 垛型存取　（scara-HMI + scara-PLC agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 4.1 | 逐层编辑画面 | scara-HMI：每层 pattern 单独查看 / 修改画面 | C# Openness builder | 🟡 中 | 1d |
| 4.2 | 垛型存取逻辑 | scara-PLC：按 D2 实现垛型存盘 / 加载 | PSC 或 LJDM 存盘 + 读盘回填交换块 | 🟡 中 | 1.5d |
| 4.3 | §4 handoff | scara-PM 写 handoff | 状态线 + 验收 + 部署 runbook | 🟢 简单 | 2h |

## 5. 端到端验收 + 收尾　（scara-PLC / scara-HMI / scara-PM agent）

| # | 内容 | 描述 | 方法 | 难度 | 工时 |
|---|---|---|---|---|---|
| 5.1 | 两路贯通 | scara-PLC/HMI：手动 + 自动两路都跑通 | 跑冒烟，验两路生成 → 编辑 → 存取 | 🟡 中 | 4h |
| 5.2 | 接入码垛 | scara-PLC：编辑好的垛型驱动 Phase 2 码垛 FB | 垛型数据接 Phase 2 的 `FB_AutoCtrl_Palletizing` V5.0 + `FB_PatternAutoGen` V3.0（替代后者的 auto-grid 路径，让编辑器 pattern 直接喂 `GDB_PalletizingPath.aCmd[]`）；参考 `PLC_HANDOFF_2026-05-23_ModuleE_DualPallet.md` §3 集成点 | 🔴 难 | 1d |
| 5.3 | 验证 handoff + 收尾 | scara-PM 汇总 V1–V8 + 更新 SCOREBOARD / LEDGER | bundle handoff + 跟踪表 | 🟡 中 | 4h |

## 阶段验收标准

| # | 验收点 | 通过条件 |
|---|---|---|
| V1 | 手动拖拽编辑 | Web 上拖拽摆箱，每层 pattern 可编辑 |
| V2 | 手动存盘联通 | 拖拽结果写入交换块，PLC 正确收到 boxes[] |
| V3 | 自动垛型生成 | HMI 输入箱 / 垛参数 → 算法生成合理垛型 |
| V4 | 逐层编辑 | 每一层 pattern 可单独查看 / 修改 |
| V5 | 垛型存取 | 编辑后的垛型存入 HMI 介质（PSC / LJDM），可重新加载 |
| V6 | 两路贯通 | 手动 + 自动两种方式都能生成 → 编辑 → 存取 |
| V7 | 接入码垛 | 编辑好的垛型驱动实际码垛，按 pattern 码放 |
| V8 | 代码量受控 | 排样算法 + 交换逻辑 SCL 简洁不臃肿，不用第三方库 |

## 任务规模与排期

| 模块 | 负责 agent | 规模估 | 前置依赖 |
|---|---|---|---|
| §1 开工前设计决策 | （操作员，agent 不参与）| — | — |
| §2 手动 Web 拖拽编辑器 | scara-HMI + scara-PLC | ~5.5 人天 | §1 操作员决策 |
| §3 自动垛型生成算法 | scara-PLC + scara-HMI | ~4 人天 | §1 |
| §4 逐层编辑 + 垛型存取 | scara-HMI + scara-PLC | ~3 人天 | §2 §3 |
| §5 端到端验收 + 收尾 | scara-PLC/HMI/PM | ~2 人天 | 全部 |
| **合计** | | **~14.5 人天** | |

**说明**：scara-PM 全程并行（每模块 1 份 handoff + SCOREBOARD/LEDGER 跟踪，不单列）。agent 代码产出快；真实日历周期由操作员的部署 / 验收节奏决定 —— 见《人工版》。**依赖**：§1 决策 → §2 §3（可并行）→ §4 → §5 收尾。

## 阶段总结

main target 是给 Phase 2 的码垛工作站补上 **垛型可编辑** 能力。本版是 agent 侧执行计划：scara-HMI agent 移植 Web 编辑器 + 写 HMI 各画面，scara-PLC agent 写排样算法 + DB 交换 + 接入码垛，scara-PM agent 每模块出 handoff + 维护 SCOREBOARD/LEDGER。

代码就绪后移交操作员杨子楠部署、验收（见《人工版》）。两份计划独立对等、覆盖同一 Phase 3。手动侧移植 v9 现成的 WebEditor；自动侧自写轻量排样算法（不用 LPallPatt —— 延续「不用第三方库」铁律）。Phase 1 + Phase 2 成果保留不动。
