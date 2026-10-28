"""Exercise the legacy black-map case and corrected composition on SDL backends.

Use the installed game's SDL2.dll in a normal desktop session. Direct3D must
be available: a software-only run cannot establish this regression is fixed.
The probe creates hidden synthetic windows and does not load a game/save.
"""
import ctypes as C,json,argparse
from pathlib import Path
import numpy as np
from PIL import Image
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--sdl-dll',type=Path,required=True)
ap.add_argument('--zoom',type=int,choices=[2,4],default=2)
ap.add_argument('--evidence',type=Path,default=Path('work/sdl-backends'))
args=ap.parse_args();args.evidence.mkdir(parents=True,exist_ok=True)
dll=C.CDLL(str(args.sdl_dll.resolve()))
P=C.c_void_p;I=C.c_int;U=C.c_uint
class Rect(C.Structure):_fields_=[('x',I),('y',I),('w',I),('h',I)]
class Info(C.Structure):_fields_=[('name',C.c_char_p),('flags',U),('count',U),('formats',U*16),('maxw',I),('maxh',I)]
def bind(name,args,ret=I):
    fn=getattr(dll,name);fn.argtypes=args;fn.restype=ret;return fn
init=bind('SDL_Init',[U]);quit=bind('SDL_Quit',[],None)
newwin=bind('SDL_CreateWindow',[C.c_char_p,I,I,I,I,U],P)
destroywin=bind('SDL_DestroyWindow',[P],None)
num=bind('SDL_GetNumRenderDrivers',[]);driver=bind('SDL_GetRenderDriverInfo',[I,C.POINTER(Info)])
newrenderer=bind('SDL_CreateRenderer',[P,I,U],P);destroyrenderer=bind('SDL_DestroyRenderer',[P],None)
getinfo=bind('SDL_GetRendererInfo',[P,C.POINTER(Info)])
setcolor=bind('SDL_SetRenderDrawColor',[P,C.c_ubyte,C.c_ubyte,C.c_ubyte,C.c_ubyte])
clear=bind('SDL_RenderClear',[P]);viewport=bind('SDL_RenderSetViewport',[P,C.POINTER(Rect)])
clip=bind('SDL_RenderSetClipRect',[P,C.POINTER(Rect)]);scale=bind('SDL_RenderSetScale',[P,C.c_float,C.c_float])
fill=bind('SDL_RenderFillRect',[P,C.POINTER(Rect)])
read=bind('SDL_RenderReadPixels',[P,C.POINTER(Rect),U,P,I]);error=bind('SDL_GetError',[],C.c_char_p)
texture=bind('SDL_CreateTexture',[P,U,I,I,I],P);destroytexture=bind('SDL_DestroyTexture',[P],None)
target=bind('SDL_SetRenderTarget',[P,P]);copy=bind('SDL_RenderCopy',[P,P,C.POINTER(Rect),C.POINTER(Rect)])
blend=bind('SDL_SetTextureBlendMode',[P,I]);texture_scale=bind('SDL_SetTextureScaleMode',[P,I])
assert init(0x20)==0,error()
records=[]
try:
    for index in range(num()):
        info=Info();driver(index,C.byref(info));name=info.name.decode()
        win=newwin(b'World map viewport probe',0,0,512,512,8)
        renderer=newrenderer(win,index,0)
        if not renderer:
            records.append({'backend':name,'unavailable':error().decode()});destroywin(win);continue
        try:
            for negative in (False,True):
                scale(renderer,1,1);viewport(renderer,None);clip(renderer,None)
                setcolor(renderer,0,0,0,255);clear(renderer)
                if negative:
                    viewport(renderer,C.byref(Rect(-256,-256,768,768)))
                    clip(renderer,C.byref(Rect(256,256,512,512)));scale(renderer,2,2)
                setcolor(renderer,60,160,80,255);fill(renderer,C.byref(Rect(0,0,512,512)))
                scale(renderer,1,1);viewport(renderer,None);clip(renderer,None)
                pixels=np.zeros((512,512,4),dtype=np.uint8)
                rc=read(renderer,None,0x16762004,pixels.ctypes.data,512*4)
                lit=float(np.mean(pixels[:,:,:3].max(axis=2)>24))
                record={'backend':name,'negative_viewport':negative,'read_result':rc,'visible_fraction':lit,'error':error().decode()}
                print(json.dumps(record),flush=True);records.append(record)
                Image.fromarray(pixels[:,:,:3]).save(args.evidence/f'legacy-{name}-{negative}.png')
            tex=texture(renderer,0x16362004,2,512,512)
            assert tex,error()
            try:
                assert blend(tex,0)==0 and texture_scale(tex,0)==0
                assert target(renderer,tex)==0
                viewport(renderer,None);clip(renderer,None);scale(renderer,1,1)
                setcolor(renderer,0,0,0,255);clear(renderer)
                crop=512//args.zoom;offset=(512-crop)//2
                clip(renderer,C.byref(Rect(offset,offset,crop,crop)))
                setcolor(renderer,60,160,80,255);fill(renderer,C.byref(Rect(0,0,512,512)))
                assert target(renderer,None)==0
                viewport(renderer,None);clip(renderer,None);scale(renderer,1,1)
                setcolor(renderer,0,0,0,255);clear(renderer)
                assert copy(renderer,tex,C.byref(Rect(offset,offset,crop,crop)),C.byref(Rect(0,0,512,512)))==0
                pixels=np.zeros((512,512,4),dtype=np.uint8)
                assert read(renderer,None,0x16762004,pixels.ctypes.data,512*4)==0
                lit=float(np.mean(pixels[:,:,:3].max(axis=2)>24))
                record={'backend':name,'target_composition':True,'zoom':args.zoom,'visible_fraction':lit}
                print(json.dumps(record),flush=True);records.append(record)
                assert lit==1,record
            finally:destroytexture(tex)
        finally:destroyrenderer(renderer);destroywin(win)
finally:quit()
assert any(r.get('backend')=='direct3d' and r.get('target_composition') and r.get('visible_fraction')==1 for r in records), 'Direct3D must be exercised in a normal Windows desktop session'
(args.evidence/'results.json').write_text(json.dumps(records,indent=2))
