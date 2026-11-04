from PIL import Image
import numpy as np, glob, os, sys, json

def flat(path):
    """Open on white: a window shot from Shift-Cmd-4 + Space has a transparent background."""
    im=Image.open(path)
    if im.mode in ('RGBA','LA') or (im.mode=='P' and 'transparency' in im.info):
        im=im.convert('RGBA'); bg=Image.new('RGBA', im.size, (255,255,255,255)); bg.alpha_composite(im); return bg.convert('RGB')
    return im.convert('RGB')

def lum(a): return (0.299*a[:,:,0]+0.587*a[:,:,1]+0.114*a[:,:,2])

def edge_from(line, light=226, run=60):
    """line: 1-D luminance scanned from outside inward. Returns (shadow_start, window_edge) or None."""
    n=len(line)
    nonwhite=np.where(line<252)[0]
    if len(nonwhite)==0: return None
    s=nonwhite[0]
    i=s
    while i<n-run:
        if line[i]>light and (line[i:i+run]>light).all():
            return s,i
        i+=1
    return None

def analyze(path):
    im=flat(path); a=np.array(im).astype(float); L=lum(a); H,W=L.shape
    # border must be white for this to be a shadowed window shot
    border=np.concatenate([L[0,:],L[-1,:],L[:,0],L[:,-1]])
    if border.min()<240: return None
    res={}
    rows=range(H*2//5, H*3//5, max(1,H//40)); cols=range(W*2//5, W*3//5, max(1,W//40))
    def med(vals): 
        vals=[v for v in vals if v]; 
        return (int(np.median([v[0] for v in vals])), int(np.median([v[1] for v in vals]))) if vals else None
    res['L']=med([edge_from(L[y,:]) for y in rows])
    res['R']=med([edge_from(L[y,::-1]) for y in rows])
    res['T']=med([edge_from(L[:,x]) for x in cols])
    res['B']=med([edge_from(L[::-1,x]) for x in cols])
    if any(v is None for v in res.values()): return None
    return dict(W=W,H=H,
        win=(res['L'][1], res['T'][1], W-1-res['R'][1], H-1-res['B'][1]),      # x0,y0,x1,y1 of window
        shadow=dict(L=res['L'][1]-res['L'][0], T=res['T'][1]-res['T'][0], R=res['R'][1]-res['R'][0], B=res['B'][1]-res['B'][0]),
        margin=dict(L=res['L'][1], T=res['T'][1], R=res['R'][1], B=res['B'][1]))

if __name__=='__main__':
    for f in sorted(sys.argv[1:]):
        r=analyze(f)
        name=os.path.basename(f)
        if r is None: print(f"{name:34s} — no white border / not a window shot"); continue
        m=r['margin']; s=r['shadow']
        print(f"{name:34s} {r['W']}x{r['H']}  window {r['win'][2]-r['win'][0]+1}x{r['win'][3]-r['win'][1]+1}  margin L{m['L']} T{m['T']} R{m['R']} B{m['B']}  shadow L{s['L']} T{s['T']} R{s['R']} B{s['B']}")
