[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5',
    [ValidateSet('Arm','Go')]
    [string]$Stage = 'Arm',
    [switch]$Real
)

# =====================================================================
# Trace_OneBox.ps1 -- run EXACTLY ONE palletizing box and self-log the
# joint angles. No TIA trace needed: GDB_MCDData.Position[1..4] mirrors
# J1..J4 (written every scan by FB_MCDDataTransfer) and is readable via
# the PLCSIM-Adv API, so the Go stage polls it directly into a CSV.
#
#   -Stage Arm : prearm axes + PHANTOM palletizing mode + rebuild path.
#   -Stage Go  : pulse bo_Start, poll J1..J4 + statCmdPtr every scan,
#                stop at box 1's retract, dump OneBox_Joints_<stamp>.csv
#                and print per-joint travel-vs-net + a trajectory table.
#
# PHANTOM mode = identical SCARA pick-and-place motion, no belt wait.
# =====================================================================

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force -WarningAction SilentlyContinue
. "$PSScriptRoot\Plcsim_Robust.ps1"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "One-Box Joint Capture   (stage: $Stage)" -ForegroundColor Cyan
Write-Host "  Target IP: $TargetIp" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$null = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

# ---------------------------------------------------------------- ARM
if ($Stage -eq 'Arm') {
    Write-Host "`n[1/4] Pre-arming axes (enable + home)..." -ForegroundColor Yellow
    & "$PSScriptRoot\Prearm_AbcdeAxes.ps1" -TargetIp $TargetIp
    if ($LASTEXITCODE -ne 0) { Write-Host "Pre-arm failed; aborting." -ForegroundColor Red; exit 1 }
    Update-TagList

    $modeName = if ($Real) { 'REAL (conveyor + sensors live)' } else { 'PHANTOM' }
    Write-Host "`n[2/4] Setting $modeName palletizing mode..." -ForegroundColor Yellow
    Safe-Write 'GDB_MachineCmd.bo_Mode'                  $false
    Safe-Write 'GDB_ManualCmd.bo_Mode'                   $false
    Safe-Write 'GDB_PalletizingCmd.bo_Mode'             $true
    Safe-Write 'GDB_PalletizingCmd.bo_RequireSensorGate' ([bool]$Real)
    Safe-Write 'GDB_PalletizingCmd.bo_Start'            $false
    Start-Sleep -Milliseconds 300

    Write-Host "`n[3/4] Rebuilding 16-box path (bo_InitPallet pulse)..." -ForegroundColor Yellow
    Safe-Pulse 'GDB_PalletizingCmd.bo_InitPallet' 400
    Start-Sleep -Milliseconds 500

    Write-Host "`n[4/4] Verify armed state..." -ForegroundColor Yellow
    $mode   = Safe-Read 'GDB_PalletizingCmd.bo_Mode'
    $inited = Safe-Read 'GDB_PalletizingCmd.bo_PalletInitialed'
    $phase  = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase')
    Write-Host ("  bo_Mode={0}  bo_PalletInitialed={1}  statPhase={2}" -f $mode,$inited,$phase)
    if ($mode -eq $true -and $inited -eq $true -and $phase -eq 0) {
        Write-Host "ARMED." -ForegroundColor Green
        exit 0
    }
    Write-Host "ARM FAILED." -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------------- GO
if ($Stage -eq 'Go') {
    $inited = Safe-Read 'GDB_PalletizingCmd.bo_PalletInitialed'
    $mode   = Safe-Read 'GDB_PalletizingCmd.bo_Mode'
    if ($inited -ne $true -or $mode -ne $true) {
        Write-Host "NOT ARMED (bo_PalletInitialed=$inited bo_Mode=$mode). Run -Stage Arm first." -ForegroundColor Red
        exit 1
    }

    Write-Host "`nPulsing bo_Start -- box 1 motion begins, logging J1..J4..." -ForegroundColor Yellow
    Safe-Write 'GDB_PalletizingCmd.bo_Start' $false
    Start-Sleep -Milliseconds 200
    $tStart = Get-Date
    Safe-Write 'GDB_PalletizingCmd.bo_Start' $true
    Start-Sleep -Milliseconds 300
    Safe-Write 'GDB_PalletizingCmd.bo_Start' $false

    $cmdNames = @{ 0='idle';1='WAIT';2='ABOVE_PICK';3='PICK_DESCEND';4='GRIP';
                   5='PICK_RAISE';6='APPROACH_PLACE';7='PLACE_DESCEND';8='RELEASE';9='PLACE_RETRACT' }
    $samples = New-Object System.Collections.Generic.List[object]
    $prevPtr = -99
    $deadline = $tStart.AddSeconds($(if ($Real) { 150 } else { 40 }))
    $stopped = $false

    while ((Get-Date) -lt $deadline) {
        $ptr  = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statCmdPtr')
        $exec = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statExecState')
        $plc  = [int](Safe-Read 'instFB_AutoCtrl_Palletizing.statBoxesPlaced')
        $j1   = [double](Safe-Read 'GDB_MCDData.Position[1]')
        $j2   = [double](Safe-Read 'GDB_MCDData.Position[2]')
        $j3   = [double](Safe-Read 'GDB_MCDData.Position[3]')
        $j4   = [double](Safe-Read 'GDB_MCDData.Position[4]')
        $el   = ((Get-Date)-$tStart).TotalSeconds
        $cn   = if ($ptr -ge 0 -and $ptr -le 9) { $cmdNames[$ptr] } elseif ($ptr -ge 10) { 'box1-done' } else { "cmd$ptr" }
        $samples.Add([PSCustomObject]@{ T=[Math]::Round($el,3); Cmd=$ptr; CmdName=$cn; Exec=$exec; J1=$j1; J2=$j2; J3=$j3; J4=$j4 })
        if ($ptr -ne $prevPtr) {
            Write-Host ("  t={0,6:F2}  cmd {1,-2} {2,-14} J1={3,8:F2} J2={4,8:F2} J3={5,9:F1} J4={6,8:F2}" -f $el,$ptr,$cn,$j1,$j2,$j3,$j4) -ForegroundColor Gray
            $prevPtr = $ptr
        }
        if ( ($ptr -eq 9 -and $exec -eq 1) -or $ptr -ge 10 -or $plc -ge 1 ) {
            Safe-Pulse 'GDB_PalletizingCmd.bo_Stop' 350
            $stopped = $true
            break
        }
    }
    if (-not $stopped) { Safe-Pulse 'GDB_PalletizingCmd.bo_Stop' 350 }

    # let the in-flight retract finish, then log the settled pose
    Start-Sleep -Milliseconds 1800
    for ($k=0; $k -lt 8; $k++) {
        $el = ((Get-Date)-$tStart).TotalSeconds
        $samples.Add([PSCustomObject]@{ T=[Math]::Round($el,3); Cmd=99; CmdName='settled'; Exec=0
            J1=[double](Safe-Read 'GDB_MCDData.Position[1]'); J2=[double](Safe-Read 'GDB_MCDData.Position[2]')
            J3=[double](Safe-Read 'GDB_MCDData.Position[3]'); J4=[double](Safe-Read 'GDB_MCDData.Position[4]') })
        Start-Sleep -Milliseconds 120
    }

    Safe-Write 'GDB_PalletizingCmd.bo_Mode' $false
    Safe-Write 'GDB_PalletizingCmd.bo_RequireSensorGate' $true

    $stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outCsv = "$PSScriptRoot\OneBox_Joints_$stamp.csv"
    $samples | Export-Csv -Path $outCsv -NoTypeInformation
    $n = $samples.Count

    Write-Host ("`n  Captured {0} samples (~{1:F0} ms/sample) -> {2}" -f $n, ($samples[$n-1].T/$n*1000), (Split-Path $outCsv -Leaf)) -ForegroundColor Green

    # --- per-joint travel vs net = the pointless-motion metric ---
    Write-Host "`n--- Per-joint travel vs net displacement ---" -ForegroundColor Yellow
    Write-Host ("  {0,-5} {1,9} {2,9} {3,9} {4,9} {5,9} {6,9}  {7}" -f 'axis','start','end','min','max','net','travel','travel/|net|') -ForegroundColor Gray
    foreach ($j in 'J1','J2','J3','J4') {
        $min=[double]::MaxValue; $max=[double]::MinValue; $travel=0.0; $prev=$null
        foreach ($s in $samples) {
            $v=$s.$j
            if ($v -lt $min){$min=$v}; if ($v -gt $max){$max=$v}
            if ($null -ne $prev){ $travel += [Math]::Abs($v-$prev) }
            $prev=$v
        }
        $st=$samples[0].$j; $en=$samples[$n-1].$j; $net=$en-$st
        $ratio = if ([Math]::Abs($net) -gt 0.5) { '{0:F1}x' -f ($travel/[Math]::Abs($net)) } else { 'n/a' }
        $u = if ($j -eq 'J3') {'mm'} else {'deg'}
        Write-Host ("  {0,-5} {1,9:F1} {2,9:F1} {3,9:F1} {4,9:F1} {5,9:F1} {6,9:F1}  {7,-7} ({8})" -f $j,$st,$en,$min,$max,$net,$travel,$ratio,$u)
    }

    # --- downsampled trajectory ---
    Write-Host "`n--- Joint trajectory (downsampled) ---" -ForegroundColor Yellow
    Write-Host ("  {0,-7} {1,-15} {2,9} {3,9} {4,10} {5,9}" -f 't(s)','command','J1','J2','J3','J4') -ForegroundColor Gray
    $nextT = 0.0
    foreach ($s in $samples) {
        if ($s.T -ge $nextT) {
            Write-Host ("  {0,-7:F2} {1,-15} {2,9:F2} {3,9:F2} {4,10:F1} {5,9:F2}" -f $s.T,$s.CmdName,$s.J1,$s.J2,$s.J3,$s.J4)
            $nextT += 0.30
        }
    }
    Write-Host "`nDone." -ForegroundColor Cyan
    exit 0
}
