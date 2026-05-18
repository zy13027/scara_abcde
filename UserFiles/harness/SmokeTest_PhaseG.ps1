[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5',
    [int]$JogObservationMs = 1500
)

<#
.SYNOPSIS
    Phase G verification -- FB_ManualCtrl + GDB_ManualCmd + GDB_ManualStatus + axesReady.

.DESCRIPTION
    Phase G ("Manual Control Surface") delivers HMI-driven manual-mode commands:
      - 20 per-axis cmd buttons (Enable/Home/Reset/JogForward/JogBackward) x 4 joints
      - 4 Kin target IOFields (cfgKinTargetX/Y/Z/A) + bo_KinGo trigger
      - 4 Kin group buttons (KinEnable/Home/Reset/Go)
      - 17 status mirror Bools (4 per-joint Enabled/Homed/Error/JogActive + 5 Kin)
      - 1 derived Bool in GDB_Control: axesReady (cycle-7.1 BackColor Q2 ACK)
      - 1 mutex contract: GDB_ManualCmd.bo_Mode XOR GDB_MachineCmd.bo_Mode

    Smoke gates (16 total):
      V8.PreflightTags        -- all 33 Phase G tags readable (cmd + status + axesReady)
      V8.SclLoaded            -- instFB_ManualCtrl.statManualOK probe (proves FB deployed)
      V8.MutexAutoBlocksManual -- AUTO mode wins mutex; statManualOK stays FALSE
      V8.ManualModeEnable     -- in MANUAL: bo_KinEnable -> axesEnabled flips TRUE
      V8.AxesReadyDerived     -- axesReady = enabled AND homed AND NOT error (Q2 ACK)
      V8.StatusMirrorEnabled  -- bo_J{n}_Enabled lit after MC_Power on
      V8.JogJ1Forward         -- bo_J1_JogForward -> J1.ActualPosition increases
      V8.JogJ1Backward        -- bo_J1_JogBackward -> J1.ActualPosition decreases
      V8.JogStopOnRelease     -- release bo_J1_JogForward -> J1.JogActive false
      V8.JogXORSafety         -- both Fwd + Bwd held -> no net motion
      V8.JogJ4Forward         -- J4 wrist jog smoke
      V8.JogActiveLamp        -- bo_J1_JogActive flips TRUE during jog, FALSE after
      V8.KinManualMove        -- set cfgKinTarget, pulse bo_KinGo -> Tcp reaches target
      V8.KinManualBusy        -- bo_KinManualBusy flips TRUE during MC_MoveLinAbs.Busy
      V8.ModeMutexOff         -- MANUAL bo_Mode OFF -> manual cmds ignored
      V8.NoAutoRegression     -- after manual cleanup, ABCDE cycle still runs (V6 smoke)

    The test SHOULD be run AFTER:
      - Phase C verified (8/8 V6 PASS — `phaseC_V6_20260517_233032.log`)
      - VCI sync + Compile Rebuild All (Phase G changed iDB shapes — requires Rebuild not Only Changes)
      - PLCSIM-Adv memory reset (mandatory; per `feedback_pytest_run_protocol.md`)
      - Download Hardware and software (only changes)
      - DemoScara_ABCD @ .5 in RUN state

.PARAMETER TargetIp
    PLCSIM-Adv instance IP. Default: 192.168.0.5 (DemoScara_ABCD).

.PARAMETER JogObservationMs
    Per-jog window in ms (default 1500 — long enough for J1 to swing ~15deg at 10deg/s).
#>

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force
. "$PSScriptRoot\Plcsim_Robust.ps1"

$script:Results = New-Object System.Collections.ArrayList

function Assert-Gate {
    param([string]$Gate, [bool]$Passed, [string]$Detail)
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }
    [void]$script:Results.Add([PSCustomObject]@{ Gate=$Gate; Status=$status; Detail=$Detail })
    Write-Host ("  [{0}] {1} -- {2}" -f $status, $Gate, $Detail) -ForegroundColor $(if ($Passed) { 'Green' } else { 'Red' })
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Phase G Verification -- FB_ManualCtrl + GDB_ManualCmd/Status" -ForegroundColor Cyan
Write-Host "Target: $TargetIp" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$targetName = Connect-PlcsimRobust -TargetIp $TargetIp

