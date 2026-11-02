"""Generate independent, one-pixel raster edges and exercise the RTL."""
from pathlib import Path
import math
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'mode4_rectfix_20261029' / 'fixtures'
OUT.mkdir(parents=True, exist_ok=True)
fullhd = '--fullhd' in sys.argv
W, H = (1920,1080) if fullhd else (192,128)

def line(pixels, x0, y0, x1, y1, gaps=False):
    steps = max(abs(x1-x0), abs(y1-y0))
    for i in range(steps+1):
        if gaps and i % 19 in (8, 9):
            continue
        x = round(x0+(x1-x0)*i/steps)
        y = round(y0+(y1-y0)*i/steps)
        pixels[y*W+x] = 1

def rectangle(x0, y0, x1, y1, skew=0, gaps=False):
    p = [0]*(W*H)
    points = [(x0+skew,y0), (x1,y0+skew), (x1-skew,y1), (x0,y1-skew)]
    for a,b in zip(points,points[1:]+points[:1]):
        line(p,*a,*b,gaps=gaps)
    return p

def circle(cx,cy,r):
    p = [0]*(W*H)
    for i in range(4096):
        a=2*math.pi*i/4096
        p[round(cy+r*math.sin(a))*W+round(cx+r*math.cos(a))]=1
    return p

cases = []
for off in range(4):
    cases.append((f'rect_phase{off}',rectangle(44+off,28+off,140+off,96+off),2))
cases += [('rect_square',rectangle(50,20,138,108),2),
          ('rect_gaps',rectangle(44,28,140,96,gaps=True),2),
          ('rect_skew',rectangle(40,20,148,108,skew=8),2),
          ('rect_skew_gaps',rectangle(40,20,148,108,skew=8,gaps=True),2),
          ('circle',circle(96,64,40),1),
          ('circle_small',circle(96,64,26),1),
          ('empty',[0]*(W*H),0)]
extra=[]
if fullhd:
    def outside_clutter(p):
        line(p,30,30,1850,30)
        line(p,30,30,30,1030)
        line(p,300,400,400,700)
        return p
    cases=[('fullhd_rect',outside_clutter(rectangle(705,355,1201,723)),2),
           ('fullhd_skew',outside_clutter(rectangle(705,315,1201,763,skew=40)),2),
           ('fullhd_circle',outside_clutter(circle(960,540,190)),1),
           ('fullhd_empty_roi',outside_clutter([0]*(W*H)),0)]
    extra=['-Ptb_shape_simple_thin.W=1920','-Ptb_shape_simple_thin.H=1080',
           '-Ptb_shape_simple_thin.B=16','-Ptb_shape_simple_thin.RX0=560',
           '-Ptb_shape_simple_thin.RX1=1359','-Ptb_shape_simple_thin.RY0=240',
           '-Ptb_shape_simple_thin.RY1=839']
rtl = next((arg for arg in sys.argv[1:] if not arg.startswith('--')), 'src/isp/shape_simple_recognizer.v')
binary = OUT/('fullhd.vvp' if fullhd else 'thin.vvp')
subprocess.run(['iverilog','-g2012','-s','tb_shape_simple_thin',*extra,'-o',str(binary),
                'sim/tb_shape_simple_thin.v',rtl],cwd=ROOT,check=True)
failed=[]
for name,pixels,expected in cases:
    path=OUT/(name+'.mem')
    path.write_text(''.join(f'{p}\n' for p in pixels),encoding='ascii')
    result=subprocess.run(['vvp',str(binary),f'+fixture={path.as_posix()}',f'+expected={expected}'],
                          cwd=ROOT,capture_output=True,text=True)
    print(name+': '+result.stdout.strip(),flush=True)
    if result.returncode: failed.append(name)
print(f'{len(cases)-len(failed)}/{len(cases)} PASS; failures={failed}')
sys.exit(bool(failed))
