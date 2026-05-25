[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5',
    [int]$TimeoutSeconds = 360,
    [int]$SampleMs = 500,
    [switch]$SkipPrearm,
    [switch]$RealMode  # if set, leaves bo_RequireSensorGate=TRUE (needs MCD belt + sensor live)
)

<#
.SYNOPSIS
    Phantom-mode smoke for FB_AutoCtrl_Palletizing V3.0.

.DESCRIPTION
    Phantom mode (default) sets bo_RequireSensorGate=FALSE so the WAIT_ARRIVAL
    phase auto-advances on each cycle. Useful for verifying state-machine motion
    end-to-end without needing NX MCD belt + PalletizingSensor live.

    Flow:
      1. Prearm (clears modes, enables + homes axes) unless -SkipPrearm
      2. Set GDB_PalletizingCmd.bo_Mode=TRUE
      3. Set GDB_PalletizingCmd.bo_RequireSensorGate=FALSE  (unless -RealMode)
      4. Pulse bo_Start TRUE/FALSE
      5. Observation loop: poll statPhase/statBoxIdx/statBoxesPlaced + joints + belt/gripper
      6. Terminates on: bo_PalletDone=TRUE, statBoxesPlaced>=16, OR timeout
      7. Cleanup: bo_Stop pulse, clear bo_Mode

    Phase enumeration (per V3.0 SCL):
      0 = IDLE / STOPPED
      1 = ABOVE_PICK
      2 = PICK_DESCEND
      3 = PICK_RAISE
      4 = APPROACH_PLACE
      5 = PLACE_DESCEND
      6 = PLACE_RETRACT
      7 = WAIT_ARRIVAL  (phantom-mode auto-bypass)
      8 = COMPLETE
#>

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force -WarningAction SilentlyContinue
. "$PSScriptRoot\Plcsim_Robust.ps1"

$PhaseName = @{
    0 = 'IDLE'; 5 = 'RUNNING'; 8 = 'COMPLETE'; 9 = 'FAULT'
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Palletize V3.0 Smoke   (mode: $(if($RealMode){'REAL'}else{'PHANTOM'}))" -ForegroundColor Cyan
Write-Host "  Target IP: $TargetIp" -ForegroundColor Gray
Write-Host "  Timeout:   ${TimeoutSeconds}s" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$null = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

# --- Step 1: Prearm ---
if (-not $SkipPrearm) {
    Write-Host "`n[1/6] Pre-arming axes..." -ForegroundColor Yellow
    & "$PSScriptRoot\Prearm_AbcdeAxes.ps1" -TargetIp $TargetIp
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Pre-arm failed; aborting smoke." -ForegroundColor Red
        exit 1
    }
    Update-TagList
}

# --- Step 2 + 3: Set palletizing mode + phantom-gate flag ---
Write-Host "`n[2/6] Setting palletizing mode + phantom gate..." -ForegroundColor Yellow
Safe-Write 'GDB_MachineCmd.bo_Mode'     $false  # belt + ABCDE off
Safe-Write 'GDB_ManualCmd.bo_Mode'      $false
Safe-Write 'GDB_PalletizingCmd.bo_Mode' $true
Safe-Write 'GDB_PalletizingCmd.bo_RequireSensorGate' ([bool]$RealMode)
Start-Sleep -Milliseconds 300

Write-Host ("  bo_Mode               = {0}" -f (Safe-Read 'GDB_PalletizingCmd.bo_Mode'))
Write-Host ("  bo_RequireSensorGate  = {0}" -f (Safe-Read 'GDB_PalletizingCmd.bo_RequireSensorGate'))
Write-Host ("  bo_PalletInitialed    = {0}" -f (Safe-Read 'GDB_PalletizingCmd.bo_PalletInitialed'))

# Ensure pallet inited (idempotent)
if ((Safe-Read 'GDB_PalletizingCmd.bo_PalletInitialed') -ne $true) {
    Write-Host "  Pallet not inited; pulsing bo_InitPallet..." -ForegroundColor Gray
    Safe-Pulse 'GDB_PalletizingCmd.bo_InitPallet' 400
    Start-Sleep -Milliseconds 400
}

# --- Step 4: Pulse bo_Start (rising edge) ---
Write-Host "`n[3/6] Pulsing bo_Start..." -ForegroundColor Yellow
Safe-Write 'GDB_PalletizingCmd.bo_Start' $false
Start-Sleep -Milliseconds 300
$tStart = Get-Date
Safe-Write 'GDB_PalletizingCmd.bo_Start' $true
Start-Sleep -Milliseconds 350
Safe-Write 'GDB_PalletizingCmd.bo_Start' $false

# --- Step 5: Observation loop ---
Write-Host "`n[4/6] Observing cycle (timeout ${TimeoutSeconds}s)..." -ForegroundColor Yellow
Write-Host ("  {0,-7} {1,-4} {2,-11} {3,-3} {4,-3} {5,-7} {6,-7} {7,-7} {8,-7} {9,-4} {10,-4}" -f 'time(s)','Box','Phase','Sub','Plc','Belt','Spawn','Pack','Pallet','Grip','Rel') -ForegroundColor Gray

$transitions = @()
$boxEvents   = @()
$prevPhase   = -1
$prevBoxes   = -1
$prevBoxIdx  = -1
$stuckSince  = Get-Date
$lastPrintT  = (Get-Date).AddSeconds(-10)
$deadline    = $tStart.AddSeconds($TimeoutSeconds)
$finalReason = 'timeout'

