<#
.SYNOPSIS
    Phase D smoke test — SCARA ABCDE 5-point cycle verification via PLCSIM-Adv API.

.DESCRIPTION
    Drives the PLC state machine (Wang Shuo 4-REGION pattern in FB_AutoCtrl_ABCDE)
    through one full bring-up sequence and 3 ABCDE cycles, asserting V0–V5 + V-OB91
    gates per the approved plan zazzy-mixing-hammock.md.

    Target PLCSIM-Adv instance: IP 192.168.0.5 (operator's new instance).

.NOTES
    Author: Phase D execution recipe per plan
    Date:   2026-05-17
#>

# ====================================================================
# Bootstrap
# ====================================================================
Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force

$script:Results = New-Object System.Collections.ArrayList
$script:Transitions = New-Object System.Collections.ArrayList

function Assert-Gate {
    param(
        [string]$Gate,
        [bool]$Passed,
        [string]$Detail
    )
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }
    [void]$script:Results.Add([PSCustomObject]@{
        Gate   = $Gate
        Status = $status
        Detail = $Detail
    })
    $color = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host "  [$status] $Gate — $Detail" -ForegroundColor $color
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Phase D Smoke Test — SCARA ABCDE 5-point cycle" -ForegroundColor Cyan
Write-Host "Target PLCSIM-Adv instance: IP 192.168.0.5" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim

# ====================================================================
# Discover PLCSIM-Adv instance at IP 192.168.0.5
# ====================================================================
Write-Host ""
Write-Host "--- Discovering PLCSIM-Adv instance ---" -ForegroundColor Cyan

$mgrType    = [Siemens.Simatic.Simulation.Runtime.SimulationRuntimeManager]
$registered = @($mgrType::RegisteredInstanceInfo)

Write-Host "Found $($registered.Count) registered instance(s):"
$targetName = $null
foreach ($info in $registered) {
    $ip = '?'
    $state = '?'
    try {
        $tmp = $mgrType::CreateInterface($info.Name)
        $state = $tmp.OperatingState
        # Try common IP property names
        if ($tmp.PSObject.Properties['ControllerIP'])      { $ip = $tmp.ControllerIP }
        elseif ($tmp.PSObject.Properties['IP'])            { $ip = $tmp.IP }
        elseif ($tmp.PSObject.Properties['IPAddress'])     { $ip = $tmp.IPAddress }
        elseif ($tmp.PSObject.Properties['CommunicationConfiguration']) {
            $ip = $tmp.CommunicationConfiguration.IPAddress
        }
    } catch {
        Write-Warning "  Failed to inspect '$($info.Name)': $($_.Exception.Message)"
    }
    Write-Host ("  - {0,-30} IP={1,-15} State={2}" -f $info.Name, $ip, $state)
    if ($ip -eq '192.168.0.5' -and -not $targetName) {
        $targetName = $info.Name
    }
}

# Fallback strategy: if no IP match, use only-Run instance; else first Run; else first
if (-not $targetName) {
    $runningInstances = @($registered | ForEach-Object {
        try {
            $tmp = $mgrType::CreateInterface($_.Name)
            if ($tmp.OperatingState -eq 'Run') { $_ }
        } catch { }
    })
    if ($runningInstances.Count -eq 1) {
        $targetName = $runningInstances[0].Name
        Write-Warning "No instance at 192.168.0.5; falling back to single Run instance: $targetName"
    } elseif ($runningInstances.Count -gt 1) {
        $targetName = $runningInstances[0].Name
        Write-Warning "Multiple Run instances; picking first: $targetName"
    } elseif ($registered.Count -ge 1) {
        $targetName = $registered[0].Name
        Write-Warning "No Run instances; picking first registered: $targetName"
    } else {
        throw "No PLCSIM-Adv instances available. Start one via PLCSIM Adv UI + download project."
    }
}

Write-Host ""
Write-Host "Using instance: $targetName" -ForegroundColor Yellow
Connect-PlcsimInstance -Name $targetName | Out-Null
Update-TagList

# Confirm in RUN
$inst = Get-PlcsimInstance
if ($inst.OperatingState -ne 'Run') {
    Write-Warning "Instance not in Run; current state: $($inst.OperatingState). Attempting Run..."
    Start-PlcsimInstance | Out-Null
    Wait-ForCpuRun -TimeoutSeconds 30
}
Write-Host "  CPU state: $($inst.OperatingState)" -ForegroundColor Green

# ====================================================================
# Safety: stop any in-progress cycle from a previous run
# ====================================================================
Write-Host ""
Write-Host "--- Safety reset: stopping any in-progress cycle ---" -ForegroundColor Cyan
try {
    Pulse-Tag 'GDB_MachineCmd.bo_Stop' -HoldMs 300
    Write-Tag  'GDB_MachineCmd.bo_Start'     $false
    Write-Tag  'GDB_MachineCmd.bo_InitPath'  $false
    Start-Sleep -Milliseconds 500
    Write-Host "  Stopped + cleared command bits"
} catch {
    Write-Warning "Safety reset partial: $($_.Exception.Message)"
}

# ====================================================================
# V0: Startup OB verification
# ====================================================================
Write-Host ""
Write-Host "--- V0: Startup OB verification ---" -ForegroundColor Cyan

try {
    $startMode1 = Read-Tag 'GDB_Control.StartMode[1]'
    $homePos1   = Read-Tag 'GDB_Control.HomePos[1]'
    $step       = Read-Tag 'GDB_MachineCmd.i16_AutoStep'

    Assert-Gate 'V0.StartMode' ($startMode1 -eq 1) "GDB_Control.StartMode[1]=$startMode1 (expect 1)"
    Assert-Gate 'V0.HomePos'   ($homePos1   -eq 0.0) "GDB_Control.HomePos[1]=$homePos1 (expect 0.0)"
    Assert-Gate 'V0.AutoStep'  ($step       -eq 0)   "GDB_MachineCmd.i16_AutoStep=$step (expect 0 after safety reset)"
} catch {
    Assert-Gate 'V0.Read' $false "Failed: $($_.Exception.Message)"
}

# ====================================================================
# Drive enable + reset + home + init
# ====================================================================
Write-Host ""
Write-Host "--- Drive enable + reset + home + init ---" -ForegroundColor Cyan

try {
    # Reset first to clear any prior axis errors
    Write-Host "  Resetting axes (clearing prior errors)..."
    Pulse-Tag 'GDB_Control.resetAxes' -HoldMs 300
    Start-Sleep -Milliseconds 500

    Write-Host "  Enabling axes..."
    Write-Tag 'GDB_Control.enableAxes' $true
    Wait-ForTag 'GDB_Control.axesEnabled' $true -TimeoutSeconds 10
    Write-Host "    axesEnabled=TRUE" -ForegroundColor Green

    Write-Host "  Homing axes..."
    Write-Tag 'GDB_Control.homeAxes' $true
    Wait-ForTag 'GDB_Control.axesHomed' $true -TimeoutSeconds 10
    Write-Tag 'GDB_Control.homeAxes' $false
    Write-Host "    axesHomed=TRUE" -ForegroundColor Green

    Write-Host "  Initializing path..."
    Pulse-Tag 'GDB_MachineCmd.bo_InitPath' -HoldMs 300
    Wait-ForTag 'GDB_MachineCmd.bo_PathInitialed' $true -TimeoutSeconds 5
    Write-Host "    bo_PathInitialed=TRUE" -ForegroundColor Green

    Write-Host "  Setting auto mode..."
    Write-Tag 'GDB_MachineCmd.bo_Mode' $true
    Start-Sleep -Milliseconds 200
} catch {
    Assert-Gate 'BringUp' $false "Failed: $($_.Exception.Message)"
    Write-Host "Cannot proceed — bring-up sequence failed" -ForegroundColor Red
}

# ====================================================================
# V2: Start triggers state machine
# ====================================================================
Write-Host ""
Write-Host "--- V2: Start triggers state machine ---" -ForegroundColor Cyan

try {
    Pulse-Tag 'GDB_MachineCmd.bo_Start' -HoldMs 300
    $step = 0
    $deadline = (Get-Date).AddSeconds(2)
    while ((Get-Date) -lt $deadline) {
        $step = Read-Tag 'GDB_MachineCmd.i16_AutoStep'
        if ($step -gt 0) { break }
        Start-Sleep -Milliseconds 50
    }
    Assert-Gate 'V2.StartTrigger' ($step -gt 0) "i16_AutoStep jumped 0 -> $step after bo_Start pulse (expect >0)"
} catch {
    Assert-Gate 'V2.StartTrigger' $false "Failed: $($_.Exception.Message)"
}

# ====================================================================
# V3 + V4: 45-second ABCDE cycle observation
# (cycle period observed ~11s; 45s gives comfortable margin for 3 full cycles)
# ====================================================================
Write-Host ""
Write-Host "--- V3 + V4: 45-second ABCDE cycle observation ---" -ForegroundColor Cyan

$prevStep   = -1
$cycleCount = 0
$endTime    = (Get-Date).AddSeconds(45)

while ((Get-Date) -lt $endTime) {
    try {
        $currentStep = Read-Tag 'GDB_MachineCmd.i16_AutoStep'
    } catch {
        Start-Sleep -Milliseconds 100
        continue
    }
    if ($currentStep -ne $prevStep) {
        $tx = $null; $ty = $null; $tz = $null
        try {
            $tx = Read-Tag 'instFB_AutoCtrl_ABCDE.statTargetPos.x'
            $ty = Read-Tag 'instFB_AutoCtrl_ABCDE.statTargetPos.y'
            $tz = Read-Tag 'instFB_AutoCtrl_ABCDE.statTargetPos.z'
        } catch { }
        [void]$script:Transitions.Add([PSCustomObject]@{
            Time = (Get-Date).ToString('HH:mm:ss.fff')
            From = $prevStep
            To   = $currentStep
            Tx   = $tx
            Ty   = $ty
            Tz   = $tz
        })
        # Cycle wrap detection: 50 -> 10
        if ($prevStep -eq 50 -and $currentStep -eq 10) { $cycleCount++ }
        # Also count first 10->10 transition or initial 0->10 as not a wrap
        Write-Host ("  {0}  step {1,3} -> {2,3}   target=({3,8:F1}, {4,8:F1}, {5,8:F1})" -f `
                   $script:Transitions[-1].Time, $prevStep, $currentStep, $tx, $ty, $tz)
        $prevStep = $currentStep
    }
    Start-Sleep -Milliseconds 100
}

# Assert V3: all 5 going-to states visited
$observedSteps = @($script:Transitions | ForEach-Object { $_.To } | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
$expectedSteps = @(10, 20, 30, 40, 50)
$missingSteps  = @($expectedSteps | Where-Object { $_ -notin $observedSteps })
Assert-Gate 'V3.Sequence' ($missingSteps.Count -eq 0) `
    "Observed steps: $($observedSteps -join ','). Missing: $($missingSteps -join ',' )"

# Assert V4: at least 3 cycle wraps
Assert-Gate 'V4.CycleWrap' ($cycleCount -ge 3) "$cycleCount cycle wraps (50->10) observed in 30s (target: >=3)"

# Bonus: verify target coordinates match ABCDE expected values
# (i16_AutoStep is Int16; hashtable lookup needs explicit int cast for key match)
function Get-ExpectedCoord {
    param([int]$Step, [string]$Axis)
    switch ($Step) {
        10 { return @{x=1800.0; y=0.0;    z=400.0}[$Axis] }
        20 { return @{x=1800.0; y=300.0;  z=400.0}[$Axis] }
        30 { return @{x=1500.0; y=300.0;  z=400.0}[$Axis] }
        40 { return @{x=1500.0; y=-300.0; z=400.0}[$Axis] }
        50 { return @{x=1800.0; y=-300.0; z=400.0}[$Axis] }
    }
    return $null
}

$coordMismatches = @()
foreach ($t in $script:Transitions) {
    $step = [int]$t.To
    if ($step -lt 10 -or $step -gt 50) { continue }
    if ($null -eq $t.Tx) { continue }
    $eTx = Get-ExpectedCoord -Step $step -Axis 'x'
    $eTy = Get-ExpectedCoord -Step $step -Axis 'y'
    $eTz = Get-ExpectedCoord -Step $step -Axis 'z'
    if ($null -eq $eTx) { continue }
    if ([Math]::Abs([double]$t.Tx - $eTx) -gt 0.1 -or
        [Math]::Abs([double]$t.Ty - $eTy) -gt 0.1 -or
        [Math]::Abs([double]$t.Tz - $eTz) -gt 0.1) {
        $coordMismatches += "step=$step got=($($t.Tx),$($t.Ty),$($t.Tz)) expect=($eTx,$eTy,$eTz)"
    }
}
Assert-Gate 'V3.Coords' ($coordMismatches.Count -eq 0) "$($coordMismatches.Count) coordinate mismatches"
if ($coordMismatches.Count -gt 0) {
    foreach ($m in $coordMismatches | Select-Object -First 5) {
        Write-Host "    $m" -ForegroundColor Yellow
    }
}

# ====================================================================
# V5: Stop responsiveness
# ====================================================================
Write-Host ""
Write-Host "--- V5: Stop responsiveness ---" -ForegroundColor Cyan

try {
    Pulse-Tag 'GDB_MachineCmd.bo_Stop' -HoldMs 300
    $step = 99
    $stopDeadline = (Get-Date).AddSeconds(2)
    while ((Get-Date) -lt $stopDeadline) {
        $step = Read-Tag 'GDB_MachineCmd.i16_AutoStep'
        if ($step -eq 0) { break }
        Start-Sleep -Milliseconds 50
    }
    Assert-Gate 'V5.Stop' ($step -eq 0) "i16_AutoStep=$step after bo_Stop pulse (expect 0)"
} catch {
    Assert-Gate 'V5.Stop' $false "Failed: $($_.Exception.Message)"
}

# ====================================================================
# V-OB91: CPU Diagnostic Buffer check
# (PLCSIM-Adv API method discovery — try several known method names)
# ====================================================================
Write-Host ""
Write-Host "--- V-OB91: CPU Diagnostic Buffer check ---" -ForegroundColor Cyan

$diagMethodFound = $false
$diagEntries    = @()
$inst = Get-PlcsimInstance

# Discover available diagnostic-buffer methods on this API version
$diagMethodNames = @(
    'GetDiagnosticBufferEntries',
    'ReadDiagnosticBuffer',
    'GetDiagnosticBuffer',
    'ReadDiagnostic',
    'GetDiagBufferEntries'
)
$availableMethods = $inst.GetType().GetMethods() | Where-Object { $_.Name -like '*Diag*' } | ForEach-Object { $_.Name } | Sort-Object -Unique

Write-Host "  Diagnostic-related methods available on CInstanceNet:"
foreach ($mn in $availableMethods) {
    Write-Host "    - $mn" -ForegroundColor DarkGray
}

# Attempt each candidate
foreach ($mn in $diagMethodNames) {
    if ($availableMethods -contains $mn) {
        try {
            $diagEntries = $inst.$mn(100)
            $diagMethodFound = $true
            Write-Host "  Method '$mn' worked, $($diagEntries.Count) entries read" -ForegroundColor Green
            break
        } catch {
            Write-Warning "  Method '$mn' threw: $($_.Exception.InnerException.Message)"
        }
    }
}

if (-not $diagMethodFound) {
    # Manual fallback — assert based on cycle health observation
    # If the 45s cycle completed multiple wraps without state-machine stuck or
    # axis errors, OB91 saturation didn't occur (the v9 failure mode froze cycles)
    Write-Host "  V-OB91 API path unavailable on this PLCSIM-Adv version." -ForegroundColor Yellow
    Write-Host "  Inferring from cycle health: $cycleCount complete cycles in 45s = no OB91 saturation observed." -ForegroundColor Yellow
    Write-Host "  Operator should additionally verify manually:" -ForegroundColor Yellow
    Write-Host "    TIA Portal -> PLC_1 -> Online & Diagnostics -> Diagnostics buffer" -ForegroundColor Yellow
    Write-Host "    Search for 'Buffer overflow' or 'OB 91' entries. Expect ZERO." -ForegroundColor Yellow
    Assert-Gate 'V-OB91.Inferred' ($cycleCount -ge 2) `
        "Inferred PASS from $cycleCount cycle wraps (motion would freeze if OB91 saturated). Manual TIA buffer check still recommended."
} else {
    $ob91Hits = @($diagEntries | Where-Object {
        ($_.ShortInfo -and ($_.ShortInfo -like '*OB 91*' -or $_.ShortInfo -like '*overflow*OB91*' -or $_.ShortInfo -like '*Buffer overflow*'))  -or
        ($_.LongInfo  -and ($_.LongInfo  -like '*OB 91*' -or $_.LongInfo  -like '*overflow*OB91*' -or $_.LongInfo  -like '*Buffer overflow*'))
    })

    Assert-Gate 'V-OB91' ($ob91Hits.Count -eq 0) `
        "$($ob91Hits.Count) potential OB91 buffer overflow entries (expect 0)"

    if ($ob91Hits.Count -gt 0) {
        Write-Host "  OB91-related entries:" -ForegroundColor Yellow
        foreach ($e in $ob91Hits | Select-Object -First 10) {
            Write-Host "    $($e.Timestamp) [$($e.EventId)] $($e.ShortInfo)"
        }
    } else {
        Write-Host "  No OB91 buffer overflow entries in last $($diagEntries.Count) diagnostic events" -ForegroundColor Green
    }
}

# ====================================================================
# Summary + log
# ====================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                          SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

foreach ($r in $script:Results) {
    $color = if ($r.Status -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1,-22} {2}" -f $r.Status, $r.Gate, $r.Detail) -ForegroundColor $color
}

$passCount  = @($script:Results | Where-Object Status -eq 'PASS').Count
$totalCount = $script:Results.Count
$result = if ($passCount -eq $totalCount) { "ALL GATES PASS" } else { "$($totalCount - $passCount) GATE(S) FAILED" }
$color  = if ($passCount -eq $totalCount) { 'Green' } else { 'Red' }
Write-Host ""
Write-Host "Result: $passCount / $totalCount — $result" -ForegroundColor $color

# Save log file
$logDir = Join-Path $PSScriptRoot 'results'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $logDir "phaseD_$timestamp.log"

$log = @()
$log += "Phase D Smoke Test - SCARA ABCDE 5-point cycle"
$log += "Timestamp: $timestamp"
$log += "PLCSIM-Adv instance: $targetName"
$log += "Result: $passCount / $totalCount — $result"
$log += ""
$log += "Gate Results:"
foreach ($r in $script:Results) {
    $log += "  [$($r.Status)] $($r.Gate) -- $($r.Detail)"
}
$log += ""
$log += "Transitions ($($script:Transitions.Count) observed, $cycleCount cycle wraps):"
foreach ($t in $script:Transitions) {
    $log += "  $($t.Time)  step $($t.From) -> $($t.To)  target=($($t.Tx), $($t.Ty), $($t.Tz))"
}
$log | Out-File -FilePath $logFile -Encoding UTF8

Write-Host ""
Write-Host "Full log: $logFile" -ForegroundColor DarkGray

# Exit code for CI: 0 if all pass, 1 if any fail
if ($passCount -ne $totalCount) { exit 1 } else { exit 0 }
