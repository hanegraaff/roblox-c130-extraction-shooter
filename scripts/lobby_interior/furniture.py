"""Reusable dimensional fittings for the P21 public rooms. All lengths in studs."""
import math
import random
from atelier import (TAU, PI, Vector, box, rod, turned, panel, frame, local, wall_box, light,
                     make_mesh, attach, materials)


def wall_sections(wall, length, height, lining, opening=None, thickness=.65):
    """Build solid lengths around a true portal. The floor continues through its jambs."""
    intervals=[(-length/2,length/2,0,height)] if opening is None else [
        (-length/2,opening[0],0,height),(opening[1],length/2,0,height),
        (opening[0],opening[1],opening[2],height)]
    for lo,hi,z0,z1 in intervals:
        if hi<=lo: continue
        w=hi-lo
        wall_box(wall,"Masonry shell",(hi+lo)/2,0,(z1+z0)/2,(w,thickness,z1-z0),lining,.035)
        if z0==0:
            for z,depth,h,mat in ((.55,.18,1.10,"Fumed oak"),(1.19,.23,.18,"Quarter-cut walnut"),
                                  (1.31,.24,.055,"Champagne brass")):
                wall_box(wall,"Skirting",(hi+lo)/2,.36+depth/2,z,(w,depth,h),mat)


def pilaster(wall,u,height,width=1.45):
    for z,d,w,h,mat in ((height/2,.57,width,height,"Quarter-cut walnut"),
                         (1.22,.75,width+.3,2.40,"Honed pearl marble"),
                         (2.51,.81,width+.44,.19,"Champagne brass"),
                         (height-.64,.69,width+.20,.85,"Fumed oak"),
                         (height-.14,.81,width+.44,.26,"Champagne brass")):
        wall_box(wall,"Pilaster",u,.37+d/2,z,(w,d,h),mat,.04)
    for off in (-.35,0,.35):
        wall_box(wall,"Pilaster reed",u+off,.97,(height+2)/2,(.074,.075,height-3.5),"Patinated bronze",.025)


def sconce(wall,u,z,fixture="lantern"):
    """Two-tone fluted opal and metal light or theater uplight."""
    p=lambda forward,h:local(wall,u,forward,h)
    wall_box(wall,"Sconce saddle",u,.51,z,(.72,.24,2.6),"Patinated bronze",.09)
    rod("Sconce return",p(.51,z),p(1.08,z),.12,"Champagne brass")
    if fixture=="lantern":
        turned("Sconce opal reeding",p(1.03,z-1.02),[(.28,0),(.32,.13),(.32,1.93),(.28,2.05)],"Amber alabaster",24)
        for h in (-1.09,.94):
            turned("Sconce rim",p(1.03,z+h),[(.33,0),(.37,.10),(.30,.21)],"Champagne brass",24)
        for j in range(6):
            angle=j*TAU/6
            c=Vector(p(1.03,z))+Vector((.323*math.cos(angle),.323*math.sin(angle),0))
            rod("Lantern cage",c+Vector((0,0,-.95)),c+Vector((0,0,.95)),.024,"Patinated bronze",6)
    else:
        turned("Hourglass shaded wall light",p(1.05,z-1.16),
               [(.46,0),(.46,.1),(.16,1.1),(.15,1.27),(.48,2.31),(.48,2.40)],"Champagne brass",32)
        for h in (-1.16,1.25): turned("Sconce warm aperture",p(1.05,z+h),[(.41,0),(.41,.03)],"Amber alabaster",24)
    for dz in (3,-2):
        light("Pool above wall light" if dz>0 else "Pool below wall light",p(1.13,z+(1.40 if dz>0 else -1.31)),
              p(.35,z+dz),185,.49,(1,.64,.35))


