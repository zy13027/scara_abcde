param([string]$TargetIp='192.168.0.5')
# Put the SCARA system into MANUAL mode: GDB_ManualCmd.bo_Mode = TRUE,
# with palletizing + ABCDE modes OFF (3-way mode mutex). Manual mode
# activates FB_ManualCtrl and -- because both FB_AutoCtrl_Palletizing and
# FB_ConveyorCtrl gate their start on NOT GDB_ManualCmd.bo_Mode -- it
# locks out the auto cycle so the staged box and the arm are undisturbed.

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force -WarningAction SilentlyContinue
. "$PSScriptRoot\Plcsim_Robust.ps1"
Initialize-Plcsim
$null = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

Write-Host "`nSetting SCARA -> MANUAL mode (palletizing + ABCDE OFF)..." -ForegroundColor Yellow
Safe-Write 'GDB_MachineCmd.bo_Mode'     $false
Safe-Write 'GDB_PalletizingCmd.bo_Mode' $false
Safe-Write 'GDB_ManualCmd.bo_Mode'      $true
Start-Sleep -Milliseconds 600

Write-Host "`n--- Mode state ---" -ForegroundColor Cyan
Write-Host ("  GDB_ManualCmd.bo_Mode        = {0}" -f (Safe-Read 'GDB_ManualCmd.bo_Mode'))
Write-Host ("  GDB_PalletizingCmd.bo_Mode   = {0}" -f (Safe-Read 'GDB_PalletizingCmd.bo_Mode'))
Write-Host ("  GDB_MachineCmd.bo_Mode       = {0}" -f (Safe-Read 'GDB_MachineCmd.bo_Mode'))
Write-Host "--- Guard checks ---" -ForegroundColor Cyan
Write-Host ("  instFB_AutoCtrl_Palletizing.statPhase = {0}  (0 = palletizer idle)" -f (Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase'))
Write-Host ("  instFB_ConveyorCtrl.statRunning       = {0}  (False = conveyor idle)" -f (Safe-Read 'instFB_ConveyorCtrl.statRunning'))
Write-Host ("  GDB_MCDData.PalletizingSensor         = {0}  (True = box still staged at pick)" -f (Safe-Read 'GDB_MCDData.PalletizingSensor'))
Write-Host ("  GDB_PalletizingCmd.bo_Alarm           = {0}" -f (Safe-Read 'GDB_PalletizingCmd.bo_Alarm'))

$man = Safe-Read 'GDB_ManualCmd.bo_Mode'
Write-Host ""
if ($man -eq $true) {
    Write-Host "SCARA is in MANUAL mode. Auto palletizer + conveyor are locked out." -ForegroundColor Green
} else {
    Write-Host "FAILED to set manual mode." -ForegroundColor Red
}
