"""Independent integer-array reference; no RTL/window/BRAM code reuse.

The reference models the documented bounded hysteresis, not exact flood-fill.
Only standard Python is needed. Run from the project root.
"""
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]


def process(image, high=64, low=24):
    h, w = len(image), len(image[0])
    g, m, d, n, e = [[[0]*w for _ in range(h)] for _ in range(5)]
    for y in range(2, h):
        for x in range(2, w):
            g[y][x] = sum(image[y-2+j][x-2+i]*((1, 2, 1)[j])*((1, 2, 1)[i])
                          for j in range(3) for i in range(3)) >> 4
    for y in range(2, h):
        for x in range(2, w):
            a = [g[y-2+j][x-2:x+1] for j in range(3)]
            gx = a[0][2]+2*a[1][2]+a[2][2]-a[0][0]-2*a[1][0]-a[2][0]
            gy = a[2][0]+2*a[2][1]+a[2][2]-a[0][0]-2*a[0][1]-a[0][2]
            ax, ay = abs(gx), abs(gy)
            m[y][x] = (ax+ay)//2
            d[y][x] = 0 if ay*256 <= ax*106 else 2 if ax*256 <= ay*106 else 1 if gx*gy >= 0 else 3
    for y in range(2, h):
        for x in range(2, w):
            cy, cx = y-1, x-1
            dy, dx = ((0, 1), (1, 1), (1, 0), (1, -1))[d[cy][cx]]
            center = m[cy][cx]
            n[y][x] = center if center >= m[cy-dy][cx-dx] and center >= m[cy+dy][cx+dx] else 0
    e = hysteresis(n, high, low)
    return g, m, d, n, e


def hysteresis(n, high=64, low=24):
    h, w = len(n), len(n[0])
    e = [[0]*w for _ in range(h)]
    strong = [[v >= max(1, high) and v != 0 for v in row] for row in n]
    candidate = [[v >= min(low, max(1, high)) and v != 0 for v in row] for row in n]
    accepted = [[False]*w for _ in range(h)]
    for y in range(2, h):
        for x in range(2, w):
            cy, cx = y-1, x-1
            seed = any(strong[j][i] for j in range(y-2, y+1) for i in range(x-2, x+1))
            prior = accepted[cy][cx-1] or any(accepted[cy-1][i] for i in range(cx-1, cx+2))
            accepted[cy][cx] = strong[cy][cx] or candidate[cy][cx] and (seed or prior)
            e[y][x] = int(accepted[cy][cx])
    return e


def main():
    w, h = 40, 30
    rng = random.Random(1977)
    images = []
    images.append([[0]*w for _ in range(h)])
    images.append([[255]*w for _ in range(h)])
    images.append([[220 if 9 <= x < 31 and 8 <= y < 22 else 20 for x in range(w)] for y in range(h)])
    images.append([[220 if (x-20)**2+(y-15)**2 < 9**2 else 20 for x in range(w)] for y in range(h)])
    images.append([[(x*7+y*13) % 256 for x in range(w)] for y in range(h)])
    images.append([[rng.randrange(256) for x in range(w)] for y in range(h)])
    images.append([[255 if (x//4+y//4) % 2 else 0 for x in range(w)] for y in range(h)])
    images.append([[220 if abs(x-y-4) <= 3 else 20 for x in range(w)] for y in range(h)])
    target = ROOT/'sim/canny_vectors'
    target.mkdir(exist_ok=True)
    accum = {key: [] for key in ('input', 'gauss', 'mag', 'dir', 'nms', 'edge')}
    for image in images:
        for key, a in zip(accum, (image, *process(image))):
            accum[key].extend(v for row in a for v in row)
    for key, values in accum.items():
        (target/f'{key}.hex').write_text(''.join(f'{v:03x}\n' for v in values), encoding='ascii')
    print(f'Generated {len(images)} independent {w}x{h} reference frames')
    cases=[]
    for number in range(10):
        a=[[0]*40 for _ in range(16)]
        if number in (1, 2, 3, 6, 8, 9):
            for x in range(7,31): a[6][x]=40
        if number in (2, 8, 9): a[6][6]=100
        if number==3: a[6][31]=100
        if number==4:
            a[4][10]=100
            for y in range(5,14): a[y][10]=40
        if number==5:
            a[4][10]=100
            for y in range(5,14): a[y][y+6]=40
        if number==7: a[6][12]=1
        high,low=(0,0) if number==7 else (64,999) if number==8 else (64,24)
        expected=hysteresis(a,high,low)
        if number in (0,1,6): assert not any(map(any,expected)), 'isolated weak must be suppressed'
        if number==2: assert sum(map(sum,expected))==25, 'forward weak chain must survive'
        if number==3: assert sum(map(sum,expected))==2, 'bounded reverse reach must be explicit'
        if number==4: assert sum(map(sum,expected))==10, 'vertical weak chain'
        if number==5: assert sum(map(sum,expected))==10, 'diagonal weak chain'
        cases.append((a,expected,high,low))
    data=[];expected=[];highs=[];lows=[]
    for number,(a,e,high,low) in enumerate(cases):
        data.extend(v for row in a for v in row)
        expected.extend(v for row in e for v in row)
        highs.extend(1023 if number==9 and i>100 else high for i in range(640))
        lows.extend(1023 if number==9 and i>100 else low for i in range(640))
    for key,values in [('hyst_input',data),('hyst_edge',expected),('hyst_high',highs),('hyst_low',lows)]:
        (target/f'{key}.hex').write_text(''.join(f'{v:03x}\n' for v in values),encoding='ascii')
    print('Generated 10 directed hysteresis frames, including seed-free/reverse/diagonal/threshold-change cases')
    # Independent spatial reference for the actual padded/cropped video wrapper.
    video=[[220 if 10<x<30 and 7<y<22 else 20 for x in range(40)] for y in range(30)]
    padded=[row+[0]*4 for row in video]+[[0]*44 for _ in range(4)]
    video_edge=process(padded)[-1]
    (target/'video_edge.hex').write_text(''.join(f'{(video_edge[y+4][x+4] if 4<=x<36 and 4<=y<26 else 0):03x}\n'
        for y in range(30) for x in range(40)),encoding='ascii')


if __name__ == '__main__':
    main()
