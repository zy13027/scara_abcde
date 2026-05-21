param([string]$TargetIp='192.168.0.5')
# Release the SCARA axes from the PLC user program so the TIA TO control
# panel can take master control. FB_AxisCtrl powers the 4 axes via MC_Power
# every scan; while enableAxes=TRUE the kinematic group is "controlled by
# the user program" and the panel's master-control request fails. Setting
# enableAxes=FALSE makes FB_AxisCtrl drop MC_Power.Enable -> axes released.

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force -WarningAction SilentlyContinue
. "$PSScriptRoot\Plcsim_Robust.ps1"
Initialize-Plcsim
$null = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

Write-Host "`nReleasing SCARA axes from the PLC program (enableAxes := FALSE)..." -ForegroundColor Yellow
Safe-Write 'GDB_Control.homeAxes'   $false
Safe-Write 'GDB_Control.resetAxes'  $false
Safe-Write 'GDB_Control.enableAxes' $false
Start-Sleep -Milliseconds 2000

Write-Host "`n--- Axis state ---" -ForegroundColor Cyan
Write-Host ("  GDB_Control.enableAxes  = {0}" -f (Safe-Read 'GDB_Control.enableAxes'))
Write-Host ("  GDB_Control.axesEnabled = {0}  (False = released, free for the control panel)" -f (Safe-Read 'GDB_Control.axesEnabled'))
Write-Host ("  GDB_Control.axesReady   = {0}" -f (Safe-Read 'GDB_Control.axesReady'))
Write-Host ("  GDB_ManualCmd.bo_Mode   = {0}  (manual mode still set)" -f (Safe-Read 'GDB_ManualCmd.bo_Mode'))
Write-Host ("  GDB_MCDData.PalletizingSensor = {0}  (box still at pick)" -f (Safe-Read 'GDB_MCDData.PalletizingSensor'))

$ae = Safe-Read 'GDB_Control.axesEnabled'
Write-Host ""
if ($ae -eq $false) {
    Write-Host "Axes released. 'Activate master control' in the TO control panel should now succeed." -ForegroundColor Green
} else {
    Write-Host "Axes still report enabled -- give it a moment, then retry the panel." -ForegroundColor Yellow
}
