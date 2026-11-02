"""Run new runtime-mode tests; preserve logs and checked input hashes."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    compiler, runtime = shutil.which("iverilog"), shutil.which("vvp")
    if not compiler or not runtime:
        raise SystemExit("Icarus Verilog and vvp must be on PATH")
    records = []
    for top, rtl, log_name in (
        ("tb_uart_modes", ["src/uart_rx.v", "src/display_mode_ctrl.v", "src/uart_mode_reply.v"], "uart_modes.log"),
        ("tb_display_modes", ["src/isp/color_edge_overlay.v"], "display_modes.log"),
    ):
        sources = [f"sim/{top}.v", *rtl]
        output = f"sim/{top}.vvp"
        commands = [[compiler, "-g2012", "-s", top, "-o", output, *sources], [runtime, output]]
        with (ROOT / "sim" / log_name).open("w", encoding="utf-8") as log:
            for command in commands:
                result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
                log.write("COMMAND " + json.dumps(command) + "\n" + result.stdout + result.stderr)
                print(result.stdout + result.stderr, end="")
                if result.returncode:
                    raise SystemExit(result.returncode)
        records.append(dict(test=top, passed=True, commands=commands,
                            files_sha256={name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
                                          for name in sources}))
    result = subprocess.run([sys.executable, "host/mode_panel.py", "--self-test"], cwd=ROOT,
                            capture_output=True, text=True, timeout=30)
    (ROOT / "host/panel_selftest.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    print(result.stdout + result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    records.append(dict(test="panel_loopback", passed=True,
                        hardware_test=False,
                        files_sha256={"host/mode_panel.py": hashlib.sha256(
                            (ROOT/"host/mode_panel.py").read_bytes()).hexdigest()}))
    (ROOT / "sim/regression_modes.json").write_text(json.dumps(records, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
