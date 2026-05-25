#!/usr/bin/env python3
"""
RunPalletize.py — One-shot SCARA palletizing trigger via PLCSIM-Adv.

Connects to the DemoScara_ABCDE PLCSIM-Adv instance, prearms the 4 SCARA
axes through the post-LayeredRefactor manual-mode gate, kicks
FB_AutoCtrl_Palletizing V5.2 in PHANTOM or REAL mode, and watches the
16-box / 4-layer cycle run.

This bypasses HMI entirely — useful for sanity-checking the PLC + NX MCD
loop without depending on HMI compile/download. The 4 GDBs touched are
all "stable" paths (per PLC_HANDOFF_2026-05-21_LayeredRefactor §2.4) plus
the post-refactor manual-mode write paths confirmed in
PLC_HANDOFF_2026-05-25_GDB_ControlReplacementPaths.md.

Usage:
    python RunPalletize.py                  # PHANTOM mode (PLC state-machine only)
    python RunPalletize.py --real           # REAL mode (NX MCD provides sensor gates)
    python RunPalletize.py --skip-prearm    # axes assumed already enabled+homed
    python RunPalletize.py --ip 192.168.0.5 # override target IP (default shown)
    python RunPalletize.py --timeout 600    # observation timeout in seconds (default 360)

Dependencies:
    pip install pythonnet
    SIMATIC PLCSIM Advanced V20 (or V8+) installed with the .NET runtime DLL
    NX MCD with co-sim active (REAL mode only)

Exit codes:
    0 = palletizing completed (bo_PalletDone=TRUE or statBoxesPlaced >= 16)
    1 = failure (prearm timeout, stuck phase >60s, observation timeout, or Ctrl-C cleanup)

Author: v9-PM (acting as scara-PLC deputy), 2026-05-25
"""

from __future__ import annotations

import argparse
import signal
import sys
import time
from pathlib import Path

# ----- Siemens API loading (pythonnet) -------------------------------------

try:
    import clr  # pythonnet
except ImportError:
    sys.exit("Missing dependency: pip install pythonnet")

# Candidate DLL locations (first existing one wins).
# The first entry is the proven path on this machine (per v9 harness project.toml).
DLL_CANDIDATES = [
    r"F:\Program Files\Siemens\Automation\PLCSIM_V20\resources\bin\wwwroot\assets\lib\runtime\Siemens.Simatic.Simulation.Runtime.Api.x64.dll",
    r"C:\Program Files\Siemens\Automation\PLCSIM_V20\resources\bin\wwwroot\assets\lib\runtime\Siemens.Simatic.Simulation.Runtime.Api.x64.dll",
    r"C:\Program Files (x86)\Common Files\Siemens\PLCSIMADV\API\8.0\Siemens.Simatic.Simulation.Runtime.Api.x64.dll",
    r"C:\Program Files (x86)\Common Files\Siemens\PLCSIMADV\API\6.0\Siemens.Simatic.Simulation.Runtime.Api.x64.dll",
]

def _load_api() -> str:
    for dll in DLL_CANDIDATES:
        if Path(dll).exists():
            clr.AddReference(dll)
            return dll
    raise FileNotFoundError(
        "Siemens PLCSIM-Adv API DLL not found in any candidate path:\n  "
        + "\n  ".join(DLL_CANDIDATES)
        + "\nEdit DLL_CANDIDATES at top of script to point at your install."
    )

_loaded = _load_api()
print(f"[init] Loaded Siemens API: {_loaded}")

from Siemens.Simatic.Simulation.Runtime import SimulationRuntimeManager, ETagListDetails  # noqa: E402

# ----- Connection wrapper --------------------------------------------------

