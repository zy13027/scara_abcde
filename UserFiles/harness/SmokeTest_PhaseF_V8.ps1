<#
.SYNOPSIS
    Phase F smoke test — V8 blending verification via PLCSIM-Adv API.

.DESCRIPTION
    Identical to Phase D bring-up sequence, but additionally samples the SCARA
    TCP velocity throughout the 45-second cycle window. With BufferMode=5
    (BM_BLENDING_HIGH) + progress>50% step advance, the kinematic group should
    NEVER reach Standstill between ABCDE points — the next motion queues into
    the MC_MoveLinAbs buffer before the current motion completes, and SCARA
    blends through the corner.

    Pass criterion: <5% of velocity samples show standstill during cycle.
    Also verifies statProgress oscillates between 0 (after step change) and
    >0.5 (just before step advance).

.NOTES
    Requires FB_AutoCtrl_ABCDE.scl rev 3.0 (with BufferMode=5 + statTotalDistance
    + statProgress + progress-based advance). See V8 edits 2026-05-17.
#>

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force

$script:Results = New-Object System.Collections.ArrayList
$script:Transitions = New-Object System.Collections.ArrayList

function Assert-Gate {
    param([string]$Gate, [bool]$Passed, [string]$Detail)
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }
    [void]$script:Results.Add([PSCustomObject]@{ Gate=$Gate; Status=$status; Detail=$Detail })
    $color = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host "  [$status] $Gate — $Detail" -ForegroundColor $color
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Phase F Smoke Test — V8 blending (BufferMode=5 + progress advance)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# ====================================================================
# Connect to PLCSIM-Adv
# ====================================================================
Initialize-Plcsim
$mgrType = [Siemens.Simatic.Simulation.Runtime.SimulationRuntimeManager]
$registered = @($mgrType::RegisteredInstanceInfo)
if ($registered.Count -eq 0) { throw "No PLCSIM-Adv instances registered." }

# Auto-pick first running (or first registered)
$targetName = $null
foreach ($info in $registered) {
    try {
        $tmp = $mgrType::CreateInterface($info.Name)
        if ($tmp.OperatingState -eq 'Run') { $targetName = $info.Name; break }
    } catch { }
}
if (-not $targetName) { $targetName = $registered[0].Name }
Write-Host "Using instance: $targetName" -ForegroundColor Yellow

Connect-PlcsimInstance -Name $targetName | Out-Null
Update-TagList
$inst = Get-PlcsimInstance
if ($inst.OperatingState -ne 'Run') { Start-PlcsimInstance | Out-Null; Wait-ForCpuRun -TimeoutSeconds 30 }

# ====================================================================
# Safety reset
# ====================================================================
Write-Host ""
Write-Host "--- Safety reset ---" -ForegroundColor Cyan
Pulse-Tag 'GDB_MachineCmd.bo_Stop' -HoldMs 300
Write-Tag 'GDB_MachineCmd.bo_Start' $false
Write-Tag 'GDB_MachineCmd.bo_InitPath' $false
Start-Sleep -Milliseconds 500

# ====================================================================
# Bring-up
# ====================================================================
Write-Host ""
Write-Host "--- Bring-up: reset + enable + home + init + mode + start ---" -ForegroundColor Cyan
Pulse-Tag 'GDB_Control.resetAxes' -HoldMs 300
Start-Sleep -Milliseconds 500
Write-Tag 'GDB_Control.enableAxes' $true
Wait-ForTag 'GDB_Control.axesEnabled' $true -TimeoutSeconds 10 | Out-Null
Write-Host "  axesEnabled=TRUE"
Write-Tag 'GDB_Control.homeAxes' $true
Wait-ForTag 'GDB_Control.axesHomed' $true -TimeoutSeconds 10 | Out-Null
Write-Tag 'GDB_Control.homeAxes' $false
Write-Host "  axesHomed=TRUE"
Pulse-Tag 'GDB_MachineCmd.bo_InitPath' -HoldMs 300
Wait-ForTag 'GDB_MachineCmd.bo_PathInitialed' $true -TimeoutSeconds 5 | Out-Null
Write-Host "  bo_PathInitialed=TRUE"
Write-Tag 'GDB_MachineCmd.bo_Mode' $true
Pulse-Tag 'GDB_MachineCmd.bo_Start' -HoldMs 300
Start-Sleep -Milliseconds 500

