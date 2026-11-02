from pathlib import Path
import json
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reports/submission_checks'
OUT.mkdir(parents=True, exist_ok=True)
if not shutil.which('iverilog') or not shutil.which('vvp'):
    raise SystemExit('Put Icarus Verilog (iverilog and vvp) on PATH.')
records = []

def run(name, commands):
    started = time.monotonic()
    chunks = []
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=240)
        chunks.append(result.stdout + result.stderr)
        if result.returncode:
            (OUT / f'{name}.log').write_text('\n'.join(chunks), encoding='utf-8')
            print(''.join(chunks), flush=True)
            raise SystemExit(result.returncode)
    (OUT / f'{name}.log').write_text('\n'.join(chunks), encoding='utf-8')
    records.append({'test': name, 'passed': True, 'elapsed_seconds': round(time.monotonic() - started, 3)})
    print(f'PASS {name}', flush=True)

run('mode3_reference', [[sys.executable, 'sim/verify_multi_reference.py']])
run('mode4_thin', [[sys.executable, 'sim/check_shape_rectfix.py']])
run('mode4_fullhd', [[sys.executable, 'sim/check_shape_rectfix.py', '--fullhd']])
for top, rtl in (
    ('tb_erosion_bounds', ['src/isp/erosion_run_analyzer.v']),
    ('tb_erosion_overlay', ['src/isp/erosion_analysis_overlay.v']),
):
    binary = f'sim/{top}.vvp'
    run(top, [['iverilog', '-g2012', '-s', top, '-o', binary, f'sim/{top}.v', *rtl], ['vvp', binary]])
(OUT / 'summary.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
print('PASS all submission checks; module simulation only, not a new board test', flush=True)
