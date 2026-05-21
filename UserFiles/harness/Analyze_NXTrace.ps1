param(
    [Parameter(Mandatory=$true)][string]$Csv,
    [double]$StepSeconds = 0.45
)
# Parse an NX MCD Runtime-Inspector CSV export. Column 0 = time; columns
# 1..3 = the FIRST tracked body's COM x,y,z (here the suction-cup gripper).
# Reports the gripper's physical trajectory, 3D path length vs net travel,
# and a downsampled table.

$ci = [Globalization.CultureInfo]::InvariantCulture
$lines = [System.IO.File]::ReadAllLines($Csv)
$hdr = $lines[0].Split(',')
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ("NX trace: {0}" -f (Split-Path $Csv -Leaf)) -ForegroundColor Cyan
Write-Host ("Body tracked (cols 1-3): {0}" -f $hdr[1]) -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

$rows = New-Object System.Collections.Generic.List[object]
for ($i=1; $i -lt $lines.Count; $i++) {
    $c = $lines[$i].Split(',')
    if ($c.Count -lt 4 -or [string]::IsNullOrWhiteSpace($c[0])) { continue }
    $rows.Add([PSCustomObject]@{
        T=[double]::Parse($c[0],$ci); X=[double]::Parse($c[1],$ci)
        Y=[double]::Parse($c[2],$ci); Z=[double]::Parse($c[3],$ci)
    })
}
$n = $rows.Count
if ($n -lt 2) { Write-Host "No data."; exit 1 }

Write-Host ("Samples: {0}   Duration: {1:F2}s   (~{2:F0} ms/sample)" -f $n,$rows[$n-1].T,($rows[$n-1].T/$n*1000)) -ForegroundColor Gray

# stats + 3D path length
$pathLen=0.0; $maxStep=0.0; $maxStepT=0.0
$minX=[double]::MaxValue;$maxX=[double]::MinValue
$minY=[double]::MaxValue;$maxY=[double]::MinValue
$minZ=[double]::MaxValue;$maxZ=[double]::MinValue
for ($i=0;$i -lt $n;$i++){
    $r=$rows[$i]
    if($r.X -lt $minX){$minX=$r.X}; if($r.X -gt $maxX){$maxX=$r.X}
    if($r.Y -lt $minY){$minY=$r.Y}; if($r.Y -gt $maxY){$maxY=$r.Y}
    if($r.Z -lt $minZ){$minZ=$r.Z}; if($r.Z -gt $maxZ){$maxZ=$r.Z}
    if($i -gt 0){
        $p=$rows[$i-1]
        $d=[Math]::Sqrt([Math]::Pow($r.X-$p.X,2)+[Math]::Pow($r.Y-$p.Y,2)+[Math]::Pow($r.Z-$p.Z,2))
        $pathLen+=$d
        if($d -gt $maxStep){$maxStep=$d;$maxStepT=$r.T}
    }
}
$s=$rows[0]; $e=$rows[$n-1]
$net=[Math]::Sqrt([Math]::Pow($e.X-$s.X,2)+[Math]::Pow($e.Y-$s.Y,2)+[Math]::Pow($e.Z-$s.Z,2))
Write-Host "`n--- Gripper (tool) trajectory ---" -ForegroundColor Yellow
Write-Host ("  start      : ({0,8:F1}, {1,8:F1}, {2,8:F1})" -f $s.X,$s.Y,$s.Z)
Write-Host ("  end        : ({0,8:F1}, {1,8:F1}, {2,8:F1})" -f $e.X,$e.Y,$e.Z)
Write-Host ("  X range    : {0,8:F1} .. {1,8:F1}   ({2:F1} mm)" -f $minX,$maxX,($maxX-$minX))
Write-Host ("  Y range    : {0,8:F1} .. {1,8:F1}   ({2:F1} mm)" -f $minY,$maxY,($maxY-$minY))
Write-Host ("  Z range    : {0,8:F1} .. {1,8:F1}   ({2:F1} mm)" -f $minZ,$maxZ,($maxZ-$minZ))
Write-Host ("  3D path len: {0:F0} mm" -f $pathLen) -ForegroundColor White
Write-Host ("  net displ. : {0:F0} mm   -> path/net ratio = {1:F1}x" -f $net,($pathLen/[Math]::Max($net,1))) -ForegroundColor White
Write-Host ("  fastest step: {0:F1} mm/sample at t={1:F2}s" -f $maxStep,$maxStepT)

# distance from base (origin) at each sample -> how close to the column
Write-Host "`n--- Trajectory (downsampled) -- R = radius from base (0,0) ---" -ForegroundColor Yellow
Write-Host ("  {0,-7} {1,9} {2,9} {3,9} {4,9}" -f 't(s)','X','Y','Z','R(xy)') -ForegroundColor Gray
$nextT=0.0
$minR=[double]::MaxValue; $minRT=0.0
foreach($r in $rows){
    $rad=[Math]::Sqrt($r.X*$r.X+$r.Y*$r.Y)
    if($rad -lt $minR){$minR=$rad;$minRT=$r.T}
    if($r.T -ge $nextT){
        Write-Host ("  {0,-7:F2} {1,9:F1} {2,9:F1} {3,9:F1} {4,9:F1}" -f $r.T,$r.X,$r.Y,$r.Z,$rad)
        $nextT+=$StepSeconds
    }
}
Write-Host ("`n  closest approach to base: R={0:F0} mm at t={1:F2}s" -f $minR,$minRT) -ForegroundColor White
Write-Host "Done." -ForegroundColor Cyan
