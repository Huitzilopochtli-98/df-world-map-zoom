"""Compare live native 1x/selected-scale map captures and measure the renderer path.

Run on a disposable DF instance with World Map Zoom open. Does not click maps,
embark, issue orders, or save. Requires Pillow and numpy.
"""
from pathlib import Path
import argparse,json,os,subprocess,time
from PIL import Image
import numpy as np

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--runner',type=Path,required=True)
ap.add_argument('--port',type=int,default=5000)
ap.add_argument('--zoom',type=int,choices=[2,4],default=2)
ap.add_argument('--evidence',type=Path,default=Path('evidence/rendering'))
ap.add_argument('--scratch',type=Path,default=Path('work/native-captures'))
args=ap.parse_args()
runner=args.runner.resolve();dest=args.evidence.resolve();scratch=args.scratch.resolve()
dest.mkdir(parents=True,exist_ok=True);scratch.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env['DFHACK_PORT']=str(args.port)

def lua(code):
    r=subprocess.run([str(runner),'lua',code],env=env,capture_output=True,text=True,timeout=30)
    if r.returncode or 'stack traceback' in r.stdout+r.stderr: raise RuntimeError(r.stdout+r.stderr)
    return r.stdout

def expr(code):return json.loads(lua('print(require("json").encode('+code+'))'))
def status():return expr('require("plugins.worldmap-zoom-render").status()')

def snapshot(name):
    path=scratch/(name+'-'+str(time.time_ns())+'.ppm')
    lua('require("plugins.worldmap-zoom-render").capture('+json.dumps(path.as_posix())+')')
    deadline=time.monotonic()+8
    while time.monotonic()<deadline:
        s=status()
        if s['last_capture']==path.as_posix():break
        if s.get('capture_error'):raise RuntimeError(s['capture_error'])
        time.sleep(.05)
    else:raise TimeoutError(name)
    im=Image.open(path);im.save(dest/(name+'.png'))
    return np.array(im),s

meta=expr('''(function()local v=reqscript('gui/worldmap-zoom').view;assert(v,'Open World Map Zoom first');
local r=df.global.enabler.renderer;local p=v.context.port;
return {context=v.context.id,cols=p.dim_x,rows=p.dim_y,mx=r.origin_x+p.top_left_corner_x,
my=r.origin_y+p.top_left_corner_y,tx=r.dispx_z,ty=r.dispy_z,ox=r.origin_x,oy=r.origin_y,
width=r.cur_w,height=r.cur_h} end)()''')
prefix=('fortress' if meta['context']==2 else 'embark')+f"-{meta['width']}x{meta['height']}"

def ui_mask():
    info=expr('''(function()local v=reqscript('gui/worldmap-zoom').view;local g=df.global.gps;
local b=require('plugins.worldmap-zoom-render');local rows={};for y=0,g.dimy-1 do local row={};
for x=0,g.dimx-1 do row[#row+1]=b.ui_hit(x,y) and '1' or '0' end;rows[#rows+1]=table.concat(row) end;
local f=v.subviews.controls.frame_rect;return {rows=rows,panel={f.x1,f.y1,f.x2,f.y2}} end)()''')
    mask=np.zeros((meta['height'],meta['width']),dtype=bool)
    for y,row in enumerate(info['rows']):
        for x,c in enumerate(row):
            if c=='1':
                x1=meta['ox']+x*meta['tx'];y1=meta['oy']+y*meta['ty']
                mask[max(0,y1):y1+meta['ty'],max(0,x1):x1+meta['tx']]=True
    panel=info['panel'];x1=meta['ox']+panel[0]*meta['tx'];y1=meta['oy']+panel[1]*meta['ty']
    x2=meta['ox']+(panel[2]+1)*meta['tx'];y2=meta['oy']+(panel[3]+1)*meta['ty']
    panel_mask=np.zeros_like(mask)
    panel_mask[max(0,y1-3):min(meta['height'],y2+3),max(0,x1-3):min(meta['width'],x2+3)]=True
    return mask|panel_mask,mask,panel_mask

