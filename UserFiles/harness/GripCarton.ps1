param([string]$TargetIp='192.168.0.5')
# Drive the suction-cup GRIP signal level-TRUE to test the grab:
# GDB_Control.bo_gripperGrip -> co-sim sScaraGrip -> MCD Suction_Cup_Gripper,
# which attaches whatever box is in contact with the cup face.

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force -WarningAction SilentlyContinue
. "$PSScriptRoot\Plcsim_Robust.ps1"
Initialize-Plcsim
$null = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

Write-Host "`nSetting gripper GRIP signal (level TRUE)..." -ForegroundColor Yellow
Safe-Write 'GDB_Control.bo_gripperRelease' $false
Safe-Write 'GDB_Control.bo_gripperGrip'    $true
Start-Sleep -Milliseconds 1200

$grip = Safe-Read 'GDB_Control.bo_gripperGrip'
$rel  = Safe-Read 'GDB_Control.bo_gripperRelease'
Write-Host ""
Write-Host ("  GDB_Control.bo_gripperGrip    = {0}" -f $grip)
Write-Host ("  GDB_Control.bo_gripperRelease = {0}" -f $rel)
Write-Host ""
if ($grip -eq $true) {
    Write-Host "GRIP signal HELD TRUE -- Suction_Cup_Gripper activated via sScaraGrip." -ForegroundColor Green
} else {
    Write-Host "GRIP did NOT stick -- a running FB (e.g. FB_ManualCtrl) is overwriting bo_gripperGrip." -ForegroundColor Red
}
