# SCARA ABCDE — Palletizing Robot Demonstrator

A TIA Portal V20 project for a 4-axis **SCARA palletizing robot**: a repeatable five-waypoint "ABCDE" motion cycle plus conveyor-fed box palletizing, designed for full digital-twin co-simulation.

> TIA Portal project: `hmiDemoSCARA_ABCDE`

## Overview

The project controls a SCARA arm (joints J1–J4) that:

- runs a repeatable **five-point auto-cycle** through waypoints A → B → C → D → E, and
- performs **box palletizing** — picking conveyor-fed cartons with a suction-cup gripper and stacking them on a pallet.

It is built to run entirely in simulation: the PLC program on **PLCSIM Advanced**, the machine mechanics as a **Siemens NX Mechatronics Concept Designer (MCD)** digital twin, and the operator interface on a **WinCC Unified** panel — all co-simulated together.

## Control stack

| Role | Component |
|---|---|
| PLC | SIMATIC S7-1511T Technology CPU |
| Motion | TIA Technology Objects — four positioning axes + one SCARA kinematics group |
| HMI | WinCC Unified — MTP1000 Unified Basic Panel |
| PLC simulation | PLCSIM Advanced |
| Mechanical twin | Siemens NX + Mechatronics Concept Designer |
| Engineering tool | TIA Portal V20 |

## PLC program architecture

The PLC program uses a layered, numbered folder scheme that keeps axis control decoupled from process logic:

| Folder | Layer |
|---|---|
| `000_OB` | Organization blocks — startup, cyclic interrupt, main scan |
| `200_HMI_Comm` | HMI communication — status mirror, MCD data exchange |
| `300_Alarm_IO` | IO and alarm handling |
| `500_AutoCtrl` | Process logic — auto sequences (ABCDE / 5-point), palletizing, manual control |
| `600_AxisCtrl` | Axis and kinematics control |
| `700_Palletizing` | Palletizing path and move-sequence blocks |
| `900_TIALib` | Siemens library blocks |

Instance data blocks are collected under `instances/`. Supporting folders under `PLC_1/`: `PLC data types/` (UDTs), `PLC tags/` (tag tables), and `Technology objects/` (the SCARA axis and kinematics TOs).

## Project phases

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | ABCDE five-point auto-cycle · HMI target-position display · NX MCD auto-connect | Complete |
| **Phase 2** | MCD conveyor co-simulation · finer palletizing logic · recipe-set box dimensions · dual-pallet switching · teach / jog · parameterized function blocks | In progress |
| **Phase 3** | Pallet pattern editor — manual drag-and-drop layout, automatic layout generation, layer-by-layer editing, pattern save / load | Planned |

## Repository layout

This repository version-controls the `hmiDemoSCARA_ABCDE` TIA Portal project. TIA Portal's regenerable build and cache directories (`System/`, `IM/`, `Vci/`, `XRef/`, …) are excluded via `.gitignore` and are recreated when the project is opened.

```
hmiDemoSCARA_ABCDE/
├── hmiDemoSCARA_ABCDE.ap20     TIA Portal V20 project file
├── .gitignore
├── README.md
└── UserFiles/
    ├── VCIExportedContents/
    │   ├── PLC_1/              PLC program — layered 000–900 (see above)
    │   └── *.md                Project documentation — design plans,
    │                           status reports, engineering notes
    ├── PM_Workspace/           Planning, scheduling, and progress tracking
    └── harness/                Automated test and simulation scripts
```

## Test harness

`UserFiles/harness/` contains PowerShell and Python scripts that drive PLCSIM Advanced for automated smoke and regression testing — phase smoke tests, trace capture, and log analysis. Run logs are written to `harness/results/`.

## Getting started

1. Install **TIA Portal V20** (with WinCC Unified) and **PLCSIM Advanced**; for the mechanical co-simulation, **Siemens NX** with Mechatronics Concept Designer.
2. Open `hmiDemoSCARA_ABCDE.ap20` in TIA Portal V20.
3. Compile the project, then download the PLC to a PLCSIM Advanced instance.
4. For full co-simulation, connect the NX MCD digital twin's signals to the PLC.
5. Optionally, run the scripts in `UserFiles/harness/` for automated checks.