lua('''local v=reqscript('gui/worldmap-zoom').view;v._qa_render=v.render;v._qa_idle=v.onIdle;
local function neutral()local g=df.global.gps;g.mouse_x=-1;g.mouse_y=-1;g.precise_mouse_x=-1;g.precise_mouse_y=-1 end;
v.render=function(self,dc)neutral();self._qa_render(self,dc)end;
v.onIdle=function(self)neutral();self._qa_idle(self)end;v:reset()''')
try:
    original,_=snapshot(prefix+'-original')
    # Align the native camera for the image/timing comparison. Normal UI zoom
    # can clamp at world edges; comparing different cameras is not an oracle.
    lua('''local v=reqscript('gui/worldmap-zoom').view;v:zoom(__ZOOM__);v.camera.zoom=1;v:sync();
v._qa_cx,v._qa_cy=v.camera.cx,v.camera.cy'''.replace('__ZOOM__',str(args.zoom)))
    one,_=snapshot(prefix+'-1x');ui1,native1,panel1=ui_mask()
    lua('local v=reqscript("gui/worldmap-zoom").view;v.camera.zoom=__ZOOM__;v:sync()'.replace('__ZOOM__',str(args.zoom)))
    two,_=snapshot(prefix+f'-{args.zoom}x');ui2,native2,panel2=ui_mask()
    visible_ui=native1 & native2 & ~panel1 & ~panel2
    assert visible_ui.any()
    ui_match=float(np.mean(np.all(one==two,axis=2)[visible_ui]))
    offsets=expr('''(function()local c=reqscript('gui/worldmap-zoom').view.camera;
local _,_,x,y=c:native_binding();return {x=math.floor(x*16+.5),y=math.floor(y*16+.5)}end)()''')
    yy,xx=np.indices(one.shape[:2]);mx,my=meta['mx'],meta['my']
    sx=mx+offsets['x']+(xx-mx)//args.zoom;sy=my+offsets['y']+(yy-my)//args.zoom
    valid=(xx>=mx)&(yy>=my)&(xx<mx+meta['cols']*16)&(yy<my+meta['rows']*16)
    valid&=(sx>=0)&(sx<meta['width'])&(sy>=0)&(sy<meta['height'])
    sx=sx.clip(0,meta['width']-1);sy=sy.clip(0,meta['height']-1)
    valid&=~ui2 & ~ui1[sy,sx]
    expected=one[sy,sx]
    error=np.abs(expected.astype(float)-two.astype(float)).mean(axis=2)
    match=float(np.mean(error[valid]<1));median=float(np.median(error[valid]))
    for _ in range(20):lua('local v=reqscript("gui/worldmap-zoom").view;v:zoom(1);v:zoom(__ZOOM__)'.replace('__ZOOM__',str(args.zoom)))
    lua('reqscript("gui/worldmap-zoom").view:reset()')
    restored,_=snapshot(prefix+'-reset')
    reset_match=float(np.mean(np.all(original==restored,axis=2)))
    profiles={};frame_profiles={}
    for z in (1,args.zoom):
        lua(f'local v=reqscript("gui/worldmap-zoom").view;v.camera.cx,v.camera.cy=v._qa_cx,v._qa_cy;v.camera.zoom={z};v:sync();require("plugins.worldmap-zoom-render").profile(true)')
        deadline=time.monotonic()+30
        while min(status()['profile_samples'],status()['frame_profile_samples'])<256:
            if time.monotonic()>deadline:raise TimeoutError('profile')
            time.sleep(.25)
        samples=expr('require("plugins.worldmap-zoom-render").profile(false)')
        profiles[str(z)]={'samples_us':samples,'p50_us':float(np.percentile(samples,50)),
                         'p95_us':float(np.percentile(samples,95)),'p99_us':float(np.percentile(samples,99))}
        samples=expr('require("plugins.worldmap-zoom-render").frame_profile()')
        frame_profiles[str(z)]={'samples_us':samples,'p50_us':float(np.percentile(samples,50)),
                               'p95_us':float(np.percentile(samples,95)),'p99_us':float(np.percentile(samples,99))}
    # Observe completion of a new 2x native draw, after old 2x work has drained.
    lua('''local v=reqscript('gui/worldmap-zoom').view;v._qa_latencies={};v._qa_latency_done=false;
local b=require('plugins.worldmap-zoom-render');local function trial()
v:zoom(1);dfhack.timeout(3,'frames',function()local start=dfhack.getTickCount();v:zoom(__ZOOM__);local generation=b.status().camera_generation;
local function poll()local s=b.status();local elapsed=dfhack.getTickCount()-start;
if s.presented_generation>=generation or elapsed>1000 then
table.insert(v._qa_latencies,elapsed);if #v._qa_latencies<8 then trial()else v._qa_latency_done=true end
else dfhack.timeout(1,'frames',poll)end end;dfhack.timeout(1,'frames',poll)end)end;trial()'''.replace('__ZOOM__',str(args.zoom)))
    deadline=time.monotonic()+20
    while not expr('reqscript("gui/worldmap-zoom").view._qa_latency_done'):
        if time.monotonic()>deadline:raise TimeoutError('response samples')
        time.sleep(.1)
    response=expr('reqscript("gui/worldmap-zoom").view._qa_latencies')
    final=status()
    result={'zoom':args.zoom,'context':prefix,'display':meta,'map_pixels_compared':int(valid.sum()),'pixel_match_fraction':match,
            'median_channel_error':median,'reset_exact_fraction':reset_match,'profiles':profiles,
            'native_ui_pixels_compared':int(visible_ui.sum()),'native_ui_match_fraction':ui_match,
            'p95_added_us':profiles[str(args.zoom)]['p95_us']-profiles['1']['p95_us'],
            'frame_profiles':frame_profiles,
            'frame_p95_added_us':frame_profiles[str(args.zoom)]['p95_us']-frame_profiles['1']['p95_us'],
            'draw_completion_response_ms':response,'renderer_status':final}
    (dest/(prefix+'-results.json')).write_text(json.dumps(result,indent=2))
    assert match>.99,result
    assert ui_match>.98,result
    assert reset_match>.99,result
    assert final['restore_errors']==0,result
    # Target switching submits queued GPU work inside the map hook. Compare
    # complete renderer frames (through Present) to account for that work at
    # both scales, instead of comparing two different queue-flush boundaries.
    assert result['frame_p95_added_us']<2000,result
    assert max(response)<=100,result
    print(json.dumps({k:v for k,v in result.items() if k not in ('profiles','frame_profiles','renderer_status')},indent=2))
finally:
    lua('''local v=reqscript('gui/worldmap-zoom').view;if v then
v.render=v._qa_render;v.onIdle=v._qa_idle;v:reset();v:zoom(__ZOOM__)end'''.replace('__ZOOM__',str(args.zoom)))
