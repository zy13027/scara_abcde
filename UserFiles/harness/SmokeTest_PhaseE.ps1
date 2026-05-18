[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5',
    [int]$ObservationSeconds = 90,
    [switch]$SkipOperatorPrompt
)

<#
.SYNOPSIS
    Phase E verification -- NX MCD integration under live ABCDE cycle.

.DESCRIPTION
    Phase E ("MCD auto-connect + follow") is Phase 1's CORE verification per 杨子楠's
    memo to 郑磊 (2026-05-17): "MCD 是第一阶段的核心验证手段, 不是 nice-to-have".

    Architecture (verified via screenshots 2026-05-18):
      - PLC publishes joint actuals every scan via FB_MCDDataTransfer rev 0.2:
          GDB_MCDData.Position[1..4] (kinematic-group order)
          GDB_MCDData.Velocity[1..4] (kinematic-group order)
          GDB_MCDData.J{1..4}_ActualPosition/Velocity (joint-name order; HMI mirror)
      - NX MCD External Signal Configuration discovered all 18 GDB_MCDData tags
        on PLCSIM-Adv instance DemoScara_ABCD (1511T, V8.0.0.0)
      - NX MCD Signal Mapping connects 8 signals (4 Position + 4 Velocity)
        with the J2/J3 deliberate-misorder swap correctly applied:
            NX scaraA2Pos   <- PLC Position[3]  (J2 elbow data per kinematic-group)
            NX scaraA3Pos   <- PLC Position[2]  (J3 Z prismatic data)
            (and same swap on velocities)
      - When the PLC runs the ABCDE cycle, NX MCD viewport should show the
        SCARA model swinging through A->B->C->D->E points in 3D.

    Smoke gates (8 total):
      V-E.PreflightTags         -- 18 GDB_MCDData tags readable (NX consumes them)
      V-E.PublishHealth         -- Position[i] values change across cycle wraps
                                   (proves FB_MCDDataTransfer keeps publishing
                                    under the additional MCD-side read load)
      V-E.MultipleCycleWraps    -- >=6 ABCDE wraps in 90s window (loose
                                   throughput proxy; MCD streaming adds load)
      V-E.NoStuckStep           -- i16_AutoStep transitions remain healthy
                                   (no scan-time blow-out from MCD load)
      V-E.NoAxisError           -- GDB_Control.axesError stays FALSE throughout
      V-E.ToolStaysActive       -- statToolActivated stays TRUE (no UserFault
                                   regression under MCD streaming)
      V-OB91.Inferred           -- PowerShell-side inference; ZERO observable
                                   freeze events => no OB91 saturation. Full
                                   V-OB91 still needs operator TIA Diagnostics
                                   Buffer check (PLCSIM-Adv API doesn't expose
                                   GetDiagnosticBufferEntries on this version).
      V7.OperatorVisualPrompt   -- Y/N prompt: did NX MCD viewport show SCARA
                                   following the ABCDE pattern in 3D?

    Run flow:
      1. Operator opens NX 2506 + the XMD-1001-00-000 SCARA assembly
      2. Operator clicks MCD Play (or makes sure Co-sim is in PlcSim Adv link mode)
      3. Operator runs THIS script
      4. Script drives 90s ABCDE cycle, prompts operator to look at NX viewport,
         logs Y/N response into the result file

.PARAMETER TargetIp
    PLCSIM-Adv instance IP. Default: 192.168.0.5 (DemoScara_ABCD).

.PARAMETER ObservationSeconds
    Cycle observation window in seconds. Default 90 (longer than Phase D's 45s
    to give more confidence on the no-OB91 inference under MCD load).

.PARAMETER SkipOperatorPrompt
    Skip the V7 operator prompt (auto-gates V7 as PENDING). Useful for headless
    scripted runs where no operator is at the console.
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
Write-Host "Phase E Verification -- NX MCD Integration Under Live ABCDE" -ForegroundColor Cyan
Write-Host "Target: $TargetIp / Window: ${ObservationSeconds}s" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$targetName = Connect-PlcsimRobust -TargetIp $TargetIp

# ====================================================================
# Safety reset + bring-up (matches Phase C+G defensive pattern)
# ====================================================================
Write-Host ""
Write-Host "--- Safety reset + bring-up ---" -ForegroundColor Cyan
Safe-Write 'GDB_ManualCmd.bo_Mode' $false
Safe-Pulse 'GDB_MachineCmd.bo_Stop'
Start-Sleep -Milliseconds 400

Safe-Pulse 'GDB_Control.resetAxes'
Start-Sleep -Milliseconds 800

Safe-Write 'GDB_Control.enableAxes' $true
Wait-ForTag 'GDB_Control.axesEnabled' $true -TimeoutSeconds 10 | Out-Null
Write-Host "  axesEnabled=TRUE"