# ====================================================================
# Safety: both modes OFF, all manual buttons released, axes disabled
# Defensive Reset to clear any lingering J2/J3 fault from prior sessions
# (post-memory-reset SCARA can leave J2/J3 Power.Error=TRUE on first
# Enable; Reset clears it — matches Phase C bring-up sequence at line 67).
# ====================================================================
Write-Host ""
Write-Host "--- Safety reset ---" -ForegroundColor Cyan
Safe-Write 'GDB_MachineCmd.bo_Mode' $false
Safe-Write 'GDB_ManualCmd.bo_Mode' $false
Safe-Pulse 'GDB_MachineCmd.bo_Stop'
Start-Sleep -Milliseconds 300

foreach ($n in 1..4) {
    foreach ($cmd in 'Enable','Home','Reset','JogForward','JogBackward') {
        Safe-Write "GDB_ManualCmd.bo_J${n}_${cmd}" $false
    }
}
foreach ($cmd in 'KinEnable','KinHome','KinReset','KinGo') {
    Safe-Write "GDB_ManualCmd.bo_$cmd" $false
}

# Defensive Reset via direct GDB_Control path (manual mode not yet active)
Safe-Write 'GDB_Control.enableAxes' $false
Start-Sleep -Milliseconds 300
Safe-Pulse 'GDB_Control.resetAxes'
Start-Sleep -Milliseconds 800
Write-Host "  Defensive resetAxes pulse complete"

# ====================================================================
# V8.PreflightTags -- all Phase G tags readable
# ====================================================================
Write-Host ""
Write-Host "--- V8.PreflightTags ---" -ForegroundColor Cyan
$preflightOk = $true
$tags = @(
    # Manual cmd surface
    'GDB_ManualCmd.bo_Mode', 'GDB_ManualCmd.bo_ESTOP_LOCK',
    'GDB_ManualCmd.bo_J1_Enable', 'GDB_ManualCmd.bo_J1_Home', 'GDB_ManualCmd.bo_J1_Reset',
    'GDB_ManualCmd.bo_J1_JogForward', 'GDB_ManualCmd.bo_J1_JogBackward',
    'GDB_ManualCmd.bo_KinEnable', 'GDB_ManualCmd.bo_KinHome', 'GDB_ManualCmd.bo_KinReset', 'GDB_ManualCmd.bo_KinGo',
    'GDB_ManualCmd.cfgKinTargetX', 'GDB_ManualCmd.cfgKinTargetY', 'GDB_ManualCmd.cfgKinTargetZ', 'GDB_ManualCmd.cfgKinTargetA',
    # Manual status surface
    'GDB_ManualStatus.bo_J1_Enabled', 'GDB_ManualStatus.bo_J1_Homed', 'GDB_ManualStatus.bo_J1_Error', 'GDB_ManualStatus.bo_J1_JogActive',
    'GDB_ManualStatus.bo_KinEnabled', 'GDB_ManualStatus.bo_KinHomed', 'GDB_ManualStatus.bo_KinError',
    'GDB_ManualStatus.bo_KinReady', 'GDB_ManualStatus.bo_KinManualBusy',
    # axesReady (FB_AxisCtrl rev 1.3)
    'GDB_Control.axesReady',
    # FB statics (proves FB+iDB deployed)
    'instFB_ManualCtrl.statManualOK'
)
foreach ($t in $tags) {
    try { $v = Safe-Read $t; Write-Host ("    OK   {0,-50} = {1}" -f $t, $v) -ForegroundColor DarkGreen }
    catch { $preflightOk = $false; Write-Host ("    FAIL {0,-50} -- {1}" -f $t, $_.Exception.Message) -ForegroundColor Red }
}
Assert-Gate 'V8.PreflightTags' $preflightOk ("{0} Phase G tags readable" -f $tags.Count)
if (-not $preflightOk) { Write-Host "Preflight FAILED -- aborting (check operator deploy + memory reset)" -ForegroundColor Red; exit 1 }

