"""Turn a period photo/painting into a 149x114 EGA-dithered cabinet portrait (Shadow-President-era look):
black/87/171/white greys, red-yellow-red 3px frame, role tag in (87,87,171). Also a 59x48 button.
usage: stylize.py sources.json faces.tsv outdir"""
import json,sys,os,re
from PIL import Image,ImageOps,ImageFilter,ImageDraw,ImageFont,ImageEnhance
PAL=[(0,0,0),(87,87,87),(171,171,171),(255,255,255)]
RED,YEL,TAG=(255,0,0),(255,255,87),(87,87,171)
TAG_BY_ID={"marshall_gen":"GEN"}   # Army Chief of Staff, not the White House one
def tag_for(t,pid=None):
    if pid in TAG_BY_ID: return TAG_BY_ID[pid]
    t=t.lower()
    for k,v in [("vice president","VP"),("president","PRES"),("secretary of state","SofS"),("secretary of defense","SofD"),
                ("secretary of war","SofW"),("secretary of the navy","SofN"),("navy","SofN"),("treasury","SofT"),("attorney general","AG"),
                ("cia","CIA"),("central intelligence","CIA"),("national security","NSA"),("national intelligence","DNI"),
                ("homeland","DHS"),("chief of staff","WHC"),("joint chiefs","JCS"),("general","GEN"),("ambassador","UN"),("u.n.","UN"),
                ("press","PS"),("econom","EA"),("commerce","SofC"),("energy","SofE"),("interior","SofI"),("assistant","ASec")]:
        if k in t: return v
    return "".join(w[0] for w in re.findall(r"[A-Za-z]+",t) if w[0].isupper())[:4] or "ADV"
FONT=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf",15)
def dither(g):
    pal=Image.new("P",(1,1)); pal.putpalette(sum(PAL,())+(0,0,0)*252)
    return g.convert("RGB").quantize(palette=pal,dither=Image.Dither.FLOYDSTEINBERG).convert("RGB")
SPEC={ # mode: (W,H, frame band px, tag font px, button W,H)
  "ega":  (149,114,1,15,59,48),
  "svga": (298,228,2,26,118,96)}
def frame(size,band):
    W,H=size; out=Image.new("RGB",(W,H),RED); d=ImageDraw.Draw(out)
    d.rectangle((band,band,W-1-band,H-1-band),fill=YEL); d.rectangle((2*band,2*band,W-1-2*band,H-1-2*band),fill=RED)
    return out
def svga(g_rgb):
    """SVGA look: 256-colour adaptive palette with Floyd-Steinberg, like a 1990s VESA 640x480/800x600 still."""
    return g_rgb.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.FLOYDSTEINBERG).convert("RGB")
def prep(im,box,mask,size,colour):
    w,h=im.size
    base=im if colour else ImageOps.grayscale(im).convert("RGB")
    if mask and os.path.exists(mask):
        m=Image.open(mask).convert("L").resize((w,h)).filter(ImageFilter.GaussianBlur(max(1,w//300)))
        base=Image.composite(base,Image.new("RGB",(w,h),(0,0,0)),m)
    g=base.crop(box).resize(size,Image.LANCZOS)
    g=ImageOps.autocontrast(g,cutoff=(1,0.5))
    return g
def render(src,face,mask,tag,mode="svga"):
    W,H,band,fpx,BW,BH=SPEC[mode]; inset=3*band; IW,IH=W-2*inset,H-2*inset
    im=Image.open(src); im=ImageOps.exif_transpose(im).convert("RGB"); w,h=im.size
    if face: fx,fy,fw,fh=[v*s for v,s in zip(face,(w,h,w,h))]
    else: fw=w*0.42; fh=fw; fx=(w-fw)/2; fy=h*0.18
    cw=fw*2.35; ch=cw*IH/IW; cx=fx+fw/2; cy=fy+fh*0.62          # face slightly above centre, shoulders in frame
    box=(int(cx-cw/2),int(cy-ch/2),int(cx+cw/2),int(cy+ch/2))   # crop() pads out-of-range with black
    if mode=="ega":
        g=ImageOps.grayscale(prep(im,box,mask,(IW,IH),False))
        g=ImageEnhance.Contrast(g).enhance(1.35); g=g.point(lambda v:int(255*((v/255)**1.15))).filter(ImageFilter.UnsharpMask(1.2,160,2))
        inner=dither(g); binner=dither(g.resize((BW-2*inset,BH-2*inset),Image.LANCZOS))
    else:
        g=prep(im,box,mask,(IW,IH),True)
        g=ImageEnhance.Contrast(g).enhance(1.15).filter(ImageFilter.UnsharpMask(1.0,90,2))
        inner=svga(g); binner=svga(g.resize((BW-2*inset,BH-2*inset),Image.LANCZOS))
    out=frame((W,H),band); out.paste(inner,(inset,inset))
    d=ImageDraw.Draw(out); d.fontmode="1"; font=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf",fpx)
    tw=d.textlength(tag,font=font); d.text((W-2*inset-tw,H-inset-fpx-4*band),tag,font=font,fill=TAG,stroke_width=band,stroke_fill=(0,0,0))
    btn=frame((BW,BH),band); btn.paste(binner,(inset,inset))
    return out,btn
if __name__=="__main__":
    src=json.load(open(sys.argv[1])); faces={}
    for l in open(sys.argv[2]):
        p=l.rstrip("\n").split("\t"); faces[p[0]]=None if p[1]=="NONE" else tuple(map(float,p[1:5]))
    od=sys.argv[3]; os.makedirs(od,exist_ok=True)
    for r in src:
        if not r.get("local") or not os.path.exists(r["local"]): continue
        for mode in ("svga","ega"):
            p,b=render(r["local"],faces.get(r["local"]),r["local"]+".mask.png",tag_for(r["title"],r["id"]),mode)
            os.makedirs(f"{od}/{mode}",exist_ok=True)
            p.save(f"{od}/{mode}/{r['id']}.png",optimize=True); b.save(f"{od}/{mode}/{r['id']}.button.png",optimize=True)
