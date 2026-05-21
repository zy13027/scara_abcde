[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5',
    [int]$DurationSeconds = 60,
    [string]$LogDir = "$PSScriptRoot\..\VCIExportedContents\smoke_logs",
    [int]$RefreshMs = 500,
    [switch]$NoDashboard
)

<#
.SYNOPSIS
    Live monitor for GDB_HMI_Status facade (40 tags) + GDB_MachineCmd cmd bits.
    Two outputs:
      - Live console dashboard (Clear-Host + table refresh @ RefreshMs)
      - Append-only JSON log line per snapshot (post-run analyzable)

.DESCRIPTION
    Companion to the HMI Runtime Co-Driver workflow (plan: starry-seeking-seal.md).
    Run this in a separate window or as run_in_background:true. The agent then
    drives the HMI runtime via Chrome MCP and this monitor captures the resulting
    PLC tag mutations end-to-end.

    The JSON log has one line per snapshot:
      {"t":"2026-05-19T08:01:23.456Z","ms":12345,
       "cmd":{"bo_Mode":false,"bo_Start":false,...},
       "facade":{"activeMode":0,"currentStep":0,"target_x":0,...}}

.PARAMETER TargetIp
    PLCSIM-Adv instance IP. Default 192.168.0.5 (DemoScara_ABCD).

.PARAMETER DurationSeconds
    Run duration. Default 60. Monitor exits cleanly when elapsed.

.PARAMETER LogDir
    Where to write the JSON log. Created if missing.

.PARAMETER RefreshMs
    Sample period. Default 500ms. Faster = more samples, more CPU.

.PARAMETER NoDashboard
    Suppress console output (log-only). Useful in background mode.

.OUTPUTS
    Log path printed at start. Returns log path on completion.
#>

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force
. "$PSScriptRoot\Plcsim_Robust.ps1"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $LogDir "hmiRuntimeCoDriver_$timestamp.log"

# Facade tag list — must match GDB_HMI_Status.xml 40 members + key cmd bits we want to correlate
$facadeTags = @(
    'activeMode','currentStep','totalSteps',
    'target_x','target_y','target_z','target_a',
    'axesEnabled','axesHomed','axesError','axesReady',
    'j1_enabled','j1_homed','j1_error','j1_jogActive','j1_actualPos','j1_actualVel',
    'j2_enabled','j2_homed','j2_error','j2_jogActive','j2_actualPos','j2_actualVel',
    'j3_enabled','j3_homed','j3_error','j3_jogActive','j3_actualPos','j3_actualVel',
    'j4_enabled','j4_homed','j4_error','j4_jogActive','j4_actualPos','j4_actualVel',
    'estopLock','alarm','pathInitialed','palletInitialed','toolActive'
)

