[CmdletBinding()]
param(
    [string]$BaseUrl  = 'https://localhost',
    [string]$Username = 'Admin',
    [string]$Password = '12345678',
    [string]$TargetIp = '192.168.0.5',
    [int]$ObserveSeconds = 30
)

<#
.SYNOPSIS
    End-to-end HMI co-driver: drives the HMI via WinCC Unified GraphQL API
    while PLCSIM-Adv monitor captures all tag mutations.

.DESCRIPTION
    Pre-conditions:
      - WinCC Unified PC Runtime serving hmiDemoSCARA_ABCDE at $BaseUrl
      - UMC user $Username has at minimum HMI Operator + HMI Monitor roles
        assigned (for tagValues read + writeTagValues write rights)
      - PLCSIM-Adv 'DemoScara_ABCD' at $TargetIp in Run state
      - Axes pre-armed via Prearm_AbcdeAxes.ps1 (axesReady=TRUE)

    Flow:
      T+0s   GraphQL login -> bearer token
      T+1s   Start Monitor_GDB_HMI_Status.ps1 in background
      T+3s   writeTagValues: bo_Mode = TRUE   (HMI 'Mode' button equivalent)
      T+5s   writeTagValues: bo_InitPath = TRUE  (250ms pulse)
      T+8s   writeTagValues: bo_Start = TRUE  (250ms pulse)
      T+9..39s   observation (monitor captures step transitions)
      T+40s  writeTagValues: bo_Stop = TRUE  (250ms pulse)
      T+42s  cleanup + logout

    The monitor JSON log captures the same V-HMI gate evidence as
    Run_AbcdeCoDriver scenario, except writes originated from HMI API
    not PLCSIM direct.
#>

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\WinCCUnified_GraphQL.psm1" -Force

# ===== Step 1: login =====
Write-Host "[T+0s]  GraphQL login as '$Username'..." -ForegroundColor Cyan
$session = Connect-WinCCUnified -BaseUrl $BaseUrl -Username $Username -Password $Password
Write-Host "  Token: $($session.Token.Substring(0,[Math]::Min(40,$session.Token.Length)))..."
Write-Host "  Expires: $($session.Expires)"

# ===== Step 2: sanity read =====
Write-Host ""
Write-Host "[T+1s]  Sanity read of bo_Mode / bo_Start / i16_AutoStep..." -ForegroundColor Cyan
$probe = Read-WinCCUnifiedTag -Session $session -Names @('bo_Mode','bo_Start','i16_AutoStep')
$probe | Format-Table name, @{n='val';e={$_.value.value}}, @{n='err';e={$_.error.description}}

# ===== Step 3: start monitor in background (Bash-side job via Start-Process) =====
$monitorPath = "$PSScriptRoot\Monitor_GDB_HMI_Status.ps1"
$monitorArgs = "-TargetIp $TargetIp -DurationSeconds $($ObserveSeconds + 20) -NoDashboard"
Write-Host ""
Write-Host "[T+2s]  Starting monitor: $monitorPath $monitorArgs" -ForegroundColor Cyan
$proc = Start-Process pwsh -ArgumentList '-NoProfile','-File',$monitorPath,'-TargetIp',$TargetIp,'-DurationSeconds',($ObserveSeconds + 20).ToString(),'-NoDashboard' -PassThru -WindowStyle Hidden
Write-Host "  Monitor PID: $($proc.Id)"
Start-Sleep -Seconds 2  # let monitor make first snapshot

# ===== Step 4: scenario via HMI API =====
function Pulse-HmiTag {
    param([string]$Tag, [int]$PulseMs = 250)
    Write-WinCCUnifiedTag -Session $session -Tags @{ $Tag = $true }  | Out-Null
    Start-Sleep -Milliseconds $PulseMs
    Write-WinCCUnifiedTag -Session $session -Tags @{ $Tag = $false } | Out-Null
}

Write-Host ""
Write-Host "[T+3s]  bo_Mode := TRUE (toggle, HMI 'Mode' button)" -ForegroundColor Yellow
Write-WinCCUnifiedTag -Session $session -Tags @{ bo_Mode = $true } | Out-Null
Start-Sleep -Seconds 2

Write-Host "[T+5s]  bo_InitPath pulse (HMI 'InitPath' button)" -ForegroundColor Yellow
Pulse-HmiTag -Tag 'bo_InitPath'
Start-Sleep -Seconds 2

Write-Host "[T+8s]  bo_Start pulse (HMI 'Start' button)" -ForegroundColor Yellow
Pulse-HmiTag -Tag 'bo_Start'

Write-Host ""
Write-Host "[T+9..${ObserveSeconds}s]  Observation window — monitor capturing step transitions" -ForegroundColor Yellow
for ($i = 1; $i -le ($ObserveSeconds / 3); $i++) {
    Start-Sleep -Seconds 3
    $r = Read-WinCCUnifiedTag -Session $session -Names @('i16_AutoStep')
    $step = $r[0].value.value
    Write-Host ("  {0}  step={1}" -f (Get-Date).ToString('HH:mm:ss.fff'), $step)
}

Write-Host ""
Write-Host "[T+$($ObserveSeconds + 9)s]  bo_Stop pulse (HMI 'Stop' button)" -ForegroundColor Yellow
Pulse-HmiTag -Tag 'bo_Stop'
Start-Sleep -Seconds 1

# Cleanup
Write-WinCCUnifiedTag -Session $session -Tags @{ bo_Mode = $false } | Out-Null
Write-Host "[T+$($ObserveSeconds + 11)s]  bo_Mode := FALSE (cleanup)" -ForegroundColor Yellow

# Wait for monitor to finish naturally
Write-Host ""
Write-Host "Waiting for monitor to flush log..." -ForegroundColor DarkGray
$proc.WaitForExit(30000)

# Logout
Disconnect-WinCCUnified -Session $session | Out-Null
Write-Host "Session disconnected." -ForegroundColor DarkGray

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "API-driven HMI co-driver scenario COMPLETE" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