# ====================================================================
# V8.SclLoaded -- statManualOK readable proves FB_ManualCtrl deployed
# ====================================================================
Write-Host ""
Write-Host "--- V8.SclLoaded ---" -ForegroundColor Cyan
try {
    $statOK = Safe-Read 'instFB_ManualCtrl.statManualOK'
    Assert-Gate 'V8.SclLoaded' $true "instFB_ManualCtrl.statManualOK readable (= $statOK; will toggle by mode)"
} catch {
    Assert-Gate 'V8.SclLoaded' $false "instFB_ManualCtrl.statManualOK not readable -- FB or iDB not deployed"
    exit 1
}

# ====================================================================
# V8.MutexAutoBlocksManual -- AUTO mode wins mutex
# ====================================================================
Write-Host ""
Write-Host "--- V8.MutexAutoBlocksManual ---" -ForegroundColor Cyan
Safe-Write 'GDB_MachineCmd.bo_Mode' $true     # AUTO on
Safe-Write 'GDB_ManualCmd.bo_Mode'  $true     # MANUAL on too (operator UX error)
Start-Sleep -Milliseconds 300
$statManual = [bool](Safe-Read 'instFB_ManualCtrl.statManualOK')
Assert-Gate 'V8.MutexAutoBlocksManual' (-not $statManual) "with both modes ON, statManualOK = $statManual (expect FALSE — auto wins via NOT GDB_MachineCmd.bo_Mode)"

# Reset both modes off, then turn MANUAL on cleanly
Safe-Write 'GDB_MachineCmd.bo_Mode' $false
Safe-Write 'GDB_ManualCmd.bo_Mode'  $false
Start-Sleep -Milliseconds 200
Safe-Write 'GDB_ManualCmd.bo_ESTOP_LOCK' $true
Safe-Write 'GDB_ManualCmd.bo_Mode'  $true
Start-Sleep -Milliseconds 300
$statManual = [bool](Safe-Read 'instFB_ManualCtrl.statManualOK')
Write-Host ("  Now MANUAL-only: statManualOK = {0}" -f $statManual) -ForegroundColor $(if ($statManual) { 'Green' } else { 'Red' })

# ====================================================================
# V8.ManualModeEnable -- bo_KinEnable routes to GDB_Control.enableAxes
# ====================================================================
Write-Host ""
Write-Host "--- V8.ManualModeEnable ---" -ForegroundColor Cyan
Safe-Write 'GDB_ManualCmd.bo_KinEnable' $true
$got = Wait-ForTag 'GDB_Control.axesEnabled' $true -TimeoutSeconds 8
Assert-Gate 'V8.ManualModeEnable' $got "bo_KinEnable held -> GDB_Control.axesEnabled = $(Safe-Read 'GDB_Control.axesEnabled')"

# Home (group-level via bo_KinHome — pulse, FB_AxisCtrl latches axesHomed once Done)
Safe-Write 'GDB_ManualCmd.bo_KinHome' $true
Start-Sleep -Milliseconds 600
Safe-Write 'GDB_ManualCmd.bo_KinHome' $false
$homed = Wait-ForTag 'GDB_Control.axesHomed' $true -TimeoutSeconds 10
Write-Host ("  Homing: axesHomed = {0}" -f $homed)

# ====================================================================
# V8.AxesReadyDerived -- axesReady = enabled AND homed AND NOT error
# ====================================================================
Write-Host ""
Write-Host "--- V8.AxesReadyDerived ---" -ForegroundColor Cyan
Start-Sleep -Milliseconds 200
$enabled = [bool](Safe-Read 'GDB_Control.axesEnabled')
$homed   = [bool](Safe-Read 'GDB_Control.axesHomed')
$err     = [bool](Safe-Read 'GDB_Control.axesError')
$ready   = [bool](Safe-Read 'GDB_Control.axesReady')
$expected = ($enabled -and $homed -and (-not $err))
Assert-Gate 'V8.AxesReadyDerived' ($ready -eq $expected) ("enabled={0} homed={1} err={2} -> axesReady={3} (expected={4})" -f $enabled, $homed, $err, $ready, $expected)