Safe-Write 'GDB_Control.homeAxes' $true
Wait-ForTag 'GDB_Control.axesHomed' $true -TimeoutSeconds 10 | Out-Null
Safe-Write 'GDB_Control.homeAxes' $false
Write-Host "  axesHomed=TRUE"

Safe-Pulse 'GDB_MachineCmd.bo_InitPath'
Wait-ForTag 'GDB_MachineCmd.bo_PathInitialed' $true -TimeoutSeconds 5 | Out-Null
Write-Host "  bo_PathInitialed=TRUE"

Safe-Write 'GDB_MachineCmd.bo_Mode' $true

# ====================================================================
# V-E.PreflightTags -- 18 MCD-consumed tags readable
# ====================================================================
Write-Host ""
Write-Host "--- V-E.PreflightTags ---" -ForegroundColor Cyan
$preflightOk = $true
$mcdTags = @(
    'GDB_MCDData.Position[1]', 'GDB_MCDData.Position[2]', 'GDB_MCDData.Position[3]', 'GDB_MCDData.Position[4]',
    'GDB_MCDData.Velocity[1]', 'GDB_MCDData.Velocity[2]', 'GDB_MCDData.Velocity[3]', 'GDB_MCDData.Velocity[4]',
    'GDB_MCDData.J1_ActualPosition', 'GDB_MCDData.J1_ActualVelocity',
    'GDB_MCDData.J2_ActualPosition', 'GDB_MCDData.J2_ActualVelocity',
    'GDB_MCDData.J3_ActualPosition', 'GDB_MCDData.J3_ActualVelocity',
    'GDB_MCDData.J4_ActualPosition', 'GDB_MCDData.J4_ActualVelocity',
    'GDB_Control.axesEnabled', 'GDB_Control.axesError'
)
foreach ($t in $mcdTags) {
    try { $v = Safe-Read $t; Write-Host ("    OK   {0,-40} = {1}" -f $t, $v) -ForegroundColor DarkGreen }
    catch { $preflightOk = $false; Write-Host ("    FAIL {0,-40} -- {1}" -f $t, $_.Exception.Message) -ForegroundColor Red }
}
Assert-Gate 'V-E.PreflightTags' $preflightOk ("{0} MCD-consumed tags readable" -f $mcdTags.Count)
if (-not $preflightOk) { Write-Host "Preflight FAILED -- aborting" -ForegroundColor Red; exit 1 }

# ====================================================================
# Start ABCDE cycle + sample MCD-consumed tags during observation window
# ====================================================================
Write-Host ""
Write-Host ">>> STARTING ABCDE cycle for Phase E observation <<<" -ForegroundColor Yellow -BackgroundColor DarkBlue
Write-Host ">>> Watch NX MCD viewport for SCARA following ABCDE in 3D <<<" -ForegroundColor Yellow -BackgroundColor DarkBlue
Safe-Pulse 'GDB_MachineCmd.bo_Start'
Start-Sleep -Milliseconds 500

$samples = New-Object System.Collections.ArrayList
$transitions = New-Object System.Collections.ArrayList
$lastStep = 0
$cycleWraps = 0
$startTime = Get-Date
$endTime = $startTime.AddSeconds($ObservationSeconds)
$anyAxisError = $false
$toolStayedActive = $true
$lastTagListRefresh = Get-Date

while ((Get-Date) -lt $endTime) {
    # Periodic tag-cache refresh
    if (((Get-Date) - $lastTagListRefresh).TotalSeconds -ge 3) {
        Test-TagListRefresh
        $lastTagListRefresh = Get-Date
    }

    try {
        $step = [int](Safe-Read 'GDB_MachineCmd.i16_AutoStep')
        $p1 = [double](Safe-Read 'GDB_MCDData.Position[1]')
        $p2 = [double](Safe-Read 'GDB_MCDData.Position[2]')
        $p3 = [double](Safe-Read 'GDB_MCDData.Position[3]')
        $p4 = [double](Safe-Read 'GDB_MCDData.Position[4]')
        $err = [bool](Safe-Read 'GDB_Control.axesError')
        $tool = [bool](Safe-Read 'instFB_AxisCtrl.statToolActivated')
    } catch {
        Write-Warning "  Sample failed: $($_.Exception.Message)"
        Start-Sleep -Milliseconds 200
        continue
    }

    [void]$samples.Add([PSCustomObject]@{
        T_ms = [int](((Get-Date) - $startTime).TotalMilliseconds)
        Step = $step
        P1 = $p1; P2 = $p2; P3 = $p3; P4 = $p4
        Err = $err; Tool = $tool
    })

    if ($step -ne $lastStep) {
        [void]$transitions.Add([PSCustomObject]@{
            T_ms = [int](((Get-Date) - $startTime).TotalMilliseconds)
            From = $lastStep; To = $step
        })
        # Detect wrap (50 -> 10)
        if ($lastStep -eq 50 -and $step -eq 10) { $cycleWraps++ }
        $lastStep = $step
    }

    if ($err)    { $anyAxisError    = $true }
    if (-not $tool) { $toolStayedActive = $false }

    Start-Sleep -Milliseconds 200
}

