from pathlib import Path
import random,subprocess,json
W,H=16,12
rng=random.Random(71128)
patterns=[]
patterns.append([[0]*W for _ in range(H)])
a=[[0]*W for _ in range(H)]
for y in range(1,5):
 for x in range(1,6):
  if x in (1,5) or y in (1,4): a[y][x]=3
for y in range(7,10):
 for x in range(10,15): a[y][x]=2
patterns.append(a)
patterns.append([[1]*W for _ in range(H)])
patterns.append([[2 if (x+y)%2==0 else 0 for x in range(W)] for y in range(H)])
# Late merge of roots; split and rejoin; nested overlapping boxes; border walks.
a=[[0]*W for _ in range(H)]
for y in range(8): a[y][0]=3;a[y][5]=4;a[y][10]=5
for x in range(11): a[8][x]=2
patterns.append(a)
a=[[0]*W for _ in range(H)]
for y in range(H):
 for x in range(W):
  if x in (0,W-1) or y in (0,H-1): a[y][x]=1
for y in range(4,8):
 for x in range(5,10):a[y][x]=4
patterns.append(a)
a=[[0]*W for _ in range(H)];a[0][0]=10;a[0][15]=9;a[11][15]=8;a[11][0]=7
patterns.append(a)
# Long open edge, branch, diagonal, and empty after a populated frame.
a=[[0]*W for _ in range(H)]
for x in range(2,14):a[6][x]=6
for y in range(2,10):a[y][8]=3
patterns.append(a)
patterns.append([[0]*W for _ in range(H)])
for n in range(50):
 p=rng.choice([0.08,0.2,0.35,0.6,0.9])
 patterns.append([[rng.randrange(1,17) if rng.random()<p else 0 for x in range(W)] for y in range(H)])

def components(a):
 seen=set();out=[]
 for y in range(H):
  for x in range(W):
   if not a[y][x] or (x,y) in seen:continue
   todo=[(x,y)];seen.add((x,y));pts=[]
   while todo:
    u,v=todo.pop();pts.append((u,v))
    for dv in (-1,0,1):
     for du in (-1,0,1):
      q=(u+du,v+dv)
      if 0<=q[0]<W and 0<=q[1]<H and a[q[1]][q[0]] and q not in seen:seen.add(q);todo.append(q)
   count=sum(a[v][u] for u,v in pts)
   x0=min(u for u,v in pts);x1=max(u for u,v in pts);y0=min(v for u,v in pts);y1=max(v for u,v in pts)
   out.append(dict(count=count,x0=x0,x1=x1,y0=y0,y1=y1,seed=(x,y),points=set(pts)))
 return sorted(out,key=lambda c:(-c['count'],c['seed'][1],c['seed'][0]))[:3]
D=[(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1)]
def walk(c):
 pts=c['points']; start=min(pts,key=lambda p:(p[1],p[0]));cur=start;first=None;back=(cur[0]-1,cur[1]);steps=0
 while steps<=1000:
  bd=D.index((back[0]-cur[0],back[1]-cur[1]));found=False
  for off in range(1,9):
   di=(bd+off)%8;dd=D[di];n=(cur[0]+dd[0],cur[1]+dd[1])
   if n not in pts:continue
   if first is not None and cur==start and n==first:return steps,0
   if steps>=1000:return steps,2
   if first is None:first=n
   prev=D[(di-1)%8];back=(cur[0]+prev[0],cur[1]+prev[1]);cur=n;steps+=1;found=True;break
  if not found:return steps,1
 raise AssertionError('walk loop')
expected=[]
for a in patterns:
 c=components(a)
 for x in c:
  x['steps'],x['status']=walk(x);bw=x['x1']-x['x0']+1;bh=x['y1']-x['y0']+1
  x['aspect']=min(65535,max(bw,bh)*1000//min(bw,bh))
 expected.append(c)
Path('sim/multi_weights.hex').write_text('\n'.join(f'{v:02x}' for a in patterns for row in a for v in row))
bench='''`timescale 1ns/1ps
module tb_multi_reference;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,gv=0;reg [4:0] weight=0;reg [3:0] gx=0,gy=0;
wire fv,done,err,busy;wire [1:0] idx,status;wire [31:0] edges,steps,cycles;wire [3:0] x0,x1,y0,y1;wire [15:0] aspect;
erosion_run_analyzer #(.W(16),.H(12),.LB(8),.MIN_EDGES(1),.MAX_WALK(1000)) dut(
.clk(clk),.rst_n(rst_n),.grid_valid(gv),.grid_weight(weight),.grid_x(gx),.grid_y(gy),
.feature_valid(fv),.feature_index(idx),.feature_edges(edges),.feature_x0(x0),.feature_x1(x1),.feature_y0(y0),.feature_y1(y1),
.feature_aspect(aspect),.feature_steps(steps),.feature_walk_status(status),.analysis_done(done),.analysis_error(err),.busy(busy),.processing_cycles(cycles));
reg [4:0] samples[0:NUM*192-1];integer f,x,y,timeout;
always @(posedge clk) if(fv) $display("R %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",f,idx,edges,x0,x1,y0,y1,aspect,steps,status);
initial begin
$readmemh("sim/multi_weights.hex",samples);
repeat(3) @(negedge clk);rst_n=1;
for(f=0;f<NUM;f=f+1) begin
 for(y=0;y<12;y=y+1) for(x=0;x<16;x=x+1) begin
  @(negedge clk);gv=1;gx=x;gy=y;weight=samples[f*192+y*16+x];
  @(negedge clk);gv=0;repeat(3) @(negedge clk);
 end
 timeout=0;while(!done && timeout<150000) begin @(negedge clk);timeout=timeout+1;end
 if(!done || err) begin $display("FAIL f=%0d state=%0d err=%b",f,dut.state,err);$fatal;end
 $display("DONE %0d %0d",f,cycles);
 repeat(5) @(negedge clk);
end
$display("PASS RTL frames=NUM");$finish;
end
endmodule
'''.replace('NUM',str(len(patterns)))
Path('sim/tb_multi_reference.v').write_text(bench)
cmd=['iverilog','-g2012','-s','tb_multi_reference','-o','sim/tb_multi_reference.vvp','sim/tb_multi_reference.v','src/isp/erosion_run_analyzer.v']
subprocess.run(cmd,check=True)
r=subprocess.run(['vvp','sim/tb_multi_reference.vvp'],capture_output=True,text=True,timeout=120)
Path('sim/multi_reference.log').write_text(r.stdout+r.stderr)
assert r.returncode==0,r.stdout[-2500:]
actual={n:[] for n in range(len(patterns))}
for line in r.stdout.splitlines():
 if line.startswith('R '):
  vals=list(map(int,line.split()[1:]));f,idx,count,x0,x1,y0,y1,aspect,steps,status=vals
  actual[f].append(dict(count=count,x0=x0,x1=x1,y0=y0,y1=y1,aspect=aspect,steps=steps,status=status))
for f,ecs in enumerate(expected):
 ex=[{k:c[k] for k in ('count','x0','x1','y0','y1','aspect','steps','status')} for c in ecs]
 if ex!=actual[f]:
  print('MISMATCH frame',f,'expected',ex,'actual',actual[f]);raise SystemExit(1)
print('PASS independent flood-fill and Moore reference:',len(patterns),'frames,',sum(map(len,expected)),'records')
Path('sim/multi_reference_summary.json').write_text(json.dumps(dict(frames=len(patterns),records=sum(map(len,expected)),result='PASS'),indent=2))