# Confirm cycle running
$step = Read-Tag 'GDB_MachineCmd.i16_AutoStep'
Assert-Gate 'F.CycleStarted' ($step -gt 0) "i16_AutoStep=$step (cycle running)"

# ====================================================================
# V8: sample velocity + statProgress for 45s while cycle runs
# ====================================================================
Write-Host ""
Write-Host "--- V8: 45-second velocity sampling (BM_BLENDING_HIGH) ---" -ForegroundColor Cyan
Write-Host "  Polling ScaraArm3D.AxesData.A[1..3].Velocity + statProgress every 100ms..."

$velSamples = New-Object System.Collections.ArrayList
$prevStep = -1
$cycleCount = 0
$endTime = (Get-Date).AddSeconds(45)

while ((Get-Date) -lt $endTime) {
    $sample = @{}
    try {
        $v1 = [double](Read-Tag 'ScaraArm3D.AxesData.A[1].Velocity')
        $v2 = [double](Read-Tag 'ScaraArm3D.AxesData.A[2].Velocity')
        $v3 = [double](Read-Tag 'ScaraArm3D.AxesData.A[3].Velocity')
        $vMag = [Math]::Sqrt($v1*$v1 + $v2*$v2 + $v3*$v3)
        $step = [int](Read-Tag 'GDB_MachineCmd.i16_AutoStep')
        $progress = [double](Read-Tag 'instFB_AutoCtrl_ABCDE.statProgress')
        $totalDist = [double](Read-Tag 'instFB_AutoCtrl_ABCDE.statTotalDistance')
        $sample = @{
            Time = (Get-Date).ToString('HH:mm:ss.fff')
            Step = $step
            VMag = $vMag
            Progress = $progress
            TotalDist = $totalDist
        }
        [void]$velSamples.Add($sample)

        if ($step -ne $prevStep) {
            [void]$script:Transitions.Add([PSCustomObject]@{
                Time = $sample.Time; From = $prevStep; To = $step
                Progress = $progress; TotalDist = $totalDist
            })
            if ($prevStep -eq 50 -and $step -eq 10) { $cycleCount++ }
            Write-Host ("  {0}  step {1,3} -> {2,3}  progress@advance={3:F2}  totalDist={4,8:F2}" -f `
                       $sample.Time, $prevStep, $step, $progress, $totalDist)
            $prevStep = $step
        }
    } catch {
        # Tag read failure (e.g. statProgress not present on old SCL) — log + continue
        Write-Warning "Sample failed: $($_.Exception.Message)"
    }
    Start-Sleep -Milliseconds 100
}

# ====================================================================
# Analyse V8 results
# ====================================================================
Write-Host ""
Write-Host "--- V8 analysis ---" -ForegroundColor Cyan

$totalSamples = $velSamples.Count
$standstillSamples = @($velSamples | Where-Object { $_.VMag -lt 0.5 }).Count
$standstillRatio = if ($totalSamples -gt 0) { $standstillSamples / $totalSamples } else { 1.0 }
$movingRatio = 1.0 - $standstillRatio

Write-Host "  Total samples: $totalSamples"
Write-Host "  Standstill samples (|v| < 0.5 mm/s): $standstillSamples ($([Math]::Round($standstillRatio*100,1))%)"
Write-Host "  Moving samples (|v| >= 0.5 mm/s):    $($totalSamples - $standstillSamples) ($([Math]::Round($movingRatio*100,1))%)"

# V8 gate: <5% of samples should show standstill (blending should keep motion continuous)
Assert-Gate 'V8.Blending' ($standstillRatio -lt 0.05) `
    "Standstill ratio $([Math]::Round($standstillRatio*100,1))% (target <5% — motion continuous via BLENDING_HIGH)"

# V8 cycle count: blending should be FASTER than basic, so >3 cycles in 45s expected
Assert-Gate 'V8.CycleCount' ($cycleCount -ge 3) "$cycleCount cycle wraps in 45s (Phase D had 3-4; blending should be similar or faster)"

# V8 step-change progress: at each step advance, statProgress should be >0.5 (not 1.0)
$progressAtAdvance = @($script:Transitions | Where-Object { $_.To -in @(10,20,30,40,50) -and $null -ne $_.Progress } | Select-Object -ExpandProperty Progress)
if ($progressAtAdvance.Count -gt 0) {
    $minProg = ($progressAtAdvance | Measure-Object -Minimum).Minimum
    $maxProg = ($progressAtAdvance | Measure-Object -Maximum).Maximum
    $avgProg = ($progressAtAdvance | Measure-Object -Average).Average
    Write-Host "  Progress @ step-advance: min=$([Math]::Round($minProg,2)) max=$([Math]::Round($maxProg,2)) avg=$([Math]::Round($avgProg,2))"
    # If progress is ~0 at advance, the advance is happening at step entry (wrong)
    # If progress is ~0.5-0.7, the >0.5 advance is firing correctly
    # If progress is ~1.0, .Done is still gating (V8 not in effect)
    Assert-Gate 'V8.ProgressAdvance' ($avgProg -ge 0.4 -and $avgProg -le 0.8) `
        "Avg progress @ advance = $([Math]::Round($avgProg,2)) (target 0.4-0.8: motion advanced mid-flight, not at .Done)"
} else {
    Assert-Gate 'V8.ProgressAdvance' $false "No progress samples captured at step advance"
}

# ====================================================================
# Stop cycle
# ====================================================================
Write-Host ""
Write-Host "--- Stopping cycle ---" -ForegroundColor Cyan
Pulse-Tag 'GDB_MachineCmd.bo_Stop' -HoldMs 300
Start-Sleep -Milliseconds 500

# ====================================================================
# Summary
# ====================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                    PHASE F V8 SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
foreach ($r in $script:Results) {
    $color = if ($r.Status -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1,-22} {2}" -f $r.Status, $r.Gate, $r.Detail) -ForegroundColor $color
}

$passCount = @($script:Results | Where-Object Status -eq 'PASS').Count
$totalCount = $script:Results.Count
$result = if ($passCount -eq $totalCount) { "ALL V8 GATES PASS" } else { "$($totalCount - $passCount) V8 GATE(S) FAILED" }
$color = if ($passCount -eq $totalCount) { 'Green' } else { 'Red' }
Write-Host ""
Write-Host "Result: $passCount / $totalCount — $result" -ForegroundColor $color

# Save log
$logDir = Join-Path $PSScriptRoot 'results'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $logDir "phaseF_V8_$timestamp.log"

$log = @()
$log += "Phase F V8 Smoke Test — SCARA ABCDE blending"
$log += "Timestamp: $timestamp"
$log += "PLCSIM-Adv instance: $targetName"
$log += "Result: $passCount / $totalCount — $result"
$log += ""
$log += "Gate Results:"
foreach ($r in $script:Results) { $log += "  [$($r.Status)] $($r.Gate) -- $($r.Detail)" }
$log += ""
$log += "Velocity samples: $totalSamples total, $standstillSamples standstill ($([Math]::Round($standstillRatio*100,1))%)"
$log += "Cycle wraps in 45s: $cycleCount"
$log += ""
$log += "Step transitions ($($script:Transitions.Count)):"
foreach ($t in $script:Transitions) {
    $log += "  $($t.Time)  step $($t.From) -> $($t.To)  progress=$($t.Progress) totalDist=$($t.TotalDist)"
}
$log | Out-File -FilePath $logFile -Encoding UTF8

Write-Host ""
Write-Host "Full log: $logFile" -ForegroundColor DarkGray

if ($passCount -ne $totalCount) { exit 1 } else { exit 0 }