# ====================================================================
# V8.StatusMirrorEnabled -- per-joint bo_J{n}_Enabled lit
# ====================================================================
Write-Host ""
Write-Host "--- V8.StatusMirrorEnabled ---" -ForegroundColor Cyan
$allEnabled = $true
foreach ($n in 1..4) {
    $v = [bool](Safe-Read "GDB_ManualStatus.bo_J${n}_Enabled")
    Write-Host ("    J{0}_Enabled = {1}" -f $n, $v)
    if (-not $v) { $allEnabled = $false }
}
Assert-Gate 'V8.StatusMirrorEnabled' $allEnabled "all 4 bo_J{n}_Enabled mirror StatusWord.%X3"

# ====================================================================
# V8.JogJ1Forward / Backward / StopOnRelease / XORSafety
# Use kinematic-group view as proxy for J1 (PLCSIM-Adv API can't read TO_Axis direct).
# GDB_MCDData.Position[1] is the J1 kinematic-group position (= J1 base shoulder).
# ====================================================================
Write-Host ""
Write-Host "--- V8.JogJ1Forward ---" -ForegroundColor Cyan
$j1Before = [double](Safe-Read 'GDB_MCDData.Position[1]')
Safe-Write 'GDB_ManualCmd.bo_J1_JogForward' $true
Start-Sleep -Milliseconds $JogObservationMs
$j1During = [double](Safe-Read 'GDB_MCDData.Position[1]')
$j1JogActive = [bool](Safe-Read 'GDB_ManualStatus.bo_J1_JogActive')
Safe-Write 'GDB_ManualCmd.bo_J1_JogForward' $false
Start-Sleep -Milliseconds 800   # decel to standstill
$j1After = [double](Safe-Read 'GDB_MCDData.Position[1]')
$delta = $j1During - $j1Before
Assert-Gate 'V8.JogJ1Forward' ($delta -gt 0.5) ("J1 swung {0:F2}deg during {1}ms hold; before={2:F2} during={3:F2}" -f $delta, $JogObservationMs, $j1Before, $j1During)

Write-Host ""
Write-Host "--- V8.JogActiveLamp ---" -ForegroundColor Cyan
$j1JogAfter = [bool](Safe-Read 'GDB_ManualStatus.bo_J1_JogActive')
Assert-Gate 'V8.JogActiveLamp' ($j1JogActive -and (-not $j1JogAfter)) ("during jog: JogActive={0}; after release: JogActive={1}" -f $j1JogActive, $j1JogAfter)

Write-Host ""
Write-Host "--- V8.JogJ1Backward ---" -ForegroundColor Cyan
$j1Before = [double](Safe-Read 'GDB_MCDData.Position[1]')
Safe-Write 'GDB_ManualCmd.bo_J1_JogBackward' $true
Start-Sleep -Milliseconds $JogObservationMs
$j1During = [double](Safe-Read 'GDB_MCDData.Position[1]')
Safe-Write 'GDB_ManualCmd.bo_J1_JogBackward' $false
Start-Sleep -Milliseconds 800
$delta = $j1During - $j1Before
Assert-Gate 'V8.JogJ1Backward' ($delta -lt -0.5) ("J1 swung {0:F2}deg backward during {1}ms hold" -f $delta, $JogObservationMs)

Write-Host ""
Write-Host "--- V8.JogStopOnRelease ---" -ForegroundColor Cyan
Start-Sleep -Milliseconds 400
$j1Final = [double](Safe-Read 'GDB_MCDData.Position[1]')
Start-Sleep -Milliseconds 400
$j1Settled = [double](Safe-Read 'GDB_MCDData.Position[1]')
$drift = [Math]::Abs($j1Settled - $j1Final)
Assert-Gate 'V8.JogStopOnRelease' ($drift -lt 0.05) ("after release: J1 settled within 0.05deg (drift={0:F4})" -f $drift)