# Stop the cycle
Safe-Pulse 'GDB_MachineCmd.bo_Stop'
Start-Sleep -Milliseconds 400
$finalStep = [int](Safe-Read 'GDB_MachineCmd.i16_AutoStep')

Write-Host ""
Write-Host "--- Observation window complete ---" -ForegroundColor Cyan
Write-Host ("  Samples collected:  {0}" -f $samples.Count)
Write-Host ("  Step transitions:   {0}" -f $transitions.Count)
Write-Host ("  Cycle wraps (50->10): {0}" -f $cycleWraps)
Write-Host ("  Final step (after stop): {0}" -f $finalStep)

# ====================================================================
# V-E.PublishHealth -- Position[i] not frozen for >3 consecutive samples
# ====================================================================
Write-Host ""
Write-Host "--- V-E.PublishHealth ---" -ForegroundColor Cyan
$maxFreezeRun = 0
$currentFreezeRun = 0
$lastP1 = $null
foreach ($s in $samples) {
    if ($null -ne $lastP1 -and [Math]::Abs($s.P1 - $lastP1) -lt 1e-9) {
        $currentFreezeRun++
        if ($currentFreezeRun -gt $maxFreezeRun) { $maxFreezeRun = $currentFreezeRun }
    } else {
        $currentFreezeRun = 0
    }
    $lastP1 = $s.P1
}
# A real freeze would show >25 consecutive identical samples (5+ seconds at 200ms);
# brief identical runs during idle/stop are normal (we threshold at 25 = 5s).
$publishHealthOk = $maxFreezeRun -lt 25
Assert-Gate 'V-E.PublishHealth' $publishHealthOk ("Position[1] max consecutive-identical run: {0} samples (~{1:F1}s); threshold <25 (5s)" -f $maxFreezeRun, ($maxFreezeRun * 0.2))

# Also probe distinct values across observation -- proves motion happened
$distinctP1 = ($samples | Select-Object -ExpandProperty P1 | Sort-Object -Unique).Count
Write-Host ("  Distinct Position[1] values across window: {0}" -f $distinctP1) -ForegroundColor DarkGray

# ====================================================================
# V-E.MultipleCycleWraps -- robustness inference for V-OB91
# ====================================================================
Write-Host ""
Write-Host "--- V-E.MultipleCycleWraps ---" -ForegroundColor Cyan
$expectedMinWraps = [Math]::Max(3, [int]($ObservationSeconds / 12))  # ~12s per wrap with V8 blending
Assert-Gate 'V-E.MultipleCycleWraps' ($cycleWraps -ge $expectedMinWraps) ("Observed {0} wraps in {1}s; expected >={2}" -f $cycleWraps, $ObservationSeconds, $expectedMinWraps)

# ====================================================================
# V-E.NoStuckStep -- transitions kept happening through whole window
# ====================================================================
Write-Host ""
Write-Host "--- V-E.NoStuckStep ---" -ForegroundColor Cyan
# Look at the last 10s of samples; transitions must still be present
$lastWindowStart = $samples[-1].T_ms - 10000
$recentTransitions = $transitions | Where-Object T_ms -GE $lastWindowStart
Assert-Gate 'V-E.NoStuckStep' ($recentTransitions.Count -ge 1) ("In last 10s of window: {0} step transitions (>=1 expected)" -f $recentTransitions.Count)

# ====================================================================
# V-E.NoAxisError -- axesError stayed FALSE throughout
# ====================================================================
Write-Host ""
Write-Host "--- V-E.NoAxisError ---" -ForegroundColor Cyan
Assert-Gate 'V-E.NoAxisError' (-not $anyAxisError) ("GDB_Control.axesError observed during window: {0} (expect FALSE)" -f $anyAxisError)

# ====================================================================
# V-E.ToolStaysActive -- statToolActivated remained TRUE through MCD load
# ====================================================================
Write-Host ""
Write-Host "--- V-E.ToolStaysActive ---" -ForegroundColor Cyan
Assert-Gate 'V-E.ToolStaysActive' $toolStayedActive ("statToolActivated stayed TRUE throughout {0}s under MCD streaming load: {1}" -f $ObservationSeconds, $toolStayedActive)