class Plcsim:
    def __init__(self, target_ip: str):
        self.target_ip = target_ip
        self.inst = None
        self.name = None

    @staticmethod
    def _instance_ips(inst) -> list[str]:
        """Match the proven PowerShell pattern (Plcsim_Robust.ps1 Get-PlcsimInstanceIPs).

        SInstanceInfo (the lightweight registry struct from RegisteredInstanceInfo)
        does NOT carry IP. IPs live on the IInstance returned by CreateInterface,
        under one of several property names depending on API version:
            V20-bundled (v7.0): IPAddress (array) or CommunicationConfiguration.IPAddress
            V8.0 standalone:    ControllerIP (array)
            Older builds:       IP (scalar)
        Returns deduped, non-0.0.0.0 IPs as strings.
        """
        ips: list[str] = []
        for prop in ('ControllerIP', 'IP', 'IPAddress'):
            val = getattr(inst, prop, None)
            if val is None:
                continue
            if isinstance(val, str):
                ips.append(val)
            elif hasattr(val, '__iter__'):
                try:
                    ips.extend(str(x) for x in val)
                except Exception:
                    pass
            else:
                ips.append(str(val))
        # Also try CommunicationConfiguration.IPAddress
        cc = getattr(inst, 'CommunicationConfiguration', None)
        if cc is not None:
            val = getattr(cc, 'IPAddress', None)
            if val is not None:
                if isinstance(val, str):
                    ips.append(val)
                elif hasattr(val, '__iter__'):
                    try:
                        ips.extend(str(x) for x in val)
                    except Exception:
                        pass
                else:
                    ips.append(str(val))
        return sorted({ip for ip in ips if ip and ip != '0.0.0.0'})

    def connect(self, instance_name: str | None = None) -> None:
        """Connect to a registered PLCSIM-Adv instance.

        If instance_name is given, bypass IP discovery and connect by name.
        Otherwise discover by IP match. If no IP match and only one instance
        is registered, use that one (with a warning).
        """
        infos = list(SimulationRuntimeManager.RegisteredInstanceInfo)
        if not infos:
            raise RuntimeError("No PLCSIM-Adv instances registered. Start one in the PLCSIM UI first.")

        # --- Path 1: explicit name override -----------------------------
        if instance_name:
            names = [str(i.Name) for i in infos]
            if instance_name not in names:
                raise RuntimeError(
                    f"Instance '{instance_name}' not registered. Visible: {names}"
                )
            self.name = instance_name
            print(f"[connect] Using explicit instance name: {instance_name}")

        # --- Path 2: IP discovery via per-instance CreateInterface ------
        else:
            print(f"[connect] Discovering instance at IP {self.target_ip} (probing {len(infos)} registered):")
            target_name = None
            for info in infos:
                name = str(info.Name)
                try:
                    tmp = SimulationRuntimeManager.CreateInterface(name)
                    ips = self._instance_ips(tmp)
                    state = getattr(tmp, 'OperatingState', '?')
                    marker = ''
                    if self.target_ip in ips:
                        target_name = name
                        marker = ' <-- TARGET'
                    print(f"  - {name:30s} IPs:[{','.join(ips)}]  State:{state}{marker}")
                except Exception as e:
                    print(f"  - {name:30s} (inspect error: {e})")

            if target_name is None:
                # Fallback — single instance, use it
                if len(infos) == 1:
                    target_name = str(infos[0].Name)
                    print(f"[connect] No IP match for {self.target_ip}, but only 1 instance registered — using: {target_name}")
                else:
                    raise RuntimeError(
                        f"No instance found at IP {self.target_ip} among "
                        f"{[str(i.Name) for i in infos]}. "
                        "Use --name <InstanceName> to bypass IP discovery."
                    )
            self.name = target_name

        # --- Bind ------------------------------------------------------
        self.inst = SimulationRuntimeManager.CreateInterface(self.name)
        # IOMCTDB = include DB symbols; isHMIVisibleOnly=False
        try:
            self.inst.UpdateTagList(ETagListDetails.IOMCTDB, False)
        except Exception:
            self.inst.UpdateTagList()
        state = getattr(self.inst, 'OperatingState', '?')
        print(f"[connect] Bound to {self.name}, CPU state: {state}")

    # --- typed reads ---
    def read_bool(self, tag: str) -> bool:
        return bool(self.inst.ReadBool(tag))
    def read_int(self, tag: str) -> int:
        return int(self.inst.ReadInt16(tag))
    def read_lreal(self, tag: str) -> float:
        return float(self.inst.ReadDouble(tag))

    # --- typed writes ---
    def write_bool(self, tag: str, value: bool) -> None:
        self.inst.WriteBool(tag, bool(value))
    def write_int(self, tag: str, value: int) -> None:
        self.inst.WriteInt16(tag, int(value))
    def write_lreal(self, tag: str, value: float) -> None:
        self.inst.WriteDouble(tag, float(value))

    # --- helpers ---
    def safe_read(self, tag: str, default=None):
        try:
            # Try common types in order; first success wins.
            for reader in (self.inst.ReadBool, self.inst.ReadInt16, self.inst.ReadInt32, self.inst.ReadDouble):
                try:
                    return reader(tag)
                except Exception:
                    continue
        except Exception:
            pass
        return default

    def pulse(self, tag: str, ms: int = 300) -> None:
        self.write_bool(tag, True)
        time.sleep(ms / 1000.0)
        self.write_bool(tag, False)

    def wait_for(self, tag: str, expected, timeout_s: float, reader=None) -> bool:
        reader = reader or self.read_bool
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            try:
                if reader(tag) == expected:
                    return True
            except Exception:
                pass
            time.sleep(0.3)
        return False