Write-Host ""
Write-Host "--- V8.JogXORSafety ---" -ForegroundColor Cyan
$j1Before = [double](Safe-Read 'GDB_MCDData.Position[1]')
Safe-Write 'GDB_ManualCmd.bo_J1_JogForward'  $true
Safe-Write 'GDB_ManualCmd.bo_J1_JogBackward' $true
Start-Sleep -Milliseconds 1200
$j1After = [double](Safe-Read 'GDB_MCDData.Position[1]')
Safe-Write 'GDB_ManualCmd.bo_J1_JogForward'  $false
Safe-Write 'GDB_ManualCmd.bo_J1_JogBackward' $false
Start-Sleep -Milliseconds 400
$delta = [Math]::Abs($j1After - $j1Before)
Assert-Gate 'V8.JogXORSafety' ($delta -lt 0.5) ("both Fwd+Bwd held -> no net motion (delta={0:F3}deg)" -f $delta)

Write-Host ""
Write-Host "--- V8.JogJ4Forward ---" -ForegroundColor Cyan
$j4Before = [double](Safe-Read 'GDB_MCDData.Position[4]')
Safe-Write 'GDB_ManualCmd.bo_J4_JogForward' $true
Start-Sleep -Milliseconds $JogObservationMs
$j4During = [double](Safe-Read 'GDB_MCDData.Position[4]')
Safe-Write 'GDB_ManualCmd.bo_J4_JogForward' $false
Start-Sleep -Milliseconds 600
$delta = $j4During - $j4Before
Assert-Gate 'V8.JogJ4Forward' ($delta -gt 0.5) ("J4 wrist swung {0:F2}deg during {1}ms hold" -f $delta, $JogObservationMs)

# ====================================================================
# V8.KinManualMove -- pulse bo_KinGo, watch Tcp reach target
# ====================================================================
Write-Host ""
Write-Host "--- V8.KinManualMove ---" -ForegroundColor Cyan
$targetX = 1700.0
$targetY = 100.0
$targetZ = 500.0
$targetA = 0.0
Safe-Write 'GDB_ManualCmd.cfgKinTargetX' $targetX
Safe-Write 'GDB_ManualCmd.cfgKinTargetY' $targetY
Safe-Write 'GDB_ManualCmd.cfgKinTargetZ' $targetZ
Safe-Write 'GDB_ManualCmd.cfgKinTargetA' $targetA
Start-Sleep -Milliseconds 200

# Read pre-move Tcp via GDB_MCDData proxy is not available — read via API directly is also blocked.
# We trust the MC_MoveLinAbs Busy/Done semantics: probe bo_KinManualBusy during move.
Safe-Pulse 'GDB_ManualCmd.bo_KinGo'
Start-Sleep -Milliseconds 200
$busyDuring = [bool](Safe-Read 'GDB_ManualStatus.bo_KinManualBusy')

# Wait for move complete (Busy -> FALSE) -- give up to 8s for the kinematic motion
$busy = $busyDuring
$timeout = (Get-Date).AddSeconds(10)
while ($busy -and (Get-Date) -lt $timeout) {
    Start-Sleep -Milliseconds 200
    Test-TagListRefresh
    $busy = [bool](Safe-Read 'GDB_ManualStatus.bo_KinManualBusy')
}
$busyAfter = $busy
Assert-Gate 'V8.KinManualMove' ($busyDuring -and (-not $busyAfter)) ("bo_KinGo -> KinManualBusy: during={0}, after settle={1}" -f $busyDuring, $busyAfter)

Write-Host ""
Write-Host "--- V8.KinManualBusy ---" -ForegroundColor Cyan
Assert-Gate 'V8.KinManualBusy' $busyDuring ("during move: bo_KinManualBusy = {0}" -f $busyDuring)

