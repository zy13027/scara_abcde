[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5',
    [int]$EnableTimeoutS = 10,
    [int]$HomeTimeoutS   = 10
)

<#
.SYNOPSIS
    Idempotent pre-arm of the SCARA axes so the HMI can drive a cycle.

.DESCRIPTION
    The HMI's `02_Auto_Ubp` only exposes Start/Stop/Mode/InitPath buttons —
    Enable/Home/Reset live on the STAGED `02_Manual_Kin_Ubp` and aren't yet
    bound. This script pre-arms the axes via direct PLCSIM tag writes, so a
    real-operator flow (axes-already-on → click Start) can be exercised from
    the Auto screen.

    Steps:
      1. Clear all 3 mode bits (ABCDE / Pallet / Manual) for clean slate
      2. Pulse GDB_Control.resetAxes (clears latched MC errors)
      3. enableAxes=TRUE → wait for axesEnabled=TRUE  (EnableTimeoutS)
      4. homeAxes=TRUE → wait for axesHomed=TRUE  (HomeTimeoutS)
      5. homeAxes=FALSE (don't latch the home command)
      6. Final state proof: axesReady=TRUE
    Exits 0 on success, 1 with diagnostic on any timeout/failure.

.PARAMETER TargetIp
    PLCSIM-Adv instance IP. Default 192.168.0.5 (DemoScara_ABCD).

.PARAMETER EnableTimeoutS
    Seconds to wait for axesEnabled=TRUE after writing enableAxes. Default 10.

.PARAMETER HomeTimeoutS
    Seconds to wait for axesHomed=TRUE after writing homeAxes. Default 10.
#>

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force
. "$PSScriptRoot\Plcsim_Robust.ps1"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Prearm SCARA Axes for HMI-driven cycle" -ForegroundColor Cyan
Write-Host "  Target IP: $TargetIp" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$targetName = Connect-PlcsimRobust -TargetIp $TargetIp

function Wait-Tag {
    param([string]$Tag, [object]$Expected, [int]$TimeoutS)
    $deadline = (Get-Date).AddSeconds($TimeoutS)
    while ((Get-Date) -lt $deadline) {
        try {
            $v = Safe-Read $Tag
            if ($v -eq $Expected) { return $true }
        } catch { }
        Start-Sleep -Milliseconds 300
    }
    return $false
}

# Step 1: clear all mode bits
Write-Host ""
Write-Host "[1/6] Clearing mode bits..." -ForegroundColor Yellow
Safe-Write 'GDB_MachineCmd.bo_Mode'     $false
Safe-Write 'GDB_PalletizingCmd.bo_Mode' $false
Safe-Write 'GDB_ManualCmd.bo_Mode'      $false
# Also clear any latched start/stop pulses that could fire on next mode bit
Safe-Write 'GDB_MachineCmd.bo_Start'    $false
Safe-Write 'GDB_MachineCmd.bo_Stop'     $false
Safe-Write 'GDB_MachineCmd.bo_InitPath' $false
Safe-Write 'GDB_PalletizingCmd.bo_Start' $false
Safe-Write 'GDB_PalletizingCmd.bo_Stop'  $false
Safe-Write 'GDB_PalletizingCmd.bo_InitPallet' $false
Start-Sleep -Milliseconds 400

# Step 2: pulse reset
Write-Host "[2/6] Pulsing GDB_Control.resetAxes..." -ForegroundColor Yellow
Safe-Write 'GDB_Control.enableAxes' $false
Start-Sleep -Milliseconds 300
Safe-Pulse 'GDB_Control.resetAxes'
Start-Sleep -Milliseconds 800

# Step 3: enable axes
Write-Host "[3/6] enableAxes=TRUE, waiting for axesEnabled (${EnableTimeoutS}s)..." -ForegroundColor Yellow
Safe-Write 'GDB_Control.enableAxes' $true
if (-not (Wait-Tag 'GDB_Control.axesEnabled' $true $EnableTimeoutS)) {
    Write-Host "  FAIL: axesEnabled never went TRUE" -ForegroundColor Red
    Write-Host "  Diagnostic:" -ForegroundColor Red
    foreach ($n in 1..4) {
        $s = try { Safe-Read "instFB_AxisCtrl.instPower_J$n.Status" } catch { '<read-failed>' }
        $e = try { Safe-Read "instFB_AxisCtrl.instPower_J$n.Error" } catch { '<read-failed>' }
        $b = try { Safe-Read "instFB_AxisCtrl.instPower_J$n.Busy" } catch { '<read-failed>' }
        Write-Host ("    J${n} Power: Status=$s  Busy=$b  Error=$e") -ForegroundColor Red
    }
    exit 1
}
Write-Host "  axesEnabled=TRUE" -ForegroundColor Green

# Step 4: home axes
Write-Host "[4/6] homeAxes=TRUE, waiting for axesHomed (${HomeTimeoutS}s)..." -ForegroundColor Yellow
Safe-Write 'GDB_Control.homeAxes' $true
if (-not (Wait-Tag 'GDB_Control.axesHomed' $true $HomeTimeoutS)) {
    Write-Host "  FAIL: axesHomed never went TRUE" -ForegroundColor Red
    Safe-Write 'GDB_Control.homeAxes' $false
    exit 1
}
Write-Host "  axesHomed=TRUE" -ForegroundColor Green

# Step 5: release home cmd
Write-Host "[5/6] Releasing homeAxes (clear command)..." -ForegroundColor Yellow
Safe-Write 'GDB_Control.homeAxes' $false
Start-Sleep -Milliseconds 500

# Step 6: verify ready
Write-Host "[6/6] Verifying axesReady..." -ForegroundColor Yellow
$ready = try { Safe-Read 'GDB_Control.axesReady' } catch { $false }
if ($ready) {
    Write-Host "  axesReady=TRUE" -ForegroundColor Green
} else {
    Write-Host "  FAIL: axesReady is FALSE (axesEnabled AND axesHomed AND NOT axesError check failed)" -ForegroundColor Red
    Write-Host ("    axesEnabled = {0}" -f (Safe-Read 'GDB_Control.axesEnabled'))
    Write-Host ("    axesHomed   = {0}" -f (Safe-Read 'GDB_Control.axesHomed'))
    Write-Host ("    axesError   = {0}" -f (Safe-Read 'GDB_Control.axesError'))
    exit 1
}

# Report joint actuals (sanity)
Write-Host ""
Write-Host "Joint actuals at home:" -ForegroundColor Cyan
foreach ($n in 1..4) {
    $p = try { Safe-Read "GDB_HMI_Status.j${n}_actualPos" } catch { '<read-failed>' }
    Write-Host ("  J${n}: {0}" -f $p)
}

Write-Host ""
Write-Host "Prearm complete. HMI can now drive the ABCDE cycle." -ForegroundColor Green
exit 0