# ----- Prearm sequence -----------------------------------------------------

def prearm(plc: Plcsim, enable_timeout_s: float = 10.0, home_timeout_s: float = 10.0) -> None:
    """Enable + home all 4 SCARA axes via the post-LayeredRefactor manual-mode gate.

    Post-2026-05-21: GDB_Control (DB#3) retired. Manual cmd buttons route via
    FB_ManualCtrl REGION 2 OR'd into GDB_AxisCtrl.LKinCtrl.input.bo_enable/home/reset.
    statManualOK gate requires bo_Mode=TRUE + bo_ESTOP_LOCK=TRUE + NOT GDB_MachineCmd.bo_Mode.
    Status flows back through GDB_HMI_Status facade (FB_HMIStatusMirror).
    """
    print("\n=== Prearm ===")

    # Step 1: clear all mode bits + latched pulses
    print("[1/6] Clearing modes + entering manual mode...")
    plc.write_bool('GDB_MachineCmd.bo_Mode',          False)
    plc.write_bool('GDB_PalletizingCmd.bo_Mode',      False)
    plc.write_bool('GDB_ManualCmd.bo_Mode',           False)
    for t in ('GDB_MachineCmd.bo_Start', 'GDB_MachineCmd.bo_Stop', 'GDB_MachineCmd.bo_InitPath',
              'GDB_PalletizingCmd.bo_Start', 'GDB_PalletizingCmd.bo_Stop',
              'GDB_PalletizingCmd.bo_InitPallet'):
        try: plc.write_bool(t, False)
        except Exception: pass
    time.sleep(0.4)
    plc.write_bool('GDB_ManualCmd.bo_ESTOP_LOCK', True)
    plc.write_bool('GDB_ManualCmd.bo_Mode',       True)
    time.sleep(0.2)

    # Step 2: reset pulse
    print("[2/6] Pulsing GDB_ManualCmd.bo_KinReset...")
    plc.write_bool('GDB_ManualCmd.bo_KinEnable', False)
    time.sleep(0.3)
    plc.pulse('GDB_ManualCmd.bo_KinReset', ms=300)
    time.sleep(0.8)

    # Step 3: enable axes
    print(f"[3/6] bo_KinEnable=TRUE, waiting for GDB_HMI_Status.axesEnabled ({enable_timeout_s:.0f}s)...")
    plc.write_bool('GDB_ManualCmd.bo_KinEnable', True)
    if not plc.wait_for('GDB_HMI_Status.axesEnabled', True, enable_timeout_s):
        print("  FAIL: axesEnabled never went TRUE")
        print(f"  Diagnostic: bo_Mode={plc.read_bool('GDB_ManualCmd.bo_Mode')}  "
              f"bo_ESTOP_LOCK={plc.read_bool('GDB_ManualCmd.bo_ESTOP_LOCK')}  "
              f"MachineCmd.bo_Mode={plc.read_bool('GDB_MachineCmd.bo_Mode')}")
        recovering = plc.safe_read('GDB_AxisCtrl.LKinCtrl.output.bo_recovering', default='<n/a>')
        print(f"  LKinCtrl.output.bo_recovering = {recovering}")
        raise RuntimeError("prearm step 3 (enable) failed")
    print("  axesEnabled=TRUE")

    # Step 4: home axes
    print(f"[4/6] bo_KinHome=TRUE, waiting for GDB_HMI_Status.axesHomed ({home_timeout_s:.0f}s)...")
    plc.write_bool('GDB_ManualCmd.bo_KinHome', True)
    if not plc.wait_for('GDB_HMI_Status.axesHomed', True, home_timeout_s):
        print("  FAIL: axesHomed never went TRUE")
        plc.write_bool('GDB_ManualCmd.bo_KinHome', False)
        raise RuntimeError("prearm step 4 (home) failed")
    print("  axesHomed=TRUE")

    # Step 5: release home cmd
    print("[5/6] Releasing bo_KinHome...")
    plc.write_bool('GDB_ManualCmd.bo_KinHome', False)
    time.sleep(0.5)

    # Step 6: verify ready
    print("[6/6] Verifying GDB_HMI_Status.axesReady...")
    if not plc.read_bool('GDB_HMI_Status.axesReady'):
        print(f"  FAIL: axesReady=FALSE  axesEnabled={plc.read_bool('GDB_HMI_Status.axesEnabled')}  "
              f"axesHomed={plc.read_bool('GDB_HMI_Status.axesHomed')}  "
              f"axesError={plc.read_bool('GDB_HMI_Status.axesError')}")
        raise RuntimeError("prearm step 6 (axesReady) failed")
    print("  axesReady=TRUE")
    print("Joint actuals at home: " + ", ".join(
        f"J{n}={plc.read_lreal(f'GDB_HMI_Status.j{n}_actualPos'):.3f}" for n in range(1, 5)
    ))


