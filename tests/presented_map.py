"""Check for the black-map regression in a disposable, known-visible DF world.

--image checks a PNG fixture. --pid briefly shows the selected DF SDL window,
captures only its client area, and restores its previous visibility/focus.
Run desktop captures in the normal desktop session, not an isolated desktop.
The camera must contain terrain in the interior left third (the test worlds do).
"""
from pathlib import Path
import argparse,ctypes,time,json,subprocess,os
from ctypes import wintypes as W
from PIL import Image,ImageGrab
import numpy as np
ap=argparse.ArgumentParser()
ap.add_argument('--image',type=Path)
ap.add_argument('--pid',type=int)
ap.add_argument('--runner',type=Path,help='DFHack runner for the selected disposable instance')
ap.add_argument('--port',type=int,default=5000)
ap.add_argument('--expected-zoom',type=int,choices=[1,2,4],default=2)
ap.add_argument('--out',type=Path,default=Path('work/presented-map.png'))
args=ap.parse_args()
if args.image:
    im=Image.open(args.image).convert('RGB')
else:
    assert args.pid,'A specific disposable-game PID is required'
    assert args.runner,'Pass --runner and --port to verify the live map context before capturing'
    env=os.environ.copy();env['DFHACK_PORT']=str(args.port)
    code="local v=reqscript('gui/worldmap-zoom').view;assert(v and v.camera.zoom=="+str(args.expected_zoom)+",'Open the expected zoom on a supported map first');print('MAP-CONTEXT-VERIFIED')"
    result=subprocess.run([str(args.runner.resolve()),'lua',code],env=env,capture_output=True,text=True,timeout=10)
    assert 'MAP-CONTEXT-VERIFIED' in result.stdout,result.stdout+result.stderr
    u=ctypes.WinDLL('user32',use_last_error=True)
    u.GetForegroundWindow.restype=W.HWND
    for n in ('ShowWindow','SetForegroundWindow','IsWindowVisible'):
        getattr(u,n).argtypes=[W.HWND,ctypes.c_int] if n=='ShowWindow' else [W.HWND]
    u.SetWindowPos.argtypes=[W.HWND,W.HWND,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,W.UINT]
    u.GetWindowThreadProcessId.argtypes=[W.HWND,ctypes.POINTER(W.DWORD)]
    u.GetClientRect.argtypes=[W.HWND,ctypes.POINTER(W.RECT)]
    u.ClientToScreen.argtypes=[W.HWND,ctypes.POINTER(W.POINT)]
    u.GetClassNameW.argtypes=[W.HWND,W.LPWSTR,ctypes.c_int]
    windows=[]
    CALLBACK=ctypes.WINFUNCTYPE(W.BOOL,W.HWND,W.LPARAM)
    def visit(hwnd,param):
        pid=W.DWORD();u.GetWindowThreadProcessId(hwnd,ctypes.byref(pid))
        if pid.value==args.pid:
            name=ctypes.create_unicode_buffer(256);u.GetClassNameW(hwnd,name,256)
            rect=W.RECT();u.GetClientRect(hwnd,ctypes.byref(rect))
            if name.value=='SDL_app':windows.append((hwnd,rect.right*rect.bottom))
        return True
    u.EnumWindows(CALLBACK(visit),0)
    assert windows,'No SDL window owned by the requested test PID'
    hwnd=max(windows,key=lambda p:p[1])[0]
    old=u.GetForegroundWindow();visible=u.IsWindowVisible(hwnd)
    try:
        u.ShowWindow(hwnd,9)
        u.SetWindowPos(hwnd,W.HWND(-1),0,0,0,0,0x13)
        u.SetForegroundWindow(hwnd)
        time.sleep(.25)
        rect=W.RECT();u.GetClientRect(hwnd,ctypes.byref(rect))
        pos=W.POINT(0,0);u.ClientToScreen(hwnd,ctypes.byref(pos))
        im=ImageGrab.grab((pos.x,pos.y,pos.x+rect.right,pos.y+rect.bottom),all_screens=True).convert('RGB')
        args.out.parent.mkdir(parents=True,exist_ok=True);im.save(args.out)
    finally:
        u.SetWindowPos(hwnd,W.HWND(-2),0,0,0,0,0x13)
        if not visible:u.ShowWindow(hwnd,0)
        if old:u.SetForegroundWindow(old)
w,h=im.size
# Interior left/middle map area, away from the DFHack icon and native UI.
pixels=np.array(im)[int(h*.25):int(h*.75),int(w*.1):int(w*.4)]
lit=float(np.mean(np.max(pixels,axis=2)>24))
print(json.dumps({'image':str(args.image or args.out),'width':w,'height':h,'visible_map_fraction':lit}))
assert lit>.2,'BLACK MAP: fewer than 20% of interior map pixels are visible'
