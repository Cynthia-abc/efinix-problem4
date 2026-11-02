"""Reproduce Canny verification without touching the original project.

python sim/run_canny_regression.py --suite unit
python sim/run_canny_regression.py --suite hu
python sim/run_canny_regression.py --suite full
python sim/run_canny_regression.py --suite all

Native BRAM tests use the official Efinity model. Long raster/Hu tests use
the checked word-level equivalent in efx_ram10_fast.v (simulation only).
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
RTL = sorted((ROOT/'src/isp/canny').glob('*.v'))
NATIVE = Path(os.environ.get('EFINITY_HOME', 'D:/Efinity/2026.1'))/'sim_models/verilog/efx_ram10.v'
FAST = ROOT/'sim/efx_ram10_fast.v'
OVERLAY = ROOT/'src/isp/color_edge_overlay.v'
HU = [ROOT/'src/isp'/f'{name}.v' for name in (
    'hu_video_adapter', 'hu_roi_pingpong', 'hu_shape_frame', 'hu_component_frame',
    'hu_features', 'hu_serial_arithmetic', 'hu_template_match')]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--suite', choices=('unit', 'hu', 'full', 'fullwhite', 'all'), default='all')
    args = parser.parse_args()
    compiler, runtime = shutil.which('iverilog'), shutil.which('vvp')
    if not compiler or not runtime:
        raise SystemExit('Icarus Verilog and vvp must be on PATH')
    subprocess.run([sys.executable, str(ROOT/'sim/canny_reference.py')], cwd=ROOT, check=True)
    tests = []
    if args.suite in ('unit', 'all'):
        for name in ('tb_gauss_3x3', 'tb_canny_core', 'tb_canny_hysteresis', 'tb_canny_ram_banks'):
            tests.append((name, name, RTL+[NATIVE], []))
        tests.append(('tb_canny_ram_banks', 'tb_canny_ram_banks_fast', RTL+[FAST], []))
        tests.append(('tb_canny_video', 'tb_canny_video', RTL+[OVERLAY,NATIVE], []))
        tests.append(('tb_canny_video', 'tb_canny_video_fullwidth', RTL+[OVERLAY,FAST],
                      [f'-Ptb_canny_video.{k}={v}' for k,v in
                       dict(W=1920,H=16,HT=2200,VT=30,FRAMES=5,H_OFFSET=192,V_OFFSET=2).items()]))
        tests.append(('tb_color_edge_overlay_label', 'tb_color_edge_overlay_label', [OVERLAY], []))
    if args.suite in ('hu', 'all'):
        tests.append(('tb_canny_hu', 'tb_canny_hu', RTL+HU+[OVERLAY,FAST], []))
    if args.suite in ('full', 'all'):
        params = {'W':1920,'H':1080,'HT':2200,'VT':1125,'FRAMES':3,'H_OFFSET':192,'V_OFFSET':41}
        tests.append(('tb_canny_video', 'tb_canny_video_1080p', RTL+[OVERLAY,FAST],
                      [f'-Ptb_canny_video.{k}={v}' for k,v in params.items()]))
    if args.suite in ('fullwhite', 'all'):
        params = dict(W=1920,H=1080,HT=2200,VT=1125,FRAMES=1,H_OFFSET=192,V_OFFSET=41,FLAT_ONLY=1)
        tests.append(('tb_canny_video', 'tb_canny_video_1080p_white', RTL+[OVERLAY,FAST],
                      [f'-Ptb_canny_video.{k}={v}' for k,v in params.items()]))
    records = []
    with (ROOT/f'sim/regression_{args.suite}.log').open('w', encoding='utf-8') as log:
        for top, label, sources, params in tests:
            testbench = ROOT/f'sim/{top}.v'
            output = ROOT/f'sim/{label}.vvp'
            commands = [[compiler,'-g2012','-s',top,*params,'-o',str(output),
                         str(testbench),*map(str,sources)], [runtime,str(output)]]
            started = time.monotonic()
            print(f'Running {label}', flush=True)
            record = {'test':label,'model':'official' if NATIVE in sources else 'word-level' if FAST in sources else 'none',
                      'commands':commands,'files_sha256':{str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p):
                           hashlib.sha256(p.read_bytes()).hexdigest() for p in [testbench,*sources]}}
            for command in commands:
                log.write('COMMAND '+json.dumps(command)+'\n');log.flush()
                result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=1800)
                text = result.stdout+result.stderr
                print(text,end='',flush=True);log.write(text);log.flush()
                if result.returncode:
                    raise SystemExit(result.returncode)
            record.update(passed=True,elapsed_seconds=round(time.monotonic()-started,3))
            records.append(record)
    (ROOT/f'sim/regression_{args.suite}.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    print(f'PASS {len(records)} {args.suite} regressions')


if __name__=='__main__':
    main()