# ----- Palletizing trigger + observation -----------------------------------

PHASE_NAME = {0: 'IDLE', 10: 'INIT', 20: 'WAIT_BOX', 30: 'FETCH_CMD',
               40: 'MOVE', 50: 'GRIP', 75: 'PAUSED', 100: 'BOX_END',
               200: 'CYCLE_END', 800: 'COMPLETE', 900: 'FAULT'}

def start_palletize(plc: Plcsim, real_mode: bool) -> None:
    print("\n=== Start palletizing ===")
    mode_name = 'REAL (NX-driven sensors)' if real_mode else 'PHANTOM (no sensor gate)'
    print(f"Mode: {mode_name}")
    # Flip mode bits — palletizing wins
    plc.write_bool('GDB_MachineCmd.bo_Mode',       False)
    plc.write_bool('GDB_ManualCmd.bo_Mode',        False)   # release manual mode (axes stay latched-enabled)
    plc.write_bool('GDB_PalletizingCmd.bo_Mode',   True)
    plc.write_bool('GDB_PalletizingCmd.bo_RequireSensorGate', bool(real_mode))
    time.sleep(0.3)

    # Init pallet if not already
    if not plc.read_bool('GDB_PalletizingCmd.bo_PalletInitialed'):
        print("Pallet not initialized; pulsing bo_InitPallet...")
        plc.pulse('GDB_PalletizingCmd.bo_InitPallet', ms=400)
        time.sleep(0.4)

    # Verify pallet is now initialized
    if not plc.read_bool('GDB_PalletizingCmd.bo_PalletInitialed'):
        raise RuntimeError("bo_PalletInitialed stayed FALSE after init pulse — recipe invalid?")
    print("Pallet initialized.")

    # Start pulse (rising edge)
    print("Pulsing bo_Start...")
    plc.write_bool('GDB_PalletizingCmd.bo_Start', False)
    time.sleep(0.3)
    plc.pulse('GDB_PalletizingCmd.bo_Start', ms=350)


def observe(plc: Plcsim, timeout_s: float, sample_s: float = 0.5) -> tuple[str, dict]:
    """Poll cycle progress until terminal state or timeout. Returns (reason, final_state)."""
    print(f"\n=== Observing (timeout {timeout_s:.0f}s) ===")
    print(f"  {'t(s)':>6} {'Box':>4} {'Cmd':>5} {'Placed':>6} {'Belt':>6} {'Grip':>5} {'Rel':>5}  Pack Pall")
    t0 = time.monotonic()
    deadline = t0 + timeout_s
    prev_placed = -1
    prev_cmd    = -1
    stuck_t     = t0
    last_print  = 0.0
    final_reason = 'timeout'
    while time.monotonic() < deadline:
        t = time.monotonic() - t0
        try:
            cmd     = plc.read_int('instFB_AutoCtrl_Palletizing.statCmdPtr')
            placed  = plc.read_int('instFB_AutoCtrl_Palletizing.statBoxesPlaced')
            done    = plc.read_bool('GDB_PalletizingCmd.bo_PalletDone')
            belt    = plc.read_lreal('GDB_MCDData.BeltVelocity')
            grip    = plc.read_bool('GDB_MCDData.bo_gripperGrip')
            rel     = plc.read_bool('GDB_MCDData.bo_gripperRelease')
            pack    = plc.read_bool('GDB_MCDData.PackingSensor')
            pall    = plc.read_bool('GDB_MCDData.PalletizingSensor')
        except Exception as e:
            print(f"  [{t:6.1f}s] read error: {e}")
            time.sleep(sample_s)
            continue

        # Box placed event
        if placed != prev_placed and placed > prev_placed and prev_placed >= 0:
            print(f"  [{t:6.1f}s] Box {placed} placed  -> total {placed}/16")
            stuck_t = time.monotonic()
        prev_placed = placed

        # Stuck-watchdog: cmd ptr not advancing
        if cmd != prev_cmd:
            prev_cmd = cmd
            stuck_t = time.monotonic()

        # Periodic snapshot
        if (t - last_print) >= 2.0:
            print(f"  {t:6.1f} {placed:>4} {cmd:>5} {placed:>6}/16 {belt:6.1f} {str(grip):>5} {str(rel):>5}  {int(pack)}    {int(pall)}")
            last_print = t

        # Terminal — completion
        if done or placed >= 16:
            final_reason = 'pallet_done'
            time.sleep(0.8)
            break
        # Terminal — stuck > 60s
        if time.monotonic() - stuck_t > 60:
            final_reason = f'stuck_cmd_{cmd}_placed_{placed}'
            break

        time.sleep(sample_s)

    # Final snapshot
    final = {
        'reason':       final_reason,
        'statCmdPtr':   plc.read_int('instFB_AutoCtrl_Palletizing.statCmdPtr'),
        'statBoxesPlaced': plc.read_int('instFB_AutoCtrl_Palletizing.statBoxesPlaced'),
        'bo_PalletDone': plc.read_bool('GDB_PalletizingCmd.bo_PalletDone'),
        'BeltVelocity':  plc.read_lreal('GDB_MCDData.BeltVelocity'),
        'elapsed_s':    time.monotonic() - t0,
    }
    return final_reason, final