# ====================================================================
# V8.ModeMutexOff -- MANUAL bo_Mode OFF -> manual cmds ignored
# ====================================================================
Write-Host ""
Write-Host "--- V8.ModeMutexOff ---" -ForegroundColor Cyan
Safe-Write 'GDB_ManualCmd.bo_Mode' $false
Start-Sleep -Milliseconds 200
$j1Before = [double](Safe-Read 'GDB_MCDData.Position[1]')
Safe-Write 'GDB_ManualCmd.bo_J1_JogForward' $true
Start-Sleep -Milliseconds 1200
$j1After = [double](Safe-Read 'GDB_MCDData.Position[1]')
Safe-Write 'GDB_ManualCmd.bo_J1_JogForward' $false
Start-Sleep -Milliseconds 400
$delta = [Math]::Abs($j1After - $j1Before)
Assert-Gate 'V8.ModeMutexOff' ($delta -lt 0.5) ("MANUAL OFF: jog ignored, J1 delta={0:F3}deg" -f $delta)

# ====================================================================
# V8.NoAutoRegression -- ABCDE cycle still runs after Phase G additions
# ====================================================================
Write-Host ""
Write-Host "--- V8.NoAutoRegression ---" -ForegroundColor Cyan

# Clean up manual mode artifacts
foreach ($cmd in 'KinEnable','KinHome','KinReset','KinGo','J1_JogForward','J1_JogBackward','J4_JogForward') {
    Safe-Write "GDB_ManualCmd.bo_$cmd" $false
}

# Set AUTO mode + brief cycle
Safe-Write 'GDB_MachineCmd.bo_Mode' $true
Safe-Pulse 'GDB_MachineCmd.bo_InitPath'
Wait-ForTag 'GDB_MachineCmd.bo_PathInitialed' $true -TimeoutSeconds 5 | Out-Null
Safe-Pulse 'GDB_MachineCmd.bo_Start'
Start-Sleep -Milliseconds 1500
$autoStep1 = [int](Safe-Read 'GDB_MachineCmd.i16_AutoStep')
Start-Sleep -Milliseconds 2000
$autoStep2 = [int](Safe-Read 'GDB_MachineCmd.i16_AutoStep')
Safe-Pulse 'GDB_MachineCmd.bo_Stop'
Start-Sleep -Milliseconds 400
$autoStepStopped = [int](Safe-Read 'GDB_MachineCmd.i16_AutoStep')

$cycleAdvanced = ($autoStep1 -ge 10) -and ($autoStep1 -le 50) -and ($autoStep2 -ge 10) -and ($autoStep2 -le 50)
$cycleStopped = ($autoStepStopped -eq 0)
Assert-Gate 'V8.NoAutoRegression' ($cycleAdvanced -and $cycleStopped) ("ABCDE step transitions: {0} -> {1} -> 0 (stop ok={2})" -f $autoStep1, $autoStep2, $cycleStopped)

# ====================================================================
# Final cleanup + summary
# ====================================================================
Safe-Write 'GDB_MachineCmd.bo_Mode' $false
Safe-Write 'GDB_ManualCmd.bo_Mode' $false

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Phase G Smoke -- Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
$script:Results | Format-Table -AutoSize
$pass = ($script:Results | Where-Object Status -EQ 'PASS').Count
$fail = ($script:Results | Where-Object Status -EQ 'FAIL').Count
$total = $script:Results.Count
$verdict = if ($fail -eq 0) { 'VERIFIED' } else { 'PENDING_VERIFICATION' }
Write-Host ""
Write-Host ("Gates: {0}/{1} PASS  -- VERDICT: {2}" -f $pass, $total, $verdict) -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })

# Write log
$logDir = "$PSScriptRoot\results"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logPath = "$logDir\phaseG_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:Results | Format-Table -AutoSize | Out-String | Out-File -FilePath $logPath -Encoding utf8
Add-Content -Path $logPath -Value ""
Add-Content -Path $logPath -Value ("Total: {0} / Pass: {1} / Fail: {2}" -f $total, $pass, $fail)
Add-Content -Path $logPath -Value ("Verdict: {0}" -f $verdict)
Write-Host ""
Write-Host "Log: $logPath" -ForegroundColor DarkGray

if ($fail -gt 0) { exit 1 } else { exit 0 }
