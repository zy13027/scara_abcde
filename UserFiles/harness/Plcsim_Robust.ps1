<#
.SYNOPSIS
    Plcsim_Robust.ps1 — drop-in robustness helpers for PLCSIM-Adv smoke tests.

.DESCRIPTION
    Defines functions that defeat two recurring PLCSIM-Adv API quirks observed
    during the v9 Phase 1 + Phase 2 verification cycles (2026-05-17):

    1. **IP discovery handles array-valued IP property** — multi-NIC PLCSIM-Adv
       instances (e.g. the v9 `1511T` 1511T-1 PN) return `IPAddress` as a
       string array, not a single string. Naive `$ip -eq $TargetIp` checks
       silently fail; this helper iterates all IPs per instance and uses
       `-contains` for matching.

    2. **Tag descriptor cache goes stale during long observation loops** —
       individual `Read-Tag` calls can intermittently return "Error Code: -4
       DoesNotExist" even for valid tags. Solution: call `Update-TagList`
       periodically (every ~3s) during observation, plus retry-with-refresh
       on every read/write/pulse.

.USAGE
    Dot-source at the top of any smoke test script:

      Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force
      . "$PSScriptRoot\Plcsim_Robust.ps1"

      Initialize-Plcsim
      $targetName = Connect-PlcsimRobust -TargetIp '192.168.0.10'
      # ... now use Safe-Read / Safe-Write / Safe-Pulse instead of Read-Tag / Write-Tag / Pulse-Tag

      # In observation loops, add periodic refresh:
      while (...) {
          Test-TagListRefresh   # auto-refreshes every 3s; cheap no-op between
          ...
      }

.NOTES
    Authored 2026-05-17 after Phase 2 V2 smoke test mis-reported 0/48 steps
    visited (the cycle was actually fine; the test loop's silent `try {} catch {}`
    masked tag cache transients). See NOTE_v9_UserFault_RootCause_Analysis.md
    for the broader analysis context.
#>

# ====================================================================
# IP discovery — handle multi-NIC instances (IPAddress returns array)
# ====================================================================
function Get-PlcsimInstanceIPs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Instance
    )

    $ips = @()
    foreach ($propName in @('ControllerIP', 'IP', 'IPAddress')) {
        if ($Instance.PSObject.Properties[$propName]) {
            $val = $Instance.$propName
            if ($val -is [array]) {
                $ips += @($val | ForEach-Object { [string]$_ })
            } elseif ($val) {
                $ips += [string]$val
            }
        }
    }

    if ($Instance.PSObject.Properties['CommunicationConfiguration']) {
        $cc = $Instance.CommunicationConfiguration
        if ($cc.PSObject.Properties['IPAddress']) {
            $val = $cc.IPAddress
            if ($val -is [array]) {
                $ips += @($val | ForEach-Object { [string]$_ })
            } elseif ($val) {
                $ips += [string]$val
            }
        }
    }

    return @($ips | Where-Object { $_ -and $_ -ne '0.0.0.0' } | Sort-Object -Unique)
}

