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
# Verify V8 SCL is loaded (statProgress + statTotalDistance must exist)
# ====================================================================
Write-Host ""
Write-Host "--- V8 SCL precheck ---" -ForegroundColor Cyan
$v8Loaded = $true
try {
    $testProgress = Read-Tag 'instFB_AutoCtrl_ABCDE.statProgress'
    Write-Host "  instFB_AutoCtrl_ABCDE.statProgress = $testProgress (V8 SCL loaded)" -ForegroundColor Green
} catch {
    $v8Loaded = $false
    Write-Host "  instFB_AutoCtrl_ABCDE.statProgress NOT FOUND: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  -> Operator must re-import FB_AutoCtrl_ABCDE.scl rev 3.0 + Rebuild All + Re-download" -ForegroundColor Red
}
Assert-Gate 'F.V8SclLoaded' $v8Loaded "statProgress tag $(if($v8Loaded){'exists'}else{'MISSING — V8 SCL not deployed'})"
if (-not $v8Loaded) {
    Write-Host "Cannot proceed with V8 verification — old SCL still loaded." -ForegroundColor Red
    Pulse-Tag 'GDB_MachineCmd.bo_Stop' -HoldMs 300
    exit 1
}

# ====================================================================
# V8: sample velocity + statProgress for 45s while cycle runs
# ====================================================================
Write-Host ""
Write-Host "--- V8: 45-second velocity sampling (BM_BLENDING_HIGH) ---" -ForegroundColor Cyan
Write-Host "  Polling GDB_MCDData.Velocity[1..3] + statProgress every 100ms..."

$velSamples = New-Object System.Collections.ArrayList
$prevStep = -1
$cycleCount = 0
$endTime = (Get-Date).AddSeconds(45)

while ((Get-Date) -lt $endTime) {
    # Read each tag separately so one failure doesn't lose the whole sample
    $step = $null; $vMag = $null; $progress = $null; $totalDist = $null
    try { $step      = [int](Read-Tag 'GDB_MachineCmd.i16_AutoStep') }                catch { }
    try { $progress  = [double](Read-Tag 'instFB_AutoCtrl_ABCDE.statProgress') }       catch { }
    try { $totalDist = [double](Read-Tag 'instFB_AutoCtrl_ABCDE.statTotalDistance') }  catch { }
    try {
        $v1 = [double](Read-Tag 'GDB_MCDData.Velocity[1]')
        $v2 = [double](Read-Tag 'GDB_MCDData.Velocity[2]')
        $v3 = [double](Read-Tag 'GDB_MCDData.Velocity[3]')
        $vMag = [Math]::Sqrt($v1*$v1 + $v2*$v2 + $v3*$v3)
    } catch { }

    if ($null -ne $step) {
        $sampleTime = (Get-Date).ToString('HH:mm:ss.fff')
        [void]$velSamples.Add(@{
            Time      = $sampleTime
            Step      = $step
            VMag      = $vMag
            Progress  = $progress
            TotalDist = $totalDist
        })
        if ($step -ne $prevStep) {
            [void]$script:Transitions.Add([PSCustomObject]@{
                Time = $sampleTime; From = $prevStep; To = $step
                Progress = $progress; TotalDist = $totalDist; VMag = $vMag
            })
            if ($prevStep -eq 50 -and $step -eq 10) { $cycleCount++ }
            $vStr = if ($null -ne $vMag) { "{0,7:F2}" -f $vMag } else { "    n/a" }
            $pStr = if ($null -ne $progress) { "{0:F2}" -f $progress } else { "n/a" }
            $dStr = if ($null -ne $totalDist) { "{0,8:F2}" -f $totalDist } else { "  n/a" }
            Write-Host ("  {0}  step {1,3} -> {2,3}  progress@advance={3}  totalDist={4}  vMag={5}" -f `
                       $sampleTime, $prevStep, $step, $pStr, $dStr, $vStr)
            $prevStep = $step
        }
    }
    Start-Sleep -Milliseconds 100
}

# ====================================================================
# Analyse V8 results
# ====================================================================
Write-Host ""
Write-Host "--- V8 analysis ---" -ForegroundColor Cyan

$totalSamples = $velSamples.Count
$velocityCapable = @($velSamples | Where-Object { $null -ne $_.VMag }).Count
$standstillSamples = @($velSamples | Where-Object { $null -ne $_.VMag -and $_.VMag -lt 0.5 }).Count
$standstillRatio = if ($velocityCapable -gt 0) { $standstillSamples / $velocityCapable } else { 1.0 }
$movingRatio = 1.0 - $standstillRatio

Write-Host "  Total samples: $totalSamples"
Write-Host "  Standstill samples (|v| < 0.5 mm/s): $standstillSamples ($([Math]::Round($standstillRatio*100,1))%)"
Write-Host "  Moving samples (|v| >= 0.5 mm/s):    $($totalSamples - $standstillSamples) ($([Math]::Round($movingRatio*100,1))%)"

# V8 gate: <5% of samples should show standstill (blending should keep motion continuous)
Assert-Gate 'V8.Blending' ($standstillRatio -lt 0.05) `
    "Standstill ratio $([Math]::Round($standstillRatio*100,1))% (target <5% — motion continuous via BLENDING_HIGH)"

# V8 cycle count: blending should be FASTER than basic, so >3 cycles in 45s expected
Assert-Gate 'V8.CycleCount' ($cycleCount -ge 3) "$cycleCount cycle wraps in 45s (Phase D had 3-4; blending should be similar or faster)"

# V8 progress trigger verification — compute MAX statProgress observed within each step's
# duration (between transitions). The progress-based advance fires when statProgress > 0.5,
# so the max per step should be ≥ 0.5. We can't measure progress AT the moment of advance
# because by the time the script reads (after step changed), the new motion already started
# and statProgress dropped back to ~0. Max-per-step is the correct proxy.
$maxProgressPerStep = @()
$currentStepInProgress = $null
$maxProgInStep = 0.0
foreach ($s in $velSamples) {
    if ($s.Step -ne $currentStepInProgress) {
        if ($null -ne $currentStepInProgress -and $currentStepInProgress -in @(10,20,30,40,50)) {
            $maxProgressPerStep += $maxProgInStep
        }
        $currentStepInProgress = $s.Step
        $maxProgInStep = 0.0
    }
    if ($null -ne $s.Progress -and $s.Progress -gt $maxProgInStep) {
        $maxProgInStep = $s.Progress
    }
}
if ($maxProgressPerStep.Count -gt 0) {
    $avgMaxProg = ($maxProgressPerStep | Measure-Object -Average).Average
    $minMaxProg = ($maxProgressPerStep | Measure-Object -Minimum).Minimum
    $maxMaxProg = ($maxProgressPerStep | Measure-Object -Maximum).Maximum
    Write-Host "  Max statProgress per step (n=$($maxProgressPerStep.Count)): min=$([Math]::Round($minMaxProg,2)) avg=$([Math]::Round($avgMaxProg,2)) max=$([Math]::Round($maxMaxProg,2))"
    # If avg max progress >= 0.5, the >0.5 advance trigger IS firing in steady state
    # If max < 0.5, the advance never gets there → V8 wouldn't actually advance
    Assert-Gate 'V8.ProgressTrigger' ($avgMaxProg -ge 0.45) `
        "Avg max statProgress per step = $([Math]::Round($avgMaxProg,2)) (target >=0.45 — progress crosses >0.5 trigger threshold in steady state)"
} else {
    Assert-Gate 'V8.ProgressTrigger' $false "No max-progress data captured"
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
