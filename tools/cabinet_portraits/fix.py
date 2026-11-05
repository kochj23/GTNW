import json,sys,re,urllib.request,urllib.parse,time,os
UA={"User-Agent":"GTNW-portrait-builder/1.1 (https://github.com/kochj23/GTNW)"}
def api(base,**p):
    p.update(format="json",formatversion=2)
    for i in range(5):
        try: return json.load(urllib.request.urlopen(urllib.request.Request(base+"?"+urllib.parse.urlencode(p),headers=UA),timeout=30))
        except Exception: time.sleep(4*(i+1))
    return {}
WP="https://en.wikipedia.org/w/api.php"; CM="https://commons.wikimedia.org/w/api.php"
BAD=re.compile(r"letter|memorand|NARA - 19|cabinet meeting|sworn|L to R|from left|addresses|remarks|inaugurat|address\.png|"
               r"Seaborg|Andrus|Schlesinger|Hillary|Louisa|Quentin|Alexander LOC|Hinckley|Goldwater|Jackie Robinson|Burbeck|Crowninshie|Southard|Dulles, Secr|Collier",re.I)
FILE={"ratcliffe":"File:Official Portrait of CIA Director John Ratcliffe (cropped).webp","cutler_nsa":"File:Robert Cutler (cropped).jpg","t_roosevelt_asst":"File:Theodore Roosevelt, Asst Secretary of The Navy, 1898.png","t_roosevelt":"File:Theodore Roosevelt by the Pach Bros (4x5 cropped) (3).jpg"}  # explicit Commons files when the lead image is the wrong era/person
PAGE_FIX={"cutler_nsa":"Robert Cutler (government official)"}
src=json.load(open(sys.argv[1])); od=sys.argv[2]
for r in src:
    f=r.get("file") or ""
    if not BAD.search(f) and r["id"] not in FILE: continue
    page=PAGE_FIX.get(r["id"],r["page"])
    p=api(WP,action="query",titles=page,prop="pageimages",piprop="name",redirects=1)
    pg=(p.get("query",{}).get("pages") or [{}])[0]; lead=pg.get("pageimage")
    t=FILE.get(r["id"]) or ("File:"+lead if lead else None)
    if not t: print("NOLEAD",r["id"],page); r.pop("local",None); continue
    ii=api(CM,action="query",titles=t,prop="imageinfo",iiprop="url|extmetadata|mime",iiurlwidth=700)
    ip=((ii.get("query",{}).get("pages") or [{}])[0].get("imageinfo") or [None])[0]
    if not ip:
        ii=api(WP,action="query",titles=t,prop="imageinfo",iiprop="url|extmetadata|mime",iiurlwidth=700)
        ip=((ii.get("query",{}).get("pages") or [{}])[0].get("imageinfo") or [None])[0]
    m=(ip or {}).get("extmetadata",{}); g=lambda k:re.sub("<[^>]+>","",m.get(k,{}).get("value","")).strip()
    lic=g("LicenseShortName")
    if not ip or not lic.lower().startswith(("public domain","pd","cc0")):
        print("NOT-PD",r["id"],t,lic); r.pop("local",None); r["file"]=None; continue
    for old in [r.get("local")]:
        if old and os.path.exists(old): os.remove(old)
    ext=".png" if ip.get("mime")=="image/png" else ".jpg"; dst=f"{od}/{r['id']}{ext}"
    open(dst,"wb").write(urllib.request.urlopen(urllib.request.Request(ip.get("thumburl") or ip["url"],headers=UA),timeout=60).read())
    r.update(file=t,descurl=ip.get("descriptionurl"),license=lic,artist=g("Artist")[:160],date=g("DateTimeOriginal")[:40],local=dst,fallback=True)
    print("FIXED",r["id"],"->",t[5:70]); time.sleep(0.3)
json.dump(src,open(sys.argv[1],"w"),indent=1)
