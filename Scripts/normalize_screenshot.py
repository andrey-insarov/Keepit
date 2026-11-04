"""Normalize a window screenshot (white background, macOS shadow) to fixed margins around the window.
Usage: normalize.py SRC DST  — margins at 2x: left/right 76, top 40, bottom 112."""
from PIL import Image
import numpy as np, sys
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); from _winbox import analyze, lum, flat
M=dict(L=76,T=40,R=76,B=112)
def top_edge(L, x):
    col=L[:,x]; dark=np.where(col<=245)[0]
    if len(dark)==0: return None
    s=dark[0]; d=np.diff(col[s:s+40]); j=np.where(d>=8)[0]
    return s + (int(j[0])+1 if len(j) else 0)
def opaque_box(src):
    """A window shot from Shift-Cmd-4 + Space: the window is the fully opaque part, the shadow is translucent."""
    im=Image.open(src)
    if im.mode!='RGBA': return None
    a=np.array(im)[:,:,3]
    if a.min()==255: return None
    ys,xs=np.where(a==255)
    return (int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max()))
def normalize(src, dst):
    box=opaque_box(src)
    if box: x0,y0,x1,y1=box
    else:
        r=analyze(src); assert r, src
        x0,y0,x1,y1=r['win']
    im=flat(src); L=lum(np.array(im).astype(float))
    if not box:
        tops=[t for t in (top_edge(L,x0+dx) for dx in (250,300,400,500,600)) if t is not None]
        if tops: y0=int(np.median(tops))
    W=x1-x0+1+M['L']+M['R']; H=y1-y0+1+M['T']+M['B']
    out=Image.new('RGB',(W,H),(255,255,255)); out.paste(im,(M['L']-x0, M['T']-y0)); out.save(dst, optimize=True)
    return (x1-x0+1,y1-y0+1)
if __name__=='__main__':
    print(normalize(sys.argv[1], sys.argv[2]))
