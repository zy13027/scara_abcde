# 900_TIALib — VCI export note

## Path length

Deep LKinCtrl folder names under this tree can exceed **Windows MAX_PATH (~260)** when combined with:

`E:\TIA_Project_Directory_V20\hmiDemoSCARA_ABCDE\UserFiles\VCIExportedContents\PLC_1\Program blocks\900_TIALib\...`

Example file that may fail full VCI export:

- `LKinCtrl_SubBlocks/LKinCtrl_ContOffsetBlocks/LKinCtrl_ContOffset_SubBlocks/LKinCtrl_CalcCircPathChoiceByIntermediatePointAndEndPoint.scl`

## Recommendation

- **Routine agent work:** Edit application blocks in `100_OB`, `500_AutoCtrl`, `600_*`, `700_`, `instances/` — sync via TIA **Generate blocks from source** ([VCI_EXPORT_RUNBOOK.md](../../VCI_EXPORT_RUNBOOK.md)).
- **Full VCI export:** Exclude `900_TIALib` from export scope, or shorten the project base path (e.g. `E:\TIA\hmiDemoSCARA\`).
- **In TIA:** LKinCtrl library blocks remain in the project; they do not all need to be mirrored on disk for agent iteration.

## Disk copies here

Files present under `LKinCtrl_Blocks/` are from an earlier successful export. They are **reference copies** of Siemens L Kinematics library blocks, not primary agent edit targets.
