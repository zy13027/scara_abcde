param([string]$TargetIp='192.168.0.5')
# Post-run diagnostic: did the conveyor FB actually run? statSpawnCount is
# SET to 0 at conveyor start and incremented per spawn; it is NOT cleared by
# Stop -- so a value >=1 proves the conveyor FB started and commanded a spawn.

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force -WarningAction SilentlyContinue
. "$PSScriptRoot\Plcsim_Robust.ps1"
Initialize-Plcsim
$null = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

Write-Host "`n--- Conveyor FB state (post-run) ---" -ForegroundColor Yellow
Write-Host ("  instFB_ConveyorCtrl.statSpawnCount = {0}   (>=1 => conveyor FB started & spawned)" -f (Safe-Read 'instFB_ConveyorCtrl.statSpawnCount'))
Write-Host ("  instFB_ConveyorCtrl.statRunning    = {0}" -f (Safe-Read 'instFB_ConveyorCtrl.statRunning'))
Write-Host ("  instFB_ConveyorCtrl.statBeltRun    = {0}" -f (Safe-Read 'instFB_ConveyorCtrl.statBeltRun'))

Write-Host "`n--- GDB_MCDData (current / idle) ---" -ForegroundColor Yellow
Write-Host ("  BeltVelocity      = {0}" -f (Safe-Read 'GDB_MCDData.BeltVelocity'))
Write-Host ("  SpawnContainerCmd = {0}" -f (Safe-Read 'GDB_MCDData.SpawnContainerCmd'))
Write-Host ("  PackingSensor     = {0}" -f (Safe-Read 'GDB_MCDData.PackingSensor'))
Write-Host ("  PalletizingSensor = {0}" -f (Safe-Read 'GDB_MCDData.PalletizingSensor'))

Write-Host "`n--- Palletizer + command bits ---" -ForegroundColor Yellow
Write-Host ("  instFB_AutoCtrl_Palletizing.statPhase   = {0}" -f (Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase'))
Write-Host ("  GDB_PalletizingCmd.bo_Mode             = {0}" -f (Safe-Read 'GDB_PalletizingCmd.bo_Mode'))
Write-Host ("  GDB_PalletizingCmd.bo_RequireSensorGate= {0}" -f (Safe-Read 'GDB_PalletizingCmd.bo_RequireSensorGate'))
Write-Host ("  GDB_PalletizingCmd.lr_PickX            = {0}" -f (Safe-Read 'GDB_PalletizingCmd.lr_PickX'))
Write-Host ("  GDB_PalletizingCmd.lr_PickZ            = {0}" -f (Safe-Read 'GDB_PalletizingCmd.lr_PickZ'))
