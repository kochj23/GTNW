import csv,json,re,sys,time,urllib.parse,urllib.request,os
UA={"User-Agent":"GTNW-portrait-builder/1.1 (https://github.com/kochj23/GTNW)"}
WP="https://en.wikipedia.org/w/api.php"; CM="https://commons.wikimedia.org/w/api.php"
def api(base,**p):
    p.update(format="json",formatversion=2)
    for i in range(5):
        try: return json.load(urllib.request.urlopen(urllib.request.Request(base+"?"+urllib.parse.urlencode(p),headers=UA),timeout=30))
        except Exception: time.sleep(4*(i+1))
    return {}
PAGE={"wright":"Chris Wright (businessman)","brown":"Charles Q. Brown Jr.","waltz":"Mike Waltz","vance":"JD Vance","cutler_nsa":"Robert Cutler (government official)","webster_cia":"William H. Webster","knox":"Henry Knox",
 "seward":"William H. Seward","seward_cont":"William H. Seward","lansing":"Robert Lansing","casey":"William J. Casey",
 "simon":"William E. Simon","snyder":"John Wesley Snyder","dillon":"C. Douglas Dillon","brown_secdef":"Harold Brown (Secretary of Defense)",
 "burns_cia":"William J. Burns (diplomat)","wilson_secdef":"Charles Erwin Wilson","clark_ag":"Tom C. Clark","cohen":"William Cohen",
 "baker":"James Baker","baker_reagan":"James Baker","rubin":"Robert Rubin","brady":"Nicholas F. Brady","hay":"John Hay",
 "root":"Elihu Root","fish":"Hamilton Fish","webster":"Daniel Webster","clay":"Henry Clay","gallatin":"Albert Gallatin","pickering":"Timothy Pickering",
 "humphrey_treasury":"George M. Humphrey","fowler":"Henry H. Fowler","connally":"John Connally","kellogg":"Frank B. Kellogg","hull":"Cordell Hull"}
def clean(n):
    n=re.sub(r"^(Gen\.|General|Adm\.|Dr\.)\s+","",n); n=re.sub(r"\s*'[^']+'\s*"," ",n); return re.sub(r"\s+"," ",n).strip()
def yrs(s):
    m=[int(x) for x in re.findall(r"\b(1[6-9]\d\d|20\d\d)\b",s or "")]; return m
OK_LIC=("public domain","pd","cc0")
def meta(titles):
    out={}
    for i in range(0,len(titles),20):
        r=api(CM,action="query",titles="|".join(titles[i:i+20]),prop="imageinfo",iiprop="url|extmetadata|size|mime",iiurlwidth=700)
        for p in r.get("query",{}).get("pages",[]):
            ii=(p.get("imageinfo") or [None])[0]
            if ii: out[p["title"]]=ii
    return out
rows=list(csv.reader(open(sys.argv[1]),delimiter="\t")); out=sys.argv[2]; res=[]; done=set()
for adm,ys,pid,name,title in rows:
    if pid in done: continue
    done.add(pid); nm=clean(name); y0,y1=(yrs(ys)+[None,None])[:2]; y1=y1 or y0
    page=PAGE.get(pid,nm)
    p=api(WP,action="query",titles=page,prop="pageimages|description|pageprops",piprop="name",redirects=1)
    pg=(p.get("query",{}).get("pages") or [{}])[0]
    if "disambiguation" in (pg.get("pageprops") or {}): print("DISAMBIG",pid,page,file=sys.stderr)
    page=pg.get("title",page); lead=pg.get("pageimage"); last=nm.split()[-1].lower().replace(".","")
    cands=set(["File:"+lead] if lead else [])
    for q in (f"{nm} {y0}", f"{nm} {title}", f"{nm} portrait", f"{nm} {(y0+y1)//2}"):
        r=api(CM,action="query",list="search",srsearch=q,srnamespace=6,srlimit=12)
        cands|={h["title"] for h in r.get("query",{}).get("search",[]) if last in h["title"].lower()}
    md=meta(sorted(cands)); best=None
    for t,ii in md.items():
        m=ii.get("extmetadata",{}); g=lambda k:re.sub("<[^>]+>","",m.get(k,{}).get("value","")).strip()
        lic=g("LicenseShortName").lower()
        if not lic.startswith(OK_LIC) or ii.get("mime") not in ("image/jpeg","image/png","image/tiff"): continue
        w,h=ii.get("width",0),ii.get("height",0)
        if w<200 or h<200 or w>h*1.3: continue
        dy=yrs(g("DateTimeOriginal")) or yrs(t)
        tgt=(y0+y1)/2 if y0 else None
        if dy and tgt: sc=min(abs(dy[0]-y0),abs(dy[0]-y1)) if not (y0<=dy[0]<=y1) else 0
        else: sc=8
        if t=="File:"+(lead or ""): sc-=3
        if re.search(r"official|portrait",t,re.I): sc-=1.5
        if re.search(r"signature|grave|statue|house|stamp|coin|bill|cartoon|map|tomb|memorial|\bwith\b|and |family|wife",t,re.I): sc+=30
        if best is None or sc<best[0]: best=(sc,t,ii,g("LicenseShortName"),g("Artist")[:160],g("DateTimeOriginal")[:40])
    rec=dict(admin=adm,years=ys,id=pid,name=name,title=title,page=page,desc=pg.get("description"))
    if best:
        sc,t,ii,lic,art,dt=best; url=ii.get("thumburl") or ii["url"]
        ext=".png" if ii["mime"]=="image/png" else ".jpg"; dst=f"{out}/{pid}{ext}"
        try: open(dst,"wb").write(urllib.request.urlopen(urllib.request.Request(url,headers=UA),timeout=60).read())
        except Exception as e: rec["err"]=str(e)
        rec.update(file=t,descurl=ii.get("descriptionurl"),license=lic,artist=art,date=dt,score=sc,local=dst)
    res.append(rec); print(pid,"|",page,"|",rec.get("file"),"|",rec.get("date"),file=sys.stderr); time.sleep(0.2)
json.dump(res,open(out+"/../sources.json","w"),indent=1)
