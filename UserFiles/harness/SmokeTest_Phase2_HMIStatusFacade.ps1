[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5'
)

<#
.SYNOPSIS
    Phase 2.4 verification — GDB_HMI_Status read-only facade + FB_HMIStatusMirror.

.DESCRIPTION
    Phase 2.4 (C71) introduces a single read-only "facade" Global DB consolidating
    ~40 display tags from across the system into GDB_HMI_Status. HMI binds reads
    here; HMI writes stay direct to per-mode cmd DBs (mutex still HMI's job).

    Smoke gates (9 total):
      V-Facade.PreflightTags        — all 40 facade tags readable (proves DB+FB deployed)
      V-Facade.ActiveModeRouting    — 7-subtest IF/ELSIF priority chain
                                       (ABCDE > Palletizing > Manual > None)
      V-Facade.TotalStepsRouting    — totalSteps follows CASE (5/48/0/0)
      V-Facade.TargetMirrorPallet   — in Pallet mode, target_xyza == Pallet iDB statTargetPos
      V-Facade.TargetMirrorAbcde    — in ABCDE mode, target_xyza == ABCDE iDB statTargetPos
      V-Facade.ManualHoldsTarget    — Manual mode does NOT overwrite target (holds last)
      V-Facade.NoneHoldsTarget      — None mode does NOT overwrite target (holds last)
      V-Facade.AxesReadyMirror      — facade axesReady == GDB_Control.axesReady (rev 1.3)
      V-Facade.SafetyChainMirror    — estopLock + alarm + pathInitialed + palletInitialed + toolActive flow

    Run AFTER:
      - C69 Phase 2.2 palletizing VERIFIED 12/12 PASS (depends on Pallet iDB)
      - C71 facade VCI sync + Compile Rebuild All + PLCSIM-Adv memory reset + Download
      - DemoScara_ABCD @ .5 in RUN state

.PARAMETER TargetIp
    PLCSIM-Adv instance IP. Default: 192.168.0.5 (DemoScara_ABCD).

.NOTES
    Author: PLC agent (C71, 2026-05-18). All 9 gates depend only on cyclic
    OB1 mirror writes — no cycle motion required. Run takes ~5s.
#>

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force
. "$PSScriptRoot\Plcsim_Robust.ps1"

$script:Results = New-Object System.Collections.ArrayList

function Assert-Gate {
    param([string]$Gate, [bool]$Passed, [string]$Detail)
    $status = 'FAIL'
    $color = 'Red'
    if ($Passed) { $status = 'PASS'; $color = 'Green' }
    [void]$script:Results.Add([PSCustomObject]@{ Gate=$Gate; Status=$status; Detail=$Detail })
    Write-Host ("  [{0}] {1} -- {2}" -f $status, $Gate, $Detail) -ForegroundColor $color
}

function Set-ModeBits {
    param([bool]$Machine, [bool]$Pallet, [bool]$Manual)
    Safe-Write 'GDB_MachineCmd.bo_Mode' $Machine
    Safe-Write 'GDB_PalletizingCmd.bo_Mode' $Pallet
    Safe-Write 'GDB_ManualCmd.bo_Mode' $Manual
    Start-Sleep -Milliseconds 300  # let 2-3 OB1 scans propagate
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Phase 2.4 Verification -- GDB_HMI_Status facade + FB_HMIStatusMirror" -ForegroundColor Cyan
Write-Host "Target: $TargetIp" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$targetName = Connect-PlcsimRobust -TargetIp $TargetIp

# Idle state — clear all mode bits before any sub-tests
Set-ModeBits $false $false $false

# ====================================================================
# V-Facade.PreflightTags — all 40 facade tags readable
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.PreflightTags ---" -ForegroundColor Cyan

$facadeTags = @(
    # REGION 1 arbitration output
    'GDB_HMI_Status.activeMode',
    # REGION 2 mode-routed
    'GDB_HMI_Status.currentStep', 'GDB_HMI_Status.totalSteps',
    'GDB_HMI_Status.target_x', 'GDB_HMI_Status.target_y',
    'GDB_HMI_Status.target_z', 'GDB_HMI_Status.target_a',
    # REGION 3 group axis status
    'GDB_HMI_Status.axesEnabled', 'GDB_HMI_Status.axesHomed',
    'GDB_HMI_Status.axesError', 'GDB_HMI_Status.axesReady',
    # REGION 4 per-joint (4 joints × 6 fields = 24 tags)
    'GDB_HMI_Status.j1_enabled', 'GDB_HMI_Status.j1_homed', 'GDB_HMI_Status.j1_error',
    'GDB_HMI_Status.j1_jogActive', 'GDB_HMI_Status.j1_actualPos', 'GDB_HMI_Status.j1_actualVel',
    'GDB_HMI_Status.j2_enabled', 'GDB_HMI_Status.j2_homed', 'GDB_HMI_Status.j2_error',
    'GDB_HMI_Status.j2_jogActive', 'GDB_HMI_Status.j2_actualPos', 'GDB_HMI_Status.j2_actualVel',
    'GDB_HMI_Status.j3_enabled', 'GDB_HMI_Status.j3_homed', 'GDB_HMI_Status.j3_error',
    'GDB_HMI_Status.j3_jogActive', 'GDB_HMI_Status.j3_actualPos', 'GDB_HMI_Status.j3_actualVel',
    'GDB_HMI_Status.j4_enabled', 'GDB_HMI_Status.j4_homed', 'GDB_HMI_Status.j4_error',
    'GDB_HMI_Status.j4_jogActive', 'GDB_HMI_Status.j4_actualPos', 'GDB_HMI_Status.j4_actualVel',
    # REGION 5 safety + cycle-init + diagnostic
    'GDB_HMI_Status.estopLock', 'GDB_HMI_Status.alarm', 'GDB_HMI_Status.pathInitialed',
    'GDB_HMI_Status.palletInitialed', 'GDB_HMI_Status.toolActive'
)

$preflightOk = $true
foreach ($t in $facadeTags) {
    try {
        $v = Safe-Read $t
        Write-Host ("    OK   {0,-42} = {1}" -f $t, $v) -ForegroundColor DarkGreen
    } catch {
        $preflightOk = $false
        Write-Host ("    FAIL {0,-42} -- {1}" -f $t, $_.Exception.Message) -ForegroundColor Red
    }
}
Assert-Gate 'V-Facade.PreflightTags' $preflightOk ("{0} facade tags readable" -f $facadeTags.Count)
if (-not $preflightOk) {
    Write-Host "Preflight FAILED -- aborting (check operator deploy + memory reset)" -ForegroundColor Red
    exit 1
}

# ====================================================================
# V-Facade.ActiveModeRouting — IF/ELSIF priority chain
# ABCDE > Palletizing > Manual > None
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.ActiveModeRouting ---" -ForegroundColor Cyan

$cases = @(
    @{ label='ABCDE only';                 m=$true;  p=$false; mn=$false; expect=1 },
    @{ label='Palletizing only';           m=$false; p=$true;  mn=$false; expect=2 },
    @{ label='Manual only';                m=$false; p=$false; mn=$true;  expect=3 },
    @{ label='None/Idle';                  m=$false; p=$false; mn=$false; expect=0 },
    @{ label='ABCDE+Pallet (ABCDE wins)';  m=$true;  p=$true;  mn=$false; expect=1 },
    @{ label='Pallet+Manual (Pallet wins)';m=$false; p=$true;  mn=$true;  expect=2 },
    @{ label='All 3 (ABCDE wins)';         m=$true;  p=$true;  mn=$true;  expect=1 }
)

$routingOk = $true
$routingDetails = @()
foreach ($c in $cases) {
    Set-ModeBits $c.m $c.p $c.mn
    $actual = [int](Safe-Read 'GDB_HMI_Status.activeMode')
    $ok = ($actual -eq $c.expect)
    if (-not $ok) { $routingOk = $false }
    $routingDetails += ("{0}: got={1} expect={2}" -f $c.label, $actual, $c.expect)
    Write-Host ("    {0,-6} {1,-32} activeMode={2} (expected {3})" -f $(if($ok){'OK  '}else{'FAIL'}), $c.label, $actual, $c.expect) -ForegroundColor $(if($ok){'DarkGreen'}else{'Red'})
}
Assert-Gate 'V-Facade.ActiveModeRouting' $routingOk ("{0} priority-chain sub-tests" -f $cases.Count)

# ====================================================================
# V-Facade.TotalStepsRouting — CASE assignments
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.TotalStepsRouting ---" -ForegroundColor Cyan

$stepCases = @(
    @{ label='ABCDE';       m=$true;  p=$false; mn=$false; expect=5 },
    @{ label='Palletizing'; m=$false; p=$true;  mn=$false; expect=48 },
    @{ label='Manual';      m=$false; p=$false; mn=$true;  expect=0 },
    @{ label='None';        m=$false; p=$false; mn=$false; expect=0 }
)

$totalStepsOk = $true
foreach ($c in $stepCases) {
    Set-ModeBits $c.m $c.p $c.mn
    $actual = [int](Safe-Read 'GDB_HMI_Status.totalSteps')
    $ok = ($actual -eq $c.expect)
    if (-not $ok) { $totalStepsOk = $false }
    Write-Host ("    {0,-6} {1,-12} totalSteps={2} (expected {3})" -f $(if($ok){'OK  '}else{'FAIL'}), $c.label, $actual, $c.expect) -ForegroundColor $(if($ok){'DarkGreen'}else{'Red'})
}
Assert-Gate 'V-Facade.TotalStepsRouting' $totalStepsOk ("4-branch CASE assigns 5/48/0/0")

# ====================================================================
# V-Facade.TargetMirrorPallet — target_xyza == Pallet iDB
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.TargetMirrorPallet ---" -ForegroundColor Cyan
Set-ModeBits $false $true $false
$srcPalX = [double](Safe-Read 'instFB_AutoCtrl_Palletizing.statTargetPos.x')
$srcPalY = [double](Safe-Read 'instFB_AutoCtrl_Palletizing.statTargetPos.y')
$srcPalZ = [double](Safe-Read 'instFB_AutoCtrl_Palletizing.statTargetPos.z')
$srcPalA = [double](Safe-Read 'instFB_AutoCtrl_Palletizing.statTargetPos.a')
$mirX = [double](Safe-Read 'GDB_HMI_Status.target_x')
$mirY = [double](Safe-Read 'GDB_HMI_Status.target_y')
$mirZ = [double](Safe-Read 'GDB_HMI_Status.target_z')
$mirA = [double](Safe-Read 'GDB_HMI_Status.target_a')
$palOk = ($mirX -eq $srcPalX) -and ($mirY -eq $srcPalY) -and ($mirZ -eq $srcPalZ) -and ($mirA -eq $srcPalA)
Assert-Gate 'V-Facade.TargetMirrorPallet' $palOk ("mirror=($mirX,$mirY,$mirZ,$mirA) src=($srcPalX,$srcPalY,$srcPalZ,$srcPalA)")

# ====================================================================
# V-Facade.TargetMirrorAbcde — target_xyza == ABCDE iDB
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.TargetMirrorAbcde ---" -ForegroundColor Cyan
Set-ModeBits $true $false $false
$srcAbcX = [double](Safe-Read 'instFB_AutoCtrl_ABCDE.statTargetPos.x')
$srcAbcY = [double](Safe-Read 'instFB_AutoCtrl_ABCDE.statTargetPos.y')
$srcAbcZ = [double](Safe-Read 'instFB_AutoCtrl_ABCDE.statTargetPos.z')
$srcAbcA = [double](Safe-Read 'instFB_AutoCtrl_ABCDE.statTargetPos.a')
$mirX = [double](Safe-Read 'GDB_HMI_Status.target_x')
$mirY = [double](Safe-Read 'GDB_HMI_Status.target_y')
$mirZ = [double](Safe-Read 'GDB_HMI_Status.target_z')
$mirA = [double](Safe-Read 'GDB_HMI_Status.target_a')
$abcOk = ($mirX -eq $srcAbcX) -and ($mirY -eq $srcAbcY) -and ($mirZ -eq $srcAbcZ) -and ($mirA -eq $srcAbcA)
Assert-Gate 'V-Facade.TargetMirrorAbcde' $abcOk ("mirror=($mirX,$mirY,$mirZ,$mirA) src=($srcAbcX,$srcAbcY,$srcAbcZ,$srcAbcA)")

# ====================================================================
# V-Facade.ManualHoldsTarget — Manual branch must NOT overwrite target
# ====================================================================
# Capture current target, switch to Manual, verify target unchanged
Write-Host ""
Write-Host "--- V-Facade.ManualHoldsTarget ---" -ForegroundColor Cyan
$beforeX = [double](Safe-Read 'GDB_HMI_Status.target_x')
$beforeY = [double](Safe-Read 'GDB_HMI_Status.target_y')
Set-ModeBits $false $false $true
$afterX = [double](Safe-Read 'GDB_HMI_Status.target_x')
$afterY = [double](Safe-Read 'GDB_HMI_Status.target_y')
$manualHoldOk = ($beforeX -eq $afterX) -and ($beforeY -eq $afterY)
Assert-Gate 'V-Facade.ManualHoldsTarget' $manualHoldOk ("before=($beforeX,$beforeY) after=($afterX,$afterY)")

# ====================================================================
# V-Facade.NoneHoldsTarget — None branch must NOT overwrite target
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.NoneHoldsTarget ---" -ForegroundColor Cyan
$beforeX = [double](Safe-Read 'GDB_HMI_Status.target_x')
$beforeY = [double](Safe-Read 'GDB_HMI_Status.target_y')
Set-ModeBits $false $false $false
$afterX = [double](Safe-Read 'GDB_HMI_Status.target_x')
$afterY = [double](Safe-Read 'GDB_HMI_Status.target_y')
$noneHoldOk = ($beforeX -eq $afterX) -and ($beforeY -eq $afterY)
Assert-Gate 'V-Facade.NoneHoldsTarget' $noneHoldOk ("before=($beforeX,$beforeY) after=($afterX,$afterY)")

# ====================================================================
# V-Facade.AxesReadyMirror — facade axesReady == GDB_Control.axesReady
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.AxesReadyMirror ---" -ForegroundColor Cyan
$srcRdy = [bool](Safe-Read 'GDB_Control.axesReady')
$mirRdy = [bool](Safe-Read 'GDB_HMI_Status.axesReady')
$rdyOk = ($srcRdy -eq $mirRdy)
Assert-Gate 'V-Facade.AxesReadyMirror' $rdyOk ("src=$srcRdy mirror=$mirRdy")

# ====================================================================
# V-Facade.SafetyChainMirror — 5 safety/init/diag tags flow correctly
# ====================================================================
Write-Host ""
Write-Host "--- V-Facade.SafetyChainMirror ---" -ForegroundColor Cyan
$pairs = @(
    @{ src='GDB_MachineCmd.bo_ESTOP_LOCK';    mir='GDB_HMI_Status.estopLock' },
    @{ src='GDB_MachineCmd.bo_PathInitialed'; mir='GDB_HMI_Status.pathInitialed' },
    @{ src='GDB_PalletizingCmd.bo_PalletInitialed'; mir='GDB_HMI_Status.palletInitialed' },
    @{ src='instFB_AxisCtrl.statToolActivated';     mir='GDB_HMI_Status.toolActive' }
)
$safetyOk = $true
foreach ($p in $pairs) {
    $s = Safe-Read $p.src
    $m = Safe-Read $p.mir
    $ok = ($s -eq $m)
    if (-not $ok) { $safetyOk = $false }
    Write-Host ("    {0,-6} {1} -> {2}  (src={3} mir={4})" -f $(if($ok){'OK  '}else{'FAIL'}), $p.src, $p.mir, $s, $m) -ForegroundColor $(if($ok){'DarkGreen'}else{'Red'})
}
# alarm is OR of two sources — check separately
$srcAlarm = [bool](Safe-Read 'GDB_MachineCmd.bo_Alarm') -or [bool](Safe-Read 'GDB_PalletizingCmd.bo_Alarm')
$mirAlarm = [bool](Safe-Read 'GDB_HMI_Status.alarm')
$alarmOk = ($srcAlarm -eq $mirAlarm)
if (-not $alarmOk) { $safetyOk = $false }
Write-Host ("    {0,-6} alarm (Machine OR Palletizing) src={1} mir={2}" -f $(if($alarmOk){'OK  '}else{'FAIL'}), $srcAlarm, $mirAlarm) -ForegroundColor $(if($alarmOk){'DarkGreen'}else{'Red'})
Assert-Gate 'V-Facade.SafetyChainMirror' $safetyOk "estopLock + pathInitialed + palletInitialed + toolActive + alarm"

# ====================================================================
# Summary
# ====================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Phase 2.4 (C71) Facade Smoke Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
$pass = ($script:Results | Where-Object Status -eq 'PASS').Count
$fail = ($script:Results | Where-Object Status -eq 'FAIL').Count
$tot  = $script:Results.Count
$summaryColor = 'Green'
if ($fail -gt 0) { $summaryColor = 'Yellow' }
Write-Host ("Result: {0}/{1} PASS  ({2} FAIL)" -f $pass, $tot, $fail) -ForegroundColor $summaryColor
$script:Results | Format-Table -AutoSize

# Restore idle state
Set-ModeBits $false $false $false
Write-Host "[Mode bits restored to FALSE]" -ForegroundColor DarkGray

# Write log
$logDir = "$PSScriptRoot\..\VCIExportedContents\smoke_logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir ("hmiStatusFacade_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$script:Results | ConvertTo-Json -Depth 3 | Out-File -FilePath $logPath -Encoding UTF8
Write-Host "Log: $logPath" -ForegroundColor DarkGray

if ($fail -gt 0) { exit 1 } else { exit 0 }
