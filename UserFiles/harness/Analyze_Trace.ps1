param(
    [Parameter(Mandatory=$true)][string]$Csv,
    [double]$StepSeconds = 0.25
)

# =====================================================================
# Analyze_Trace.ps1 -- parse a TIA trace CSV (J1-J4 + TCP) for the SCARA
# palletizing one-box capture. Reports per-joint travel-vs-net (the
# pointless-motion metric), J2 zero-crossings (elbow-config flips), and a
# downsampled trajectory labelled with the box-1 command that is active.
# =====================================================================

$ci = [Globalization.CultureInfo]::InvariantCulture
function ToSec([string]$ts) {
    $p = $ts.Split(':')
    return [int]$p[0]*3600.0 + [int]$p[1]*60.0 + [double]::Parse($p[2], $ci)
}
function PD([string]$s) { return [double]::Parse($s, $ci) }

# box-1 command offsets (s) relative to motion start (cmd 2 = motion start)
$cmdOff = @(
    @{ off=0.00; name='2 ABOVE_PICK'   },
    @{ off=1.86; name='3 PICK_DESCEND' },
    @{ off=3.89; name='4 GRIP'         },
    @{ off=4.28; name='5 PICK_RAISE'   },
    @{ off=4.51; name='6 APPROACH_PLC' },
    @{ off=6.12; name='7 PLACE_DESCEND'},
    @{ off=7.84; name='8 RELEASE'      },
    @{ off=8.04; name='9 PLACE_RETRACT'}
)
function CmdAt([double]$rel) {
    $c = $cmdOff[0].name
    foreach ($e in $cmdOff) { if ($rel -ge $e.off) { $c = $e.name } }
    return $c
}

$lines = [System.IO.File]::ReadAllLines($Csv)
$rows = New-Object System.Collections.Generic.List[object]
for ($i=1; $i -lt $lines.Count; $i++) {
    $c = $lines[$i].Split(';')
    if ($c.Count -lt 14 -or [string]::IsNullOrWhiteSpace($c[2])) { continue }
    $rows.Add([PSCustomObject]@{
        Sec=(ToSec $c[0]); J1=(PD $c[2]); J2=(PD $c[3]); J3=(PD $c[4]); J4=(PD $c[5])
        X=(PD $c[8]); Y=(PD $c[9]); Z=(PD $c[10])
    })
}
$n = $rows.Count
if ($n -lt 2) { Write-Host "No data rows parsed."; exit 1 }
$t0 = $rows[0].Sec
foreach ($r in $rows) { $r | Add-Member -NotePropertyName T -NotePropertyValue ($r.Sec - $t0) }

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ("Trace: {0}" -f (Split-Path $Csv -Leaf)) -ForegroundColor Cyan
Write-Host ("Samples: {0}   Capture duration: {1:F2}s   (~{2:F1} ms/sample)" -f `
            $n, $rows[$n-1].T, ($rows[$n-1].T/($n-1)*1000)) -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

# --- motion start / end (joints leave / settle) ---
$mStart = 0
for ($i=0; $i -lt $n; $i++) {
    $r=$rows[$i]
    if (([Math]::Abs($r.J1)+[Math]::Abs($r.J2)+[Math]::Abs($r.J3)+[Math]::Abs($r.J4)) -gt 0.05) { $mStart=$i; break }
}
$mEnd = $n-1
for ($i=$n-1; $i -gt $mStart; $i--) {
    $d = [Math]::Abs($rows[$i].J1-$rows[$i-1].J1)+[Math]::Abs($rows[$i].J2-$rows[$i-1].J2)+`
         [Math]::Abs($rows[$i].J3-$rows[$i-1].J3)+[Math]::Abs($rows[$i].J4-$rows[$i-1].J4)
    if ($d -gt 0.02) { $mEnd=[Math]::Min($i+20,$n-1); break }
}
$tm = $rows[$mStart].T
Write-Host ("Motion: starts t={0:F2}s (sample {1}), settles t={2:F2}s -- {3:F2}s of motion" -f `
            $tm, $mStart, $rows[$mEnd].T, ($rows[$mEnd].T-$tm)) -ForegroundColor Gray

# --- per-joint stats: travel vs net = the pointless-motion metric ---
Write-Host "`n--- Per-joint stats (motion window) ---" -ForegroundColor Yellow
Write-Host ("  {0,-5} {1,10} {2,10} {3,10} {4,10} {5,10} {6,10}  {7}" -f `
            'axis','start','end','min','max','net','travel','travel/|net|') -ForegroundColor Gray
foreach ($j in 'J1','J2','J3','J4') {
    $min=[double]::MaxValue; $max=[double]::MinValue; $travel=0.0; $prev=$null
    for ($i=$mStart; $i -le $mEnd; $i++) {
        $v=$rows[$i].$j
        if ($v -lt $min){$min=$v}; if ($v -gt $max){$max=$v}
        if ($null -ne $prev){ $travel += [Math]::Abs($v-$prev) }
        $prev=$v
    }
    $st=$rows[$mStart].$j; $en=$rows[$mEnd].$j; $net=$en-$st
    $ratio = if ([Math]::Abs($net) -gt 0.01) { '{0:F1}x' -f ($travel/[Math]::Abs($net)) } else { 'n/a' }
    $unit = if ($j -eq 'J3') {'mm'} else {'deg'}
    Write-Host ("  {0,-5} {1,10:F1} {2,10:F1} {3,10:F1} {4,10:F1} {5,10:F1} {6,10:F1}  {7}  ({8})" -f `
                $j,$st,$en,$min,$max,$net,$travel,$ratio,$unit)
}

# --- J2 zero-crossings (elbow lefty<->righty config flip) ---
$flips=0
for ($i=$mStart+1; $i -le $mEnd; $i++) {
    if (($rows[$i-1].J2 -gt 0 -and $rows[$i].J2 -lt 0) -or ($rows[$i-1].J2 -lt 0 -and $rows[$i].J2 -gt 0)) { $flips++ }
}
Write-Host ("`n  J2 zero-crossings (elbow config flips): {0}" -f $flips) -ForegroundColor $(if($flips -gt 0){'Red'}else{'Green'})

# --- downsampled trajectory, labelled with the active command ---
Write-Host "`n--- Trajectory (downsampled @ ${StepSeconds}s) ---" -ForegroundColor Yellow
Write-Host ("  {0,-7} {1,-16} {2,9} {3,9} {4,9} {5,9} {6,9} {7,9} {8,9}" -f `
            't_rel','command','J1','J2','J3','J4','Tcp.x','Tcp.y','Tcp.z') -ForegroundColor Gray
$nextT = $rows[$mStart].T
for ($i=$mStart; $i -le $mEnd; $i++) {
    if ($rows[$i].T -ge $nextT) {
        $r=$rows[$i]; $rel=$r.T-$tm
        Write-Host ("  {0,-7:F2} {1,-16} {2,9:F2} {3,9:F2} {4,9:F1} {5,9:F2} {6,9:F1} {7,9:F1} {8,9:F1}" -f `
                    $rel,(CmdAt $rel),$r.J1,$r.J2,$r.J3,$r.J4,$r.X,$r.Y,$r.Z)
        $nextT += $StepSeconds
    }
}
Write-Host "`nDone." -ForegroundColor Cyan