# Cmd bits we want to correlate to the HMI click events (proves HMI button → PLC tag path)
$cmdTags = @(
    @{ db='GDB_MachineCmd';     name='bo_Mode' },
    @{ db='GDB_MachineCmd';     name='bo_Start' },
    @{ db='GDB_MachineCmd';     name='bo_Stop' },
    @{ db='GDB_MachineCmd';     name='bo_InitPath' },
    @{ db='GDB_MachineCmd';     name='bo_PathInitialed' },
    @{ db='GDB_MachineCmd';     name='i16_AutoStep' },
    @{ db='GDB_PalletizingCmd'; name='bo_Mode' },
    @{ db='GDB_ManualCmd';      name='bo_Mode' }
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "HMI Runtime Co-Driver Monitor" -ForegroundColor Cyan
Write-Host "  Target IP:  $TargetIp" -ForegroundColor Gray
Write-Host "  Duration:   ${DurationSeconds}s" -ForegroundColor Gray
Write-Host "  Refresh:    ${RefreshMs}ms" -ForegroundColor Gray
Write-Host "  Log:        $logPath" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$targetName = Connect-PlcsimRobust -TargetIp $TargetIp

$start = Get-Date
$deadline = $start.AddSeconds($DurationSeconds)
$sampleIdx = 0

# Open log file for append (UTF8 without BOM)
$logStream = [System.IO.StreamWriter]::new($logPath, $false, [System.Text.UTF8Encoding]::new($false))
$logStream.AutoFlush = $true

try {
    while ((Get-Date) -lt $deadline) {
        $loopStart = Get-Date
        $sampleIdx++

        # Read facade tags
        $facade = [ordered]@{}
        foreach ($t in $facadeTags) {
            try { $facade[$t] = Safe-Read "GDB_HMI_Status.$t" }
            catch { $facade[$t] = $null }
        }

        # Read cmd bits
        $cmd = [ordered]@{}
        foreach ($c in $cmdTags) {
            $key = "$($c.db).$($c.name)"
            try { $cmd[$key] = Safe-Read $key }
            catch { $cmd[$key] = $null }
        }

        # Snapshot record
        $snap = [ordered]@{
            t      = $loopStart.ToUniversalTime().ToString('o')
            ms     = [int]($loopStart - $start).TotalMilliseconds
            idx    = $sampleIdx
            cmd    = $cmd
            facade = $facade
        }

        # Append JSON line
        $logStream.WriteLine(($snap | ConvertTo-Json -Depth 3 -Compress))

        # Live dashboard
        if (-not $NoDashboard) {
            Clear-Host
            Write-Host ("=== HMI Co-Driver Monitor  t={0:F1}s  sample #{1}  log={2} ===" -f ($snap.ms/1000.0), $sampleIdx, (Split-Path $logPath -Leaf)) -ForegroundColor Cyan
            Write-Host ""
            Write-Host "REGION 1+2 — Arbitration + Step/Target routing" -ForegroundColor Yellow
            Write-Host ("  activeMode={0,-3}  currentStep={1,-4}  totalSteps={2,-4}" -f $facade.activeMode, $facade.currentStep, $facade.totalSteps)
            Write-Host ("  target  x={0,8:F2}  y={1,8:F2}  z={2,8:F2}  a={3,8:F2}" -f $facade.target_x, $facade.target_y, $facade.target_z, $facade.target_a)
            Write-Host ""
            Write-Host "REGION 3 — Group axis status" -ForegroundColor Yellow
            Write-Host ("  axesEnabled={0,-5}  axesHomed={1,-5}  axesError={2,-5}  axesReady={3,-5}" -f $facade.axesEnabled, $facade.axesHomed, $facade.axesError, $facade.axesReady)
            Write-Host ""
            Write-Host "REGION 4 — Per-joint actuals" -ForegroundColor Yellow
            Write-Host ("  J1 pos={0,8:F2}  vel={1,7:F2}  En={2,-5} Hm={3,-5} Er={4,-5} Jog={5,-5}" -f $facade.j1_actualPos, $facade.j1_actualVel, $facade.j1_enabled, $facade.j1_homed, $facade.j1_error, $facade.j1_jogActive)
            Write-Host ("  J2 pos={0,8:F2}  vel={1,7:F2}  En={2,-5} Hm={3,-5} Er={4,-5} Jog={5,-5}" -f $facade.j2_actualPos, $facade.j2_actualVel, $facade.j2_enabled, $facade.j2_homed, $facade.j2_error, $facade.j2_jogActive)
            Write-Host ("  J3 pos={0,8:F2}  vel={1,7:F2}  En={2,-5} Hm={3,-5} Er={4,-5} Jog={5,-5}" -f $facade.j3_actualPos, $facade.j3_actualVel, $facade.j3_enabled, $facade.j3_homed, $facade.j3_error, $facade.j3_jogActive)
            Write-Host ("  J4 pos={0,8:F2}  vel={1,7:F2}  En={2,-5} Hm={3,-5} Er={4,-5} Jog={5,-5}" -f $facade.j4_actualPos, $facade.j4_actualVel, $facade.j4_enabled, $facade.j4_homed, $facade.j4_error, $facade.j4_jogActive)
            Write-Host ""
            Write-Host "REGION 5 — Safety + cycle init" -ForegroundColor Yellow
            Write-Host ("  estopLock={0,-5}  alarm={1,-5}  pathInitialed={2,-5}  palletInitialed={3,-5}  toolActive={4,-5}" -f $facade.estopLock, $facade.alarm, $facade.pathInitialed, $facade.palletInitialed, $facade.toolActive)
            Write-Host ""
            Write-Host "CMD bits (HMI write targets)" -ForegroundColor Magenta
            Write-Host ("  MachineCmd:  bo_Mode={0,-5}  bo_Start={1,-5}  bo_Stop={2,-5}  bo_InitPath={3,-5}  bo_PathInitialed={4,-5}  i16_AutoStep={5}" `
                -f $cmd['GDB_MachineCmd.bo_Mode'], $cmd['GDB_MachineCmd.bo_Start'], $cmd['GDB_MachineCmd.bo_Stop'], $cmd['GDB_MachineCmd.bo_InitPath'], $cmd['GDB_MachineCmd.bo_PathInitialed'], $cmd['GDB_MachineCmd.i16_AutoStep'])
            Write-Host ("  Mutex:       Pallet.bo_Mode={0,-5}  Manual.bo_Mode={1,-5}" -f $cmd['GDB_PalletizingCmd.bo_Mode'], $cmd['GDB_ManualCmd.bo_Mode'])
            Write-Host ""
            $remaining = [int]($deadline - (Get-Date)).TotalSeconds
            Write-Host ("Remaining: ${remaining}s   (Ctrl+C to exit early)") -ForegroundColor DarkGray
        }

        # Pace to RefreshMs (account for read latency)
        $elapsed = ((Get-Date) - $loopStart).TotalMilliseconds
        $sleepMs = [int]($RefreshMs - $elapsed)
        if ($sleepMs -gt 0) { Start-Sleep -Milliseconds $sleepMs }
    }
}
finally {
    $logStream.Close()
    $logStream.Dispose()
}

Write-Host ""
Write-Host ("Monitor complete. {0} snapshots written to:" -f $sampleIdx) -ForegroundColor Green
Write-Host "  $logPath" -ForegroundColor Green

return $logPath
