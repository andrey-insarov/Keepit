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
def white_edge(line, run=20):
    """Scan from outside in: shadow, then the window's own light-grey border, then a white interior for `run` px."""
    n=len(line); nonwhite=np.where(line<252)[0]
    if len(nonwhite)==0: return None
    s=int(nonwhite[0])
    for i in range(s, min(n-run-1, s+400)):
        if line[i]<235 and (line[i+1:i+1+run]>=245).all(): return i+1
    return None
def alert_box(im):
    """A white alert on a white background (region shot): the border ring is the edge, not a long light run."""
    L=lum(np.array(im).astype(float)); H,W=L.shape
    def med(vals):
        vals=[v for v in vals if v is not None]
        return int(np.median(vals)) if len(vals)>=3 else None
    rows=range(H*2//5, H*3//5, max(1,H//40)); cols=range(W*2//5, W*3//5, max(1,W//40))
    l=med([white_edge(L[y,:]) for y in rows]); r=med([white_edge(L[y,::-1]) for y in rows])
    t=med([white_edge(L[:,x]) for x in cols]); b=med([white_edge(L[::-1,x]) for x in cols])
    if None in (l,r,t,b): return None
    return (l, t, W-1-r, H-1-b)
def normalize(src, dst):
    box=opaque_box(src)
    if not box:
        # Two detectors for flat shots: the window one (long light runs) and the white-alert one (border
        # ring). A sheet on a grey window satisfies both; the larger box is the whole window.
        r=analyze(src); ab=alert_box(flat(src))
        area=lambda b:(b[2]-b[0])*(b[3]-b[1])
        cands=[b for b in ([r['win']] if r else [])+([ab] if ab else [])]
        assert cands, src
        best=max(cands,key=area)
        if ab and best==ab: box=ab
        x0,y0,x1,y1=best
    else: x0,y0,x1,y1=box
    im=flat(src); L=lum(np.array(im).astype(float))
    if not box:
        tops=[t for t in (top_edge(L,x0+dx) for dx in (250,300,400,500,600)) if t is not None]
        if tops: y0=int(np.median(tops))
    W=x1-x0+1+M['L']+M['R']; H=y1-y0+1+M['T']+M['B']
    out=Image.new('RGB',(W,H),(255,255,255)); out.paste(im,(M['L']-x0, M['T']-y0)); out.save(dst, optimize=True)
    return (x1-x0+1,y1-y0+1)
if __name__=='__main__':
    print(normalize(sys.argv[1], sys.argv[2]))
