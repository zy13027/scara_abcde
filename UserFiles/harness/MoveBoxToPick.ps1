[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5',
    [int]$TimeoutSeconds = 150
)

# =====================================================================
# MoveBoxToPick.ps1 -- convey ONE box to the pick end of the belt and stop
# it there, WITHOUT moving the SCARA arm, so the operator can teach the
# pick pose via the TIA TO control panel.
#
# Trick: FB_AutoCtrl_Palletizing's start gate (REGION 2) requires
# i16_PalletStep = 0. Set i16_PalletStep := 1 before bo_Start and the
# palletizer never starts (statPhase stays 0, arm never commanded).
# FB_ConveyorCtrl has no such gate -> it spawns + runs the belt normally.
# The conveyor stops the belt itself when PalletizingSensor goes TRUE.
# =====================================================================

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force -WarningAction SilentlyContinue
. "$PSScriptRoot\Plcsim_Robust.ps1"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Move box to the pick end  (conveyor only -- arm stays put)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$null = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

Write-Host "`n[1/5] Mode bits (palletizing real mode, ABCDE/manual off)..." -ForegroundColor Yellow
Safe-Write 'GDB_MachineCmd.bo_Mode'                  $false
Safe-Write 'GDB_ManualCmd.bo_Mode'                   $false
Safe-Write 'GDB_PalletizingCmd.bo_Mode'             $true
Safe-Write 'GDB_PalletizingCmd.bo_RequireSensorGate' $true
Safe-Write 'GDB_PalletizingCmd.bo_Start'            $false
Start-Sleep -Milliseconds 300

Write-Host "[2/5] Build path (bo_InitPallet) -> bo_PalletInitialed..." -ForegroundColor Yellow
Safe-Pulse 'GDB_PalletizingCmd.bo_InitPallet' 400
Start-Sleep -Milliseconds 500

Write-Host "[3/5] Block the palletizer FB (i16_PalletStep := 1)..." -ForegroundColor Yellow
Safe-Write 'GDB_PalletizingCmd.i16_PalletStep' 1
Start-Sleep -Milliseconds 300

Write-Host "[4/5] Pulse bo_Start -- conveyor starts, palletizer blocked..." -ForegroundColor Yellow
$tStart = Get-Date
Safe-Write 'GDB_PalletizingCmd.bo_Start' $true
Start-Sleep -Milliseconds 350
Safe-Write 'GDB_PalletizingCmd.bo_Start' $false

Write-Host "[5/5] Conveying box to PalletizingSensor (pick end)..." -ForegroundColor Yellow
$deadline = $tStart.AddSeconds($TimeoutSeconds)
$arrived  = $false
$prevPack = $null
while ((Get-Date) -lt $deadline) {
    $pallet = [bool](Safe-Read 'GDB_MCDData.PalletizingSensor')
    $pack   = [bool](Safe-Read 'GDB_MCDData.PackingSensor')
    $phase  = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase')
    $el     = ((Get-Date)-$tStart).TotalSeconds

    if ($pack -ne $prevPack) {
        Write-Host ("  t={0,6:F1}  PackingSensor = {1}" -f $el,$pack) -ForegroundColor Gray
        $prevPack = $pack
    }
    if ($phase -eq 5) {
        Write-Host "  WARNING: palletizer started (phase=5) -- block failed; stopping." -ForegroundColor Red
        break
    }
    if ($pallet) {
        Write-Host ("  t={0,6:F1}  PalletizingSensor = TRUE -- box at the pick end" -f $el) -ForegroundColor Green
        $arrived = $true
        break
    }
    Start-Sleep -Milliseconds 200
}

Write-Host "`n[6] Stop conveyor (belt off; box stays at the pick)..." -ForegroundColor Yellow
Safe-Pulse 'GDB_PalletizingCmd.bo_Stop' 350
Start-Sleep -Milliseconds 500

$pallet = [bool](Safe-Read 'GDB_MCDData.PalletizingSensor')
$belt   = [double](Safe-Read 'GDB_MCDData.BeltVelocity')
$phase  = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase')
Write-Host ("`n  PalletizingSensor={0}   BeltVelocity={1}   palletizer statPhase={2}" -f $pallet,$belt,$phase)

Write-Host "`n================================================================" -ForegroundColor Cyan
if ($arrived -and $phase -ne 5) {
    Write-Host "BOX AT THE PICK END -- belt off, arm never moved." -ForegroundColor Green
    Write-Host "Ready: teach the pick pose via the TO control panel." -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "Box did NOT reach the pick end (timeout or palletizer ran)." -ForegroundColor Red
    Write-Host "Check NX is Playing and the belt co-sim is live." -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Cyan
    exit 1
}
