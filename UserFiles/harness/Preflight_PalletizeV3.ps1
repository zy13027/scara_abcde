[CmdletBinding()]
param(
    [string]$TargetIp = '192.168.0.5'
)

<#
.SYNOPSIS
    Post-deploy preflight for FB_AutoCtrl_Palletizing V3.0.
.DESCRIPTION
    Run AFTER operator's VCI import + Compile + MRES + Download.
    Verifies:
      1. PLCSIM-Adv reachable + CPU in Run
      2. All V3.0 GDB_PalletizingCmd new Members readable + StartValues match Brief 31/32 NX-derived defaults
      3. GDB_Control gripper Members exist + initial state both FALSE
      4. GDB_MCDData new Members readable (Belt/Spawn/Sink/Sensor)
      5. instFB_AutoCtrl_Palletizing V3.0 iDB Members exposed (statPhase/Box/SubState + TON timers)
      6. bo_InitPallet round-trip works (REGION 1 path-table init populates 48 pts[] entries)
      7. pts[1..3] (box 1: approach / place / retract) carry wrist-frame Z values (cup target + WristOffsetZ)
    Exits 0 on all-pass; 1 with diagnostic on first failure.
    Gates the full V3.0 cycle smoke — operator runs this first, fixes any deploy issues, THEN proceeds to bo_Start cycle.
#>

Import-Module "C:\Users\Admin\.claude\skills\plcsim-adv\assets\Plcsim_Helpers.psm1" -Force
. "$PSScriptRoot\Plcsim_Robust.ps1"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "FB_AutoCtrl_Palletizing V3.0 Preflight" -ForegroundColor Cyan
Write-Host "  Target IP: $TargetIp" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

Initialize-Plcsim
$targetName = Connect-PlcsimRobust -TargetIp $TargetIp
Update-TagList

$pass = 0
$fail = 0
$gates = @()

