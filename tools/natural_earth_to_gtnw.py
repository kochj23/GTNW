#!/usr/bin/env python3
"""Convert Natural Earth admin-0 countries (public domain) into GTNW's compact map file.

  natural_earth_to_gtnw.py ne_50m_admin_0_countries.geojson Shared/Resources/world_countries.json [tolerance]

Keeps one id per country (ISO_A3, falling back to ADM0_A3), the outer ring of every polygon, simplified with
Douglas-Peucker (default 0.06 degrees) and rounded to 0.01 degrees. Source: https://www.naturalearthdata.com
"""
import json, sys
src, dst = sys.argv[1], sys.argv[2]
tol = float(sys.argv[3]) if len(sys.argv) > 3 else 0.06
d = json.load(open(src))
def dp(pts, eps):
    if len(pts) < 4: return pts
    stack=[(0,len(pts)-1)]; keep=[False]*len(pts); keep[0]=keep[-1]=True
    while stack:
        a,b=stack.pop(); ax,ay=pts[a]; bx,by=pts[b]; dx,dy=bx-ax,by-ay; L=(dx*dx+dy*dy)**0.5 or 1e-12
        best,bi=-1,-1
        for i in range(a+1,b):
            px,py=pts[i]; dist=abs(dy*px-dx*py+bx*ay-by*ax)/L if (dx or dy) else ((px-ax)**2+(py-ay)**2)**0.5
            if dist>best: best,bi=dist,i
        if best>eps: keep[bi]=True; stack+= [(a,bi),(bi,b)]
    return [p for p,k in zip(pts,keep) if k]
out=[]
for f in d['features']:
    p=f['properties']; iso=p.get('ISO_A3')
    if not iso or iso=='-99': iso=p.get('ADM0_A3')
    if p.get('ISO_A3_EH') and p['ISO_A3_EH']!='-99' and (not iso or iso=='-99'): iso=p['ISO_A3_EH']
    g=f['geometry']; polys=g['coordinates'] if g['type']=='MultiPolygon' else [g['coordinates']]
    rings=[]
    for poly in polys:
        outer=poly[0]
        s=dp(outer,tol)
        if len(s)<4:
            # keep tiny islands as small triangles if the country would otherwise vanish
            if len(outer)>=4: s=dp(outer,tol/6)
            if len(s)<4: continue
        flat=[]
        for x,y in s: flat+= [round(x,2), round(y,2)]
        rings.append(flat)
    if rings: out.append({"id":iso,"name":p.get('NAME') or p.get('ADMIN'),"rings":rings})
json.dump({"source":"Natural Earth 1:50m Admin 0 Countries (public domain), simplified for GTNW","countries":out},open(dst,'w'),separators=(',',':'))
print(len(out), "countries")