# ----- Cleanup -------------------------------------------------------------

def cleanup(plc: Plcsim) -> None:
    """Stop pulse + release modes. Idempotent — safe to call multiple times."""
    if plc.inst is None:
        return
    try:
        print("\n=== Cleanup ===")
        plc.pulse('GDB_PalletizingCmd.bo_Stop', ms=350)
        time.sleep(0.3)
        plc.write_bool('GDB_PalletizingCmd.bo_Mode', False)
        plc.write_bool('GDB_PalletizingCmd.bo_RequireSensorGate', True)  # restore default
        plc.write_bool('GDB_ManualCmd.bo_KinEnable', False)
        plc.write_bool('GDB_ManualCmd.bo_Mode',       False)
        print("Cleanup complete: bo_Stop pulsed, modes cleared, sensor gate restored to default TRUE.")
    except Exception as e:
        print(f"Cleanup error (ignored): {e}")


# ----- Main ----------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="One-shot SCARA palletizing trigger via PLCSIM-Adv.")
    ap.add_argument('--ip',            default='192.168.0.5',
                    help='PLCSIM-Adv instance IP (default: %(default)s — SCARA)')
    ap.add_argument('--name',          default=None,
                    help='Bypass IP discovery — connect to this instance name directly '
                         '(e.g. --name DemoScara_ABCDE). Overrides --ip.')
    ap.add_argument('--real',          action='store_true',
                    help='REAL mode (NX MCD provides sensor gates). Default: PHANTOM mode.')
    ap.add_argument('--skip-prearm',   action='store_true',
                    help='Assume axes already enabled+homed; skip prearm sequence.')
    ap.add_argument('--timeout',       type=float, default=360.0,
                    help='Observation timeout in seconds (default: %(default)s)')
    ap.add_argument('--enable-timeout', type=float, default=10.0,
                    help='Prearm enable timeout in seconds (default: %(default)s)')
    ap.add_argument('--home-timeout',  type=float, default=10.0,
                    help='Prearm home timeout in seconds (default: %(default)s)')
    args = ap.parse_args()

    plc = Plcsim(args.ip)

    # Ctrl-C handler — clean stop
    def _sigint(signum, frame):
        print("\n[SIGINT] Caught Ctrl-C; cleaning up...")
        cleanup(plc)
        sys.exit(1)
    signal.signal(signal.SIGINT, _sigint)

    try:
        plc.connect(instance_name=args.name)

        if not args.skip_prearm:
            prearm(plc, enable_timeout_s=args.enable_timeout, home_timeout_s=args.home_timeout)
        else:
            print("[prearm] Skipped (--skip-prearm). Assuming axes ready.")
            if not plc.read_bool('GDB_HMI_Status.axesReady'):
                print("WARNING: axesReady=FALSE — palletizing will likely fail")

        start_palletize(plc, real_mode=args.real)
        reason, final = observe(plc, timeout_s=args.timeout)

        print("\n=== Final state ===")
        for k, v in final.items():
            print(f"  {k:18s} = {v}")

        passed = (reason == 'pallet_done' and final['statBoxesPlaced'] >= 16 and final['bo_PalletDone'])
        if passed:
            print(f"\nPASS — 16 boxes palletized in {final['elapsed_s']:.1f}s")
            cleanup(plc)
            return 0
        else:
            print(f"\nFAIL — reason={reason}, placed={final['statBoxesPlaced']}/16, done={final['bo_PalletDone']}")
            cleanup(plc)
            return 1

    except Exception as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        cleanup(plc)
        return 1


if __name__ == '__main__':
    sys.exit(main())