# ====================================================================
# V-OB91.Inferred -- inference from cycle health
# Same approach as Phase D smoke: PLCSIM-Adv V5/V6 API doesn't expose
# GetDiagnosticBufferEntries reliably. We infer no-OB91 from the fact that
# motion kept running cleanly under MCD streaming for ${ObservationSeconds}s.
# ====================================================================
Write-Host ""
Write-Host "--- V-OB91.Inferred ---" -ForegroundColor Cyan
$ob91InferredOk = ($cycleWraps -ge $expectedMinWraps) -and (-not $anyAxisError) -and $toolStayedActive
Assert-Gate 'V-OB91.Inferred' $ob91InferredOk ("Inferred PASS: {0} wraps + no axisError + tool stayed active = no OB91 saturation observed during {1}s MCD-streaming run. Operator should additionally check TIA Diagnostics Buffer for confirmation (manual gate)." -f $cycleWraps, $ObservationSeconds)

# ====================================================================
# V7.OperatorVisualPrompt -- Y/N for NX MCD viewport activity
# ====================================================================
Write-Host ""
if ($SkipOperatorPrompt) {
    Assert-Gate 'V7.OperatorVisualPrompt' $false "Skipped via -SkipOperatorPrompt; V7 status remains PENDING (operator must visually confirm NX MCD viewport followed ABCDE in 3D — answer in chat)"
} else {
    Write-Host "--- V7.OperatorVisualPrompt ---" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    During the ${ObservationSeconds}s cycle window, did the NX MCD" -ForegroundColor Yellow
    Write-Host "    viewport show the SCARA model swinging through ABCDE points" -ForegroundColor Yellow
    Write-Host "    in 3D (J2/J3 elbow + Z prismatic + J4 wrist all visibly moving)?" -ForegroundColor Yellow
    Write-Host ""
    # Wrap Read-Host because the smoke is often invoked from a non-interactive
    # harness (e.g., agent-driven PowerShell calls). In non-interactive mode
    # Read-Host throws — gracefully fall through to PENDING + ask operator in chat.
    $response = $null
    try { $response = Read-Host "    [Y]es / [N]o / [S]kip (default S)" } catch { $response = $null }
    switch (("$response").ToUpper()) {
        'Y' { Assert-Gate 'V7.OperatorVisualPrompt' $true "Operator confirmed YES: NX MCD viewport showed SCARA following ABCDE in 3D" }
        'N' { Assert-Gate 'V7.OperatorVisualPrompt' $false "Operator confirmed NO: NX MCD viewport did NOT follow. Investigate signal mapping or MCD Play state." }
        default { Assert-Gate 'V7.OperatorVisualPrompt' $false "Operator did not respond (PowerShell may be non-interactive); V7 remains PENDING — operator confirms in chat after watching viewport during the just-completed ${ObservationSeconds}s run" }
    }
}

# ====================================================================
# Final cleanup + summary
# ====================================================================
Safe-Write 'GDB_MachineCmd.bo_Mode' $false

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Phase E Smoke -- Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
$script:Results | Format-Table -AutoSize
$pass = ($script:Results | Where-Object Status -EQ 'PASS').Count
$fail = ($script:Results | Where-Object Status -EQ 'FAIL').Count
$total = $script:Results.Count
$verdict = if ($fail -eq 0) { 'VERIFIED' } else { 'PENDING_VERIFICATION' }
Write-Host ""
Write-Host ("Gates: {0}/{1} PASS -- VERDICT: {2}" -f $pass, $total, $verdict) -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })

# Write log
$logDir = "$PSScriptRoot\results"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logPath = "$logDir\phaseE_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:Results | Format-Table -AutoSize | Out-String | Out-File -FilePath $logPath -Encoding utf8
Add-Content -Path $logPath -Value ""
Add-Content -Path $logPath -Value ("Observation: ${ObservationSeconds}s")
Add-Content -Path $logPath -Value ("Samples:      {0}" -f $samples.Count)
Add-Content -Path $logPath -Value ("Transitions:  {0}" -f $transitions.Count)
Add-Content -Path $logPath -Value ("Cycle wraps:  {0}" -f $cycleWraps)
Add-Content -Path $logPath -Value ("Distinct P1:  {0}" -f $distinctP1)
Add-Content -Path $logPath -Value ""
Add-Content -Path $logPath -Value ("Total: {0} / Pass: {1} / Fail: {2}" -f $total, $pass, $fail)
Add-Content -Path $logPath -Value ("Verdict: {0}" -f $verdict)
Write-Host ""
Write-Host "Log: $logPath" -ForegroundColor DarkGray

if ($fail -gt 0) { exit 1 } else { exit 0 }
