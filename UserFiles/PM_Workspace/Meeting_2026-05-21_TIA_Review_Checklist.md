# TIA 编程评审 — 速查清单

**会议日期：** 2026-05-21  
**完整纪要：** [Meeting_2026-05-21_TIA_Programming_Review.md](Meeting_2026-05-21_TIA_Programming_Review.md)

## 与会人员

| 角色 | 姓名 |
|------|------|
| 开发者 | 杨子楠 |
| 评审 | 王硕 |
| HMI/仿真 | 吕佩瑶 |
| 提及 | 闫老板（闫磊）、郑老板（郑磊） |

---

## Home 与校准

| 术语 | 含义 |
|------|------|
| **当前 Home** | HMI tool tip 末端**实时位置**（校准偏移时对照） |
| **行业 Home** | PLC `GDB_Control` 中 `HomePos` / `HomeMode` → 归入 **Home Struct** |
| **JogFrame** | 三轴联动 + 单轴点动；**不用** `MC_Jog`（轴在 kinematics TO 内） |
| **Excel** | 记录自动 / 手动各用哪个 Home |

**注意：** 仿真中 HomeMode 易假象已回原；真机须走 **FB_Init** 与正确 HomeMode。

---

## GDB_Control

- `HomePos` / `HomeMode` 放在 **Home 结构体**下
- **分轴 Enable**（勿用单 Bool 一次全轴使能）
- **Struct 按功能分类**（Enable、Home、Reset 等）；同功能多轴用同一数组/结构
- 数据结构决定程序可读性

**反面教材：** 旧项目将 **Axis Control**（轴控 / **Pos Axis Ctrl**）中的点位、回原、运动等全部塞进单一 FB → 集成过多，难维护。

---

## 分层架构

| 文件夹 | 职责 |
|--------|------|
| **200** | HMI 通信 |
| **300** | IO / 报警（预留） |
| **500** | 工艺逻辑（自动步、码垛、手动逻辑）；**不得**直接调 `MC_*` |
| **600** | 轴控：`FB_AxisCtrl`、`GDB_Control`、运动/kinematics（OB 先跑轴层） |
| **700** | `FB_MovePath` / `GDB_MovePath`（`LKinCtrl_MovePath`，占位） |

- `GDB_Control` **主本在 600**；清理 500 重复副本
- **Region 4** 路径指令赋值 → **600**；路径算法 → **700**
- 闫老板（闫磊）要求：轴控与工艺逻辑解耦

---

## 初始化

- 单独 **FB_Init**（回原 / 回安全位，不塞进主自动 FB）
- 各轴**先后次序** + **独立回原速度**参数

---

## CASE 自动步（王硕模型）

| 步号 | 用途 |
|------|------|
| 0 | 空步 |
| 10 | 变量复位（启动 / 报错后） |
| 20 | 设备启动条件（风机、泵等） |
| 30–80 | 先赋值 / 计算，**再**发 CMD |
| 50 | MovePath / 运动命令 → **600**（**不是**回原） |
| 75 | 暂停（**未做**） |
| 100 | 等待运动完成（`\|actual − set\| < 0.01`；慎用 Done） |
| 200 | 急停跳转 |
| 230 | 周期结束 |
| 800–900 | 停机变量复位 |

**原则：** 主逻辑**头尾**都要准备与复位；先参数后 CMD。

---

## HMI

- 全局 **Header**：**实际位置 + 目标位置**（非 TCP），所有 UBP 页常驻

---

## 待办

- [ ] Excel：当前 Home / 行业 Home、自动 vs 手动映射
- [ ] `GDB_Control` + `FB_AxisCtrl` 迁至 **600** 并去重
- [ ] 新增 **FB_Init**（轴序、回原速度、HomeMode）
- [ ] ABCDE / `FB_AutoCtrl_5Pts` 标准 **CASE** 步表
- [ ] `MC_*` / MovePath（`LKinCtrl_MovePath`）从 500 迁至 **600**
- [ ] `GDB_Control` 结构体化 + 分轴 Enable
- [ ] 新建 **700** + `FB_MovePath` / `GDB_MovePath` 占位
- [ ] HMI 全局 Header（实际 + 目标）
- [ ] 自动序列增加**暂停**

## 待确认

- [ ] **郑老板（郑磊）：** L Kinematics Control 库是否可用