def coffer(xm,ym,w,d,h,nx,ny,lightwood=False):
    """Recessed ceiling wells with layered timber or stone moldings and metal pins."""
    from atelier import roof
    b="Ivory lacquer" if lightwood else "Quarter-cut walnut"
    lining="Parchment limestone" if lightwood else "Fumed oak"
    molding="Gilt edge" if lightwood else "Patinated bronze"
    with roof():
        box("Ceiling soffit",(xm,ym,h+.38),(w+.6,d+.6,.76),lining,.03)
        for axis,count,span,dist in ((0,nx,w,d),(1,ny,d,w)):
            for i in range(count+1):
                a=-span/2+span*i/count
                for z,breadth,thick,mat in ((h-.04,.95,.42,b),(h-.31,.70,.19,b),(h-.425,.27,.055,molding)):
                    dim=(breadth,dist+.6,thick) if axis==0 else (dist+.6,breadth,thick)
                    box("Coffer rib",(xm+(a if axis==0 else 0),ym+(a if axis else 0),z),dim,mat,.04)
        for ix in range(nx):
            for iy in range(ny):
                x=xm+(ix+.5-nx/2)*w/nx;y=ym+(iy+.5-ny/2)*d/ny
                turned("Recessed bezel",(x,y,h-.12),[(.32,0),(.39,.045),(.39,.12)],"Champagne brass",24)
                turned("Recessed lamp",(x,y,h-.146),[(.26,0),(.27,.04)],"Opal diffuser",24)
        for yy in (-1,1):
            for z,bre,ht,mat in ((h-.55,.62,.55,b),(h-.89,.86,.19,molding),(h-1.05,.72,.10,b)):
                box("Perimeter crown",(xm,ym+yy*(d/2-.22),z),(w+.25,bre,ht),mat,.04)
        for xx in (-1,1):
            for z,bre,ht,mat in ((h-.55,.62,.55,b),(h-.89,.86,.19,molding),(h-1.05,.72,.10,b)):
                box("Perimeter crown",(xm+xx*(w/2-.22),ym,z),(bre,d,ht),mat,.04)


def bench(name,x,y,length,angle=0,back=False):
    wall=(x,y,angle)
    def piece(tag,u,n,z,w,d,h,mat,b=.05):
        return wall_box(wall,name+" | "+tag,u,n,z,(w,d,h),mat,b)
    piece("rail",0,0,1.18,length-.45,2.45,.40,"Quarter-cut walnut",.09)
    piece("gilt reveal",0,0,1.43,length-.35,2.53,.11,"Champagne brass",.03)
    count=round(length/1.8)
    for i in range(count):
        u=(i+.5-count/2)*(length-.2)/count
        piece("stitched cushion",u,0,1.77,(length-.2)/count-.023,2.60,.62,"Bottle green hide",.17)
        for n in (-.58,.58):
            turned("Bench tuft",local(wall,u,n,2.075),[(.062,0),(.07,.018)],"Patinated bronze",10)
        if back:
            piece("back cushion",u,-1.13,2.69,(length-.2)/count-.03,.46,1.6,"Bottle green hide",.18)
    for u in (-length/2+.59,length/2-.59):
        for n in (-.87,.87):
            turned("Tapered bench foot",local(wall,u,n,.04),[(.11,0),(.11,.36),(.17,.41),(.23,1.16)],"Champagne brass",12)
        if back:piece("back upright",u,-1.19,2.05,.19,.20,2.08,"Quarter-cut walnut")
    if back:
        for side in (-1,1):
            piece("timber arm",side*(length/2-.08),0,2.46,.24,2.22,.22,"Quarter-cut walnut",.10)