# ====================================================================
# Connect-PlcsimRobust — discover by IP, fallback to running, fallback to first
# ====================================================================
function Connect-PlcsimRobust {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetIp,
        [string]$InstanceName  # optional: bypass IP discovery, connect by name
    )

    $mgrType = [Siemens.Simatic.Simulation.Runtime.SimulationRuntimeManager]
    $registered = @($mgrType::RegisteredInstanceInfo)
    if ($registered.Count -eq 0) {
        throw "No PLCSIM-Adv instances registered. Start one via PLCSIM Adv UI + download project."
    }

    if ($InstanceName) {
        Write-Host "Connecting to instance by explicit name: $InstanceName" -ForegroundColor Yellow
        Connect-PlcsimInstance -Name $InstanceName | Out-Null
        Update-TagList; Start-Sleep -Milliseconds 500; Update-TagList
        $Global:LastTagRefresh = Get-Date
        return $InstanceName
    }

    Write-Host "Discovering PLCSIM-Adv instance at IP $TargetIp..." -ForegroundColor Cyan
    $targetName = $null
    foreach ($info in $registered) {
        try {
            $tmp = $mgrType::CreateInterface($info.Name)
            $ips = Get-PlcsimInstanceIPs -Instance $tmp
            Write-Host ("  - {0,-30}  IPs:[{1}]  State:{2}" -f $info.Name, ($ips -join ','), $tmp.OperatingState)
            if ($ips -contains $TargetIp -and -not $targetName) {
                $targetName = $info.Name
                Write-Host "    ^ MATCHES TARGET $TargetIp" -ForegroundColor Green
            }
        } catch {
            Write-Host ("  - {0,-30}  (inspect error: {1})" -f $info.Name, $_.Exception.Message) -ForegroundColor DarkYellow
        }
    }

    if (-not $targetName) {
        $running = @()
        foreach ($info in $registered) {
            try {
                $tmp = $mgrType::CreateInterface($info.Name)
                if ($tmp.OperatingState -eq 'Run') { $running += $info.Name }
            } catch { }
        }
        if ($running.Count -eq 1) {
            $targetName = $running[0]
            Write-Warning "No instance at $TargetIp; falling back to single Run instance: $targetName"
        } elseif ($running.Count -gt 1) {
            $targetName = $running[0]
            Write-Warning "Multiple Run instances; picking first: $targetName"
        } else {
            $targetName = $registered[0].Name
            Write-Warning "No Run instances; picking first registered: $targetName"
        }
    }

    Write-Host ""
    Write-Host "Connecting to: $targetName" -ForegroundColor Yellow
    Connect-PlcsimInstance -Name $targetName | Out-Null
    Update-TagList; Start-Sleep -Milliseconds 500; Update-TagList
    $Global:LastTagRefresh = Get-Date

    $inst = Get-PlcsimInstance
    if ($inst.OperatingState -ne 'Run') {
        Write-Warning "Instance not in Run; current state: $($inst.OperatingState). Attempting Run..."
        Start-PlcsimInstance | Out-Null
        Wait-ForCpuRun -TimeoutSeconds 30
    }
    Write-Host "  CPU state: $($inst.OperatingState)" -ForegroundColor Green

    return $targetName
}

# ====================================================================
# Safe-Read / Safe-Write / Safe-Pulse — retry-with-refresh on transient cache failure
# ====================================================================
function Safe-Read {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Tag,
        [int]$MaxRetries = 3
    )
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try { return Read-Tag $Tag } catch {
            if ($i -eq ($MaxRetries - 1)) { throw }
            Update-TagList
            $Global:LastTagRefresh = Get-Date
            Start-Sleep -Milliseconds 200
        }
    }
}

function Safe-Write {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Tag,
        [Parameter(Mandatory=$true)]$Value,
        [int]$MaxRetries = 3
    )
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try { Write-Tag $Tag $Value; return } catch {
            if ($i -eq ($MaxRetries - 1)) { throw }
            Update-TagList
            $Global:LastTagRefresh = Get-Date
            Start-Sleep -Milliseconds 300
        }
    }
}

function Safe-Pulse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Tag,
        [int]$HoldMs = 300
    )
    Safe-Write -Tag $Tag -Value $true
    Start-Sleep -Milliseconds $HoldMs
    Safe-Write -Tag $Tag -Value $false
}

# ====================================================================
# Test-TagListRefresh — call from observation-loop body for periodic refresh
# (cheap no-op if last refresh was within $IntervalSec)
# ====================================================================
if (-not (Get-Variable -Name 'LastTagRefresh' -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:LastTagRefresh = Get-Date
}

function Test-TagListRefresh {
    [CmdletBinding()]
    param(
        [int]$IntervalSec = 3
    )
    if (((Get-Date) - $Global:LastTagRefresh).TotalSeconds -gt $IntervalSec) {
        try { Update-TagList } catch { }
        $Global:LastTagRefresh = Get-Date
    }
}

# ====================================================================
# Module-load message (visible when dot-sourced)
# ====================================================================
Write-Host "[Plcsim_Robust] Helpers loaded: Get-PlcsimInstanceIPs, Connect-PlcsimRobust, Safe-Read, Safe-Write, Safe-Pulse, Test-TagListRefresh" -ForegroundColor DarkGray
