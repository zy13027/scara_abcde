param(
    [Parameter(Mandatory=$true)][string]$Csv,
    [double]$StepSeconds = 0.5
)
# Parse an NX MCD Runtime-Inspector CSV with BOTH the gripper module COM
# (cols 1-3) and the box rbContainer_1 COM (cols 13-15). Decides whether the
# cup captured the box: after the cup reaches the box, if the box COM tracks
# the gripper COM (constant delta) -> captured; if the box stays put -> not.

$ci = [Globalization.CultureInfo]::InvariantCulture
$lines = [System.IO.File]::ReadAllLines($Csv)
$rows = New-Object System.Collections.Generic.List[object]
for ($i=1; $i -lt $lines.Count; $i++) {
    $c = $lines[$i].Split(',')
    if ($c.Count -lt 16 -or [string]::IsNullOrWhiteSpace($c[0])) { continue }
    $rows.Add([PSCustomObject]@{
        T =[double]::Parse($c[0],$ci)
        GX=[double]::Parse($c[1],$ci);  GY=[double]::Parse($c[2],$ci);  GZ=[double]::Parse($c[3],$ci)
        BX=[double]::Parse($c[13],$ci); BY=[double]::Parse($c[14],$ci); BZ=[double]::Parse($c[15],$ci)
    })
}
$n = $rows.Count
if ($n -lt 2) { Write-Host "No data."; exit 1 }

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ("Capture analysis: {0}   ({1} samples, {2:F2}s NX-sim time)" -f (Split-Path $Csv -Leaf),$n,$rows[$n-1].T) -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# closest approach gripper COM <-> box COM
$minD=[double]::MaxValue; $minDi=0
for ($i=0; $i -lt $n; $i++) {
    $r=$rows[$i]
    $d=[Math]::Sqrt([Math]::Pow($r.GX-$r.BX,2)+[Math]::Pow($r.GY-$r.BY,2)+[Math]::Pow($r.GZ-$r.BZ,2))
    if ($d -lt $minD) { $minD=$d; $minDi=$i }
}
$mr=$rows[$minDi]
Write-Host ("`nClosest gripper<->box COM: {0:F1} mm  at t={1:F2}s" -f $minD,$mr.T) -ForegroundColor Yellow
Write-Host ("  gripper COM ({0:F1}, {1:F1}, {2:F1})" -f $mr.GX,$mr.GY,$mr.GZ)
Write-Host ("  box     COM ({0:F1}, {1:F1}, {2:F1})" -f $mr.BX,$mr.BY,$mr.BZ)
Write-Host ("  XY gap {0:F1} mm   Z gap {1:F1} mm" -f `
    ([Math]::Sqrt([Math]::Pow($mr.GX-$mr.BX,2)+[Math]::Pow($mr.GY-$mr.BY,2))),($mr.BZ-$mr.GZ))

# box + gripper paths; box travel AFTER closest approach
$bs=$rows[0]; $be=$rows[$n-1]; $bpath=0.0; $bAfter=0.0
for ($i=1; $i -lt $n; $i++) {
    $p=$rows[$i-1]; $r=$rows[$i]
    $step=[Math]::Sqrt([Math]::Pow($r.BX-$p.BX,2)+[Math]::Pow($r.BY-$p.BY,2)+[Math]::Pow($r.BZ-$p.BZ,2))
    $bpath+=$step
    if ($i -gt $minDi) { $bAfter+=$step }
}
Write-Host ("`nBox  COM: start ({0:F0},{1:F0},{2:F0})  end ({3:F0},{4:F0},{5:F0})" -f $bs.BX,$bs.BY,$bs.BZ,$be.BX,$be.BY,$be.BZ)
Write-Host ("Grip COM: start ({0:F0},{1:F0},{2:F0})  end ({3:F0},{4:F0},{5:F0})" -f $bs.GX,$bs.GY,$bs.GZ,$be.GX,$be.GY,$be.GZ)
Write-Host ("`nBox COM travel AFTER the cup's closest approach: {0:F0} mm" -f $bAfter) -ForegroundColor White
if ($bAfter -lt 30) {
    Write-Host "  => box did NOT move after the cup arrived  ==> CAPTURE FAILED" -ForegroundColor Red
} else {
    Write-Host "  => box moved after the cup arrived  -- check if it tracked the gripper below" -ForegroundColor Green
}

# downsampled table: gripper, box, (box-gripper) delta, distance
Write-Host "`n--- T | gripper XYZ | box XYZ | delta(box-grip) | dist ---" -ForegroundColor Yellow
$nextT=0.0
foreach ($r in $rows) {
    if ($r.T -ge $nextT) {
        $d=[Math]::Sqrt([Math]::Pow($r.GX-$r.BX,2)+[Math]::Pow($r.GY-$r.BY,2)+[Math]::Pow($r.GZ-$r.BZ,2))
        Write-Host ("  {0,6:F2}  G({1,7:F0},{2,6:F0},{3,7:F0})  B({4,7:F0},{5,6:F0},{6,7:F0})  d({7,6:F0},{8,5:F0},{9,6:F0}) |{10,6:F0}|" -f `
            $r.T,$r.GX,$r.GY,$r.GZ,$r.BX,$r.BY,$r.BZ,($r.BX-$r.GX),($r.BY-$r.GY),($r.BZ-$r.GZ),$d)
        $nextT+=$StepSeconds
    }
}
Write-Host "`nIf 'delta(box-grip)' goes CONSTANT after the cup arrives, the box is rigidly held (captured)." -ForegroundColor Gray
Write-Host "If the box XYZ stays frozen while the gripper moves on, the cup never grabbed it." -ForegroundColor Gray