def fan_banner(wall,u,z,w,h):
    """Pointed woven pendant with a raised five-ray sunrise device."""
    def flag_face(name,points,forward,material):
        panel(name,[local(wall,u+px,forward,z+py) for px,py in points],material)
    outline=[(-w/2,h/2),(-w/2,-h*.31),(0,-h/2),(w/2,-h*.31),(w/2,h/2)]
    flag_face("Banner | bullion welt",outline,.65,"Gilt silk")
    flag_face("Banner | green face",[(a*.956,b*.977) for a,b in outline],.669,"Teal silk")
    focus=-h*.342
    for fractional in (-.79,-.39,0,.39,.79):
        end_x=w*.48*fractional
        end_z=h*(.21-.22*abs(fractional))
        half=w*.062
        flag_face("Banner | embroidered fan ray",[(0,focus),(end_x+half,end_z),(end_x-half,end_z)],.69,"Gilt silk")
    rod("Banner hanging rail",local(wall,u-w*.56,.60,z+h/2+.03),local(wall,u+w*.56,.60,z+h/2+.03),.12,"Champagne brass",18)


def pot(name,x,y,scale=1,seed=2):
    """Original pinnate fronds. Thin V-folded leaflets make a two-sided silhouette."""
    rng=random.Random(seed)
    def turn(label,profile,material):
        return turned(name+" | "+label,(x,y,.01),[(r*scale,z*scale) for r,z in profile],material,40)
    turn("flared stone urn",[(1.03,0),(1.05,.18),(.91,.27),(1.02,.36),(1.18,2.05),(1.31,2.23),(1.30,2.36),(1.14,2.36)],"Honed pearl marble")
    turn("burnished rim",[(1.24,2.13),(1.33,2.15),(1.33,2.33),(1.23,2.37)],"Champagne brass")
    turn("soil",[(1.11,2.29),(1.11,2.32)],"Soil")
    vsets=[[],[],[]]; fsets=[[],[],[]]
    for j in range(15):
        a=j*2.39996+.23*rng.random()
        span=(1.4+2.1*rng.random())*scale
        rise=(2.1+2.4*rng.random())*scale
        curl=.8+.6*rng.random()
        direct=Vector((math.cos(a),math.sin(a),0));side=Vector((-direct.y,direct.x,0))
        start=Vector((x,y,2.27*scale))+direct*(.28*scale)
        def spine(t):
            return start+direct*(span*t**1.3)+Vector((0,0,rise*(1.95*t-curl*t*t)))
        old=start
        for k in range(1,8):
            pt=spine(k/7)
            rod("Palm rachis",old,pt,.024*scale,"Palm olive",5,r2=.020*scale)
            old=pt
        group=j%3;vs,fs=vsets[group],fsets[group]
        for k in range(13):
            t=.15+k*.062
            le=(.97*math.sin(PI*t)**.7+.13)*scale
            for sign in (-1,1):
                base=spine(t)
                end=base+side*(sign*le)+direct*(le*.52)+Vector((0,0,-le*(.26+.26*t)))
                mid=(base+end)*.5 + Vector((0,0,.12*scale))
                idx=len(vs);wid=scale*.12*(1-.42*t)
                vs.extend([tuple(base),tuple(mid-direct*wid),tuple(mid+Vector((0,0,.08*scale))),
                           tuple(mid+direct*wid),tuple(end)])
                fs.extend([(idx,idx+1,idx+2),(idx,idx+2,idx+3),(idx+1,idx+4,idx+2),(idx+2,idx+4,idx+3)])
    for i,material in enumerate(("Palm forest","Palm jade","Palm olive")):
        panel(name+" | pinnate fronds",vsets[i],material,fsets[i])


def torchiere(wall,u):
    p=lambda z:local(wall,u,2.2,z)
    turned("Reading lamp | weighted foot",p(.02),[(.68,0),(.70,.1),(.42,.2),(.17,.32),(.10,3.80)],"Champagne brass")
    turned("Reading lamp | fluted shade",p(3.65),[(1.08,0),(1.16,.1),(.57,1.02),(.47,1.05)],"Amber alabaster")
    turned("Reading lamp | finial",p(4.68),[(.11,0),(.13,.12),(.055,.28)],"Champagne brass",16)