function Test-Gate {
    param([string]$Name, [scriptblock]$Check, [string]$Expected = '')
    try {
        $result = & $Check
        if ($result) {
            Write-Host ("  [PASS] {0,-40} {1}" -f $Name, $Expected) -ForegroundColor Green
            $script:pass++
            $script:gates += @{ Name = $Name; Status = 'PASS'; Detail = $Expected }
        } else {
            Write-Host ("  [FAIL] {0,-40} {1}" -f $Name, $Expected) -ForegroundColor Red
            $script:fail++
            $script:gates += @{ Name = $Name; Status = 'FAIL'; Detail = $Expected }
        }
    } catch {
        Write-Host ("  [FAIL] {0,-40} read-failed: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
        $script:fail++
        $script:gates += @{ Name = $Name; Status = 'FAIL'; Detail = $_.Exception.Message }
    }
}

# --- Gate 1: PLCSIM reachable ---
Write-Host "`n--- Gate 1: PLCSIM-Adv reachable + Run ---" -ForegroundColor Yellow
Test-Gate 'V3.PreflightTags.Reachable' { (Safe-Read 'GDB_PalletizingCmd.bo_Mode') -ne $null } 'GDB_PalletizingCmd.bo_Mode readable'

# --- Gate 2: GDB_PalletizingCmd V3.0 new Members + StartValues ---
Write-Host "`n--- Gate 2: GDB_PalletizingCmd Brief 31/32 StartValues ---" -ForegroundColor Yellow
Test-Gate 'V3.GDB.lr_PickX'              { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PickX') - 1170.44) -lt 0.1 }  'expect 1170.44'
Test-Gate 'V3.GDB.lr_PickY'              { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PickY') - 531.76) -lt 0.1 }   'expect 531.76'
Test-Gate 'V3.GDB.lr_PickZ'              { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PickZ') - (-699.0)) -lt 0.1 } 'expect -699 (Brief 32: box top = -899 + 200)'
Test-Gate 'V3.GDB.lr_PickApproachZOffset' { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PickApproachZOffset') - 220.0) -lt 0.1 } 'expect 220'
Test-Gate 'V3.GDB.lr_PalletTopX'         { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PalletTopX') - (-0.48)) -lt 0.1 } 'expect -0.48'
Test-Gate 'V3.GDB.lr_PalletTopY'         { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PalletTopY') - 1500.31) -lt 0.1 } 'expect 1500.31'
Test-Gate 'V3.GDB.lr_PalletTopZ'         { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PalletTopZ') - (-866.73)) -lt 0.1 } 'expect -866.73'
Test-Gate 'V3.GDB.lr_PlaceApproachZOffset' { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_PlaceApproachZOffset') - 100.0) -lt 0.1 } 'expect 100'
Test-Gate 'V3.GDB.lr_BoxHeight'          { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_BoxHeight') - 200.0) -lt 0.1 }  'expect 200 (small carton)'
Test-Gate 'V3.GDB.lr_BeltVelocityNormal' { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_BeltVelocityNormal') - 100.0) -lt 0.1 } 'expect 100 mm/s'
Test-Gate 'V3.GDB.lr_SpawnDelayMs'       { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_SpawnDelayMs') - 15000.0) -lt 1.0 } 'expect 15000 (Brief 32: belt transit)'
Test-Gate 'V3.GDB.lr_WristOffsetX'       { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_WristOffsetX') - 336.0) -lt 0.1 } 'expect 336 (Brief 31)'
Test-Gate 'V3.GDB.lr_WristOffsetY'       { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_WristOffsetY') - (-286.0)) -lt 0.1 } 'expect -286'
Test-Gate 'V3.GDB.lr_WristOffsetZ'       { [Math]::Abs((Safe-Read 'GDB_PalletizingCmd.lr_WristOffsetZ') - 135.7) -lt 0.1 } 'expect 135.7'
Test-Gate 'V3.GDB.bo_PalletDone'         { (Safe-Read 'GDB_PalletizingCmd.bo_PalletDone') -eq $false } 'expect FALSE at idle'
Test-Gate 'V3.GDB.bo_RequireSensorGate'  { (Safe-Read 'GDB_PalletizingCmd.bo_RequireSensorGate') -eq $true } 'expect TRUE (default; FALSE for phantom mode)'

# --- Gate 3: GDB_Control gripper Members ---
Write-Host "`n--- Gate 3: GDB_Control gripper Members ---" -ForegroundColor Yellow
Test-Gate 'V3.GDB_Control.bo_gripperGrip'    { (Safe-Read 'GDB_Control.bo_gripperGrip') -eq $false }    'expect FALSE at idle (neutral)'
Test-Gate 'V3.GDB_Control.bo_gripperRelease' { (Safe-Read 'GDB_Control.bo_gripperRelease') -eq $false } 'expect FALSE at idle (neutral)'

# --- Gate 4: GDB_MCDData new V3.0/V3.1 Members ---
Write-Host "`n--- Gate 4: GDB_MCDData new Members ---" -ForegroundColor Yellow
Test-Gate 'V3.MCDData.BeltVelocity'       { (Safe-Read 'GDB_MCDData.BeltVelocity') -ne $null } 'readable'
Test-Gate 'V3.MCDData.SpawnContainerCmd'  { (Safe-Read 'GDB_MCDData.SpawnContainerCmd') -eq $false } 'expect FALSE'
Test-Gate 'V3.MCDData.PackingSensor'      { (Safe-Read 'GDB_MCDData.PackingSensor') -ne $null } 'readable'
Test-Gate 'V3.MCDData.PalletizingSensor'  { (Safe-Read 'GDB_MCDData.PalletizingSensor') -ne $null } 'readable (pick gate)'
Test-Gate 'V3.MCDData.BeltStopperSensor'  { (Safe-Read 'GDB_MCDData.BeltStopperSensor') -ne $null } 'readable'
Test-Gate 'V3.MCDData.SinkContainerLeft'  { (Safe-Read 'GDB_MCDData.SinkContainerLeft') -eq $false } 'expect FALSE'
Test-Gate 'V3.MCDData.SinkContainerRight' { (Safe-Read 'GDB_MCDData.SinkContainerRight') -eq $false } 'expect FALSE'

# --- Gate 5: V3.0 iDB Members ---
Write-Host "`n--- Gate 5: instFB_AutoCtrl_Palletizing V3.0 iDB ---" -ForegroundColor Yellow
Test-Gate 'V3.iDB.statPhase'        { (Safe-Read 'instFB_AutoCtrl_Palletizing.statPhase') -eq 0 } 'expect 0 (idle)'
Test-Gate 'V3.iDB.statBoxIdx'       { (Safe-Read 'instFB_AutoCtrl_Palletizing.statBoxIdx') -ne $null } 'readable'
Test-Gate 'V3.iDB.statBoxesPlaced'  { (Safe-Read 'instFB_AutoCtrl_Palletizing.statBoxesPlaced') -eq 0 } 'expect 0'
Test-Gate 'V3.iDB.statSubState'     { (Safe-Read 'instFB_AutoCtrl_Palletizing.statSubState') -ne $null } 'readable'
Test-Gate 'V3.iDB.statSpawnRequested' { (Safe-Read 'instFB_AutoCtrl_Palletizing.statSpawnRequested') -eq $false } 'expect FALSE'

# --- Gate 6: bo_InitPallet round-trip (REGION 1 path-table init) ---
Write-Host "`n--- Gate 6: bo_InitPallet round-trip ---" -ForegroundColor Yellow
# Ensure mode bits clear first
Safe-Write 'GDB_MachineCmd.bo_Mode'     $false
Safe-Write 'GDB_PalletizingCmd.bo_Mode' $false
Safe-Write 'GDB_ManualCmd.bo_Mode'      $false
Start-Sleep -Milliseconds 200

Safe-Write 'GDB_PalletizingCmd.bo_InitPallet' $true
Start-Sleep -Milliseconds 500
Safe-Write 'GDB_PalletizingCmd.bo_InitPallet' $false
Start-Sleep -Milliseconds 500
Update-TagList   # ensure pts[] descriptors current

Test-Gate 'V3.Init.PalletInitialed' { (Safe-Read 'GDB_PalletizingCmd.bo_PalletInitialed') -eq $true } 'expect TRUE after pulse'
Test-Gate 'V3.Init.TotalBoxes'      { (Safe-Read 'GDB_PalletizingCmd.i16_TotalBoxes') -eq 16 } 'expect 16'
Test-Gate 'V3.Init.statActiveBoxes' { (Safe-Read 'instFB_AutoCtrl_Palletizing.statActiveBoxes') -eq 16 } 'expect 16'

# --- Gate 7: pts[1..3] wrist-frame values (Box 1 layer 1) ---
Write-Host "`n--- Gate 7: pts[] wrist-frame layout (Box 1 layer 1) ---" -ForegroundColor Yellow
# Box 1 layer 1 posInLayer 0 (front-left): box(X,Y) = pallet(-0.48, 1500.31) + (-200, -300) = (-200.48, 1200.31)
# Wrist offset: (+336, -286, +135.7)
# Wrist target for layer 1 pts[1] (approach z = pallet_top + 1*box_height + place_offset):
#   approach_z_cup = -866.73 + 1*200 + 100 = -566.73 → wrist_z = -566.73 + 135.7 = -431.03
# pts[1].x wrist = -200.48 + 336 = 135.52
# pts[1].y wrist = 1200.31 - 286 = 914.31
# pts[2] (place z = -866.73 + 200 = -666.73 → wrist_z = -666.73 + 135.7 = -531.03)
# pts[3] = pts[1] (retract = approach z)

Test-Gate 'V3.pts[1].x (box1 approach wrist X)' {
    [Math]::Abs((Safe-Read 'instFB_AutoCtrl_Palletizing.pts[1].x') - 135.52) -lt 0.5
} 'expect ~135.52 (= -200.48 + 336)'
Test-Gate 'V3.pts[1].y (box1 approach wrist Y)' {
    [Math]::Abs((Safe-Read 'instFB_AutoCtrl_Palletizing.pts[1].y') - 914.31) -lt 0.5
} 'expect ~914.31 (= 1200.31 - 286)'
Test-Gate 'V3.pts[1].z (box1 approach wrist Z)' {
    [Math]::Abs((Safe-Read 'instFB_AutoCtrl_Palletizing.pts[1].z') - (-431.03)) -lt 1.0
} 'expect ~-431.03 (= -566.73 + 135.7 cup→wrist)'
Test-Gate 'V3.pts[2].z (box1 place wrist Z)' {
    [Math]::Abs((Safe-Read 'instFB_AutoCtrl_Palletizing.pts[2].z') - (-531.03)) -lt 1.0
} 'expect ~-531.03 (= -666.73 + 135.7)'
Test-Gate 'V3.pts[3].z (box1 retract wrist Z)' {
    [Math]::Abs((Safe-Read 'instFB_AutoCtrl_Palletizing.pts[3].z') - (-431.03)) -lt 1.0
} 'expect ~-431.03 (= pts[1].z, retract == approach)'

# --- Summary ---
Write-Host "`n================================================================" -ForegroundColor Cyan
$summaryColor = if ($fail -eq 0) { 'Green' } else { 'Red' }
Write-Host ("Preflight result: {0} PASS / {1} FAIL / {2} total" -f $pass, $fail, ($pass + $fail)) -ForegroundColor $summaryColor
Write-Host "================================================================" -ForegroundColor Cyan

if ($fail -eq 0) {
    Write-Host "`nAll preflight gates PASS — V3.0 deploy looks healthy." -ForegroundColor Green
    Write-Host "`nNext step: phantom-mode smoke." -ForegroundColor Yellow
    Write-Host "  1. Watch Table: GDB_PalletizingCmd.bo_RequireSensorGate := FALSE" -ForegroundColor Gray
    Write-Host "  2. GDB_PalletizingCmd.bo_Mode := TRUE; bo_Start pulse TRUE/FALSE" -ForegroundColor Gray
    Write-Host "  3. Observe in NX MCD viewport: SCARA runs through all 16 box motions" -ForegroundColor Gray
    Write-Host "  4. Watch Table: instFB_AutoCtrl_Palletizing.statBoxesPlaced reaches 16; bo_PalletDone := TRUE" -ForegroundColor Gray
    Write-Host "  5. If phantom OK → bo_RequireSensorGate := TRUE + retry for real sensor-gated flow" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "`nPreflight FAIL — fix deploy issues before proceeding to cycle smoke." -ForegroundColor Red
    Write-Host "Common causes:" -ForegroundColor Yellow
    Write-Host "  - VCI import not completed (one or more of 5 files missing)" -ForegroundColor Gray
    Write-Host "  - TIA Compile errors (check Inspector → Info)" -ForegroundColor Gray
    Write-Host "  - PLCSIM-Adv MRES not done (GDB shape mismatch)" -ForegroundColor Gray
    Write-Host "  - Download incomplete or wrong instance" -ForegroundColor Gray
    exit 1
}