while ((Get-Date) -lt $deadline) {
    $phase    = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase')
    $boxIdx   = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statCmdPtr')
    $placed   = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statBoxesPlaced')
    $sub      = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statExecState')
    $belt     = [double](Safe-Read 'GDB_MCDData.BeltVelocity')
    $spawn    = [bool](Safe-Read 'GDB_MCDData.SpawnContainerCmd')
    # 2026-05-25: Post-LayeredRefactor (2026-05-21) — GDB_Control retired; gripper signals relocated to GDB_MCDData.
    $grip     = [bool](Safe-Read 'GDB_MCDData.bo_gripperGrip')
    $rel      = [bool](Safe-Read 'GDB_MCDData.bo_gripperRelease')
    $done     = [bool](Safe-Read 'GDB_PalletizingCmd.bo_PalletDone')
    $pack     = [bool](Safe-Read 'GDB_MCDData.PackingSensor')
    $pallet   = [bool](Safe-Read 'GDB_MCDData.PalletizingSensor')
    $now      = Get-Date
    $elapsed  = ($now - $tStart).TotalSeconds

    # Phase transition
    if ($phase -ne $prevPhase -or $boxIdx -ne $prevBoxIdx) {
        $transitions += [PSCustomObject]@{
            T = [Math]::Round($elapsed,1); Box=$boxIdx; Phase=$phase;
            Name = $PhaseName[$phase]; Sub = $sub
        }
        $prevPhase  = $phase
        $prevBoxIdx = $boxIdx
        $stuckSince = $now
    }

    # Box completion event
    if ($placed -ne $prevBoxes) {
        $boxEvents += [PSCustomObject]@{ T=[Math]::Round($elapsed,1); Placed=$placed }
        if ($placed -gt $prevBoxes -and $prevBoxes -ge 0) {
            Write-Host ("    [{0,6:F1}s] Box {1} placed  -> total {2}/16" -f $elapsed, $placed, $placed) -ForegroundColor Green
        }
        $prevBoxes = $placed
    }

    # Print one summary line per ~2s
    if (($now - $lastPrintT).TotalMilliseconds -ge 2000) {
        Write-Host ("  {0,7:F1} {1,-4} {2,-11} {3,-3} {4,-3} {5,7:F1} {6,-7} {7,-7} {8,-7} {9,-4} {10,-4}" -f `
            $elapsed, $boxIdx, $PhaseName[$phase], $sub, $placed, $belt, $spawn, $pack, $pallet, $grip, $rel) -ForegroundColor Gray
        $lastPrintT = $now
    }

    # Termination — done
    if ($done -or $placed -ge 16 -or $phase -eq 8) {
        $finalReason = 'pallet_done'
        Start-Sleep -Milliseconds 800   # let final state settle for printing
        break
    }

    # Termination — stuck >60s in same phase (real mode: WAIT_ARRIVAL holds
    # ~13s per box for belt transit, so 30s is too tight)
    if (($now - $stuckSince).TotalSeconds -gt 60) {
        $finalReason = "stuck_in_phase_${phase}_${($PhaseName[$phase])}"
        break
    }

    Start-Sleep -Milliseconds $SampleMs
}

# --- Step 6: Final state + cleanup ---
Write-Host "`n[5/6] Final state..." -ForegroundColor Yellow
$finalPhase = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase')
$finalBox   = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statCmdPtr')
$finalPlaced= [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statBoxesPlaced')
$finalDone  = [bool](Safe-Read 'GDB_PalletizingCmd.bo_PalletDone')
$finalBelt  = [double](Safe-Read 'GDB_MCDData.BeltVelocity')
$elapsedTot = ((Get-Date) - $tStart).TotalSeconds

Write-Host ("  Reason         : {0}" -f $finalReason) -ForegroundColor Gray
Write-Host ("  statPhase      : {0} ({1})" -f $finalPhase, $PhaseName[$finalPhase]) -ForegroundColor Gray
Write-Host ("  statBoxIdx     : {0}" -f $finalBox) -ForegroundColor Gray
Write-Host ("  statBoxesPlaced: {0}/16" -f $finalPlaced) -ForegroundColor Gray
Write-Host ("  bo_PalletDone  : {0}" -f $finalDone) -ForegroundColor Gray
Write-Host ("  BeltVelocity   : {0}" -f $finalBelt) -ForegroundColor Gray
Write-Host ("  Phase transitions observed: {0}" -f $transitions.Count) -ForegroundColor Gray
Write-Host ("  Total elapsed  : {0:F1}s" -f $elapsedTot) -ForegroundColor Gray

Write-Host "`n[6/6] Cleanup..." -ForegroundColor Yellow
Safe-Pulse 'GDB_PalletizingCmd.bo_Stop' 350
Start-Sleep -Milliseconds 300
Safe-Write 'GDB_PalletizingCmd.bo_Mode' $false
Safe-Write 'GDB_PalletizingCmd.bo_RequireSensorGate' $true  # restore default
Write-Host "  bo_Stop pulsed, bo_Mode cleared, bo_RequireSensorGate restored to TRUE" -ForegroundColor Gray

# --- Verdict ---
Write-Host "`n================================================================" -ForegroundColor Cyan
$pass = ($finalReason -eq 'pallet_done') -and ($finalPlaced -ge 16) -and $finalDone
if ($pass) {
    Write-Host ("PASS — 16 boxes palletized in {0:F1}s, bo_PalletDone=TRUE" -f $elapsedTot) -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host ("FAIL — reason={0}, placed={1}/16, done={2}" -f $finalReason, $finalPlaced, $finalDone) -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Cyan
    if ($transitions.Count -gt 0) {
        Write-Host "`nFirst 25 phase transitions:" -ForegroundColor Yellow
        $transitions | Select-Object -First 25 | Format-Table -AutoSize
        if ($transitions.Count -gt 25) {
            Write-Host "Last 10 transitions:" -ForegroundColor Yellow
            $transitions | Select-Object -Last 10 | Format-Table -AutoSize
        }
    }
    exit 1
}
