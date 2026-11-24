"""Art Deco floor plan and installed fittings for P21. Blender +Y faces the approved bust.

The existing Lobby and Operator anchors map to (0,0,3) and (0,15,3).
Doors in the main side walls are open from y=18 to 34. No duplicate wall
covers a leaf opening; both wings continue on the same finished floor.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector
import atelier as a
from atelier import (PI, TAU, box, camera, frame, image_mat, light, local, panel, rod, roof, section,
                     textmesh, turned, wall_box)
from furniture import bench, coffer, fan_banner, pilaster, pot, sconce, torchiere, wall_sections

MAIN_REAR=(0,49,0)
MAIN_FRONT=(0,-13,PI)
MAIN_WEST=(-25,18,PI/2)
MAIN_EAST=(25,18,-PI/2)
FILM_REAR=(-47.5,50,0)
FILM_SIDE=(-70,29.5,PI/2)
GALLERY_REAR=(45,49,0)
GALLERY_EAST=(65,29,-PI/2)
GALLERY_FRONT=(45,9,PI)
PAINTINGS=[]


def paving(name,x0,x1,y0,y1,mat,columns,rows):
    """Flush stone slabs with narrow grout joints and alternating quarter-turn grain."""
    box(name+" subfloor",((x0+x1)/2,(y0+y1)/2,-.34),(x1-x0,y1-y0,.64),"Mortar",.0)
    w=(x1-x0)/columns; d=(y1-y0)/rows
    for i in range(columns):
        for j in range(rows):
            dims=(w-.035,d-.035,.12)
            if (i+j)%2: dims=(d-.035,w-.035,.12)
            box(name+" polished slab",(x0+(i+.5)*w,y0+(j+.5)*d,-.059),dims,mat,.018,PI/2 if (i+j)%2 else 0)


def border(x0,x1,y0,y1,width,z,mat):
    """Rectangular floor inlay with mitred corners made from coplanar nonoverlapping strips."""
    for y in (y0+width/2,y1-width/2):
        box("Floor border",(0.5*(x0+x1),y,z),(x1-x0,width,.012),mat,.0)
    for x in (x0+width/2,x1-width/2):
        box("Floor border",(x,.5*(y0+y1),z),(width,y1-y0-2*width,.012),mat,.0)


def chandelier():
    with roof():
        z=24.75; y=24.3
        for radius,drop in ((6.1,0),(4.95,-.70),(2.85,-1.11)):
            turned("Sunburst chandelier | opal drum",(0,y,z+drop),
                   [(radius-.22,0),(radius,.15),(radius,1.20),(radius-.16,1.33)],"Opal diffuser",96)
            for h in (0,1.2):
                a.rim("Chandelier | spun gilt rim",(0,y,z+drop+h-.035),radius+.075,.16,.15,"Champagne brass")
            for j in range(24 if radius>4 else 16):
                t=TAU*j/(24 if radius>4 else 16)
                x=radius*math.cos(t); yy=y+radius*math.sin(t)
                rod("Chandelier | brass mullion",(x,yy,z+drop+.10),(x,yy,z+drop+1.21),.047,"Patinated bronze",8)
        for j in range(12):
            t=j*TAU/12
            rod("Radial bezel",(.6*math.cos(t),y+.6*math.sin(t),z-.03),(6.08*math.cos(t),y+6.08*math.sin(t),z-.03),.045,"Champagne brass",8)
        for dx in (-3,3):
            rod("Pendant suspension",(dx,y,26.0),(dx,y,28.3),.09,"Patinated bronze",12)
        turned("Chandelier finial",(0,y,23.33),[(.24,0),(.48,.15),(.46,.33)],"Champagne brass",32)


def portal(wall,title):
    # The wall-normal projects into the saloon. Its orientation also sets readable sign text.
    for u in (8-8.57,8+8.57):
        wall_box(wall,"Fluted portal casing",u,.47,7.25,(1.08,1.1,14.5),"Quarter-cut walnut",.12)
        for off in (-.35,.35):
            wall_box(wall,"Jamb bright strip",u+off,1.05,7.25,(.08,.08,14.5),"Champagne brass",.025)
        wall_box(wall,"Door plinth",u,.56,.58,(1.40,1.25,1.15),"Honed pearl marble",.06)
    wall_box(wall,"Signed entrance fascia",8,.48,16.26,(18.50,1.31,3.64),"Quarter-cut walnut",.10)
    wall_box(wall,"Recessed enamel name field",8,1.20,16.27,(17.65,.16,2.82),"Midnight enamel",.055)
    cp=local(wall,8,1.3,16.27)
    frame("Raised brass sign surround",*cp,17.94,3.12,.16,.13,"Champagne brass",wall[2])
    textmesh(title,title,local(wall,8,1.42,16.30),2.00,"Gilt edge",16.75,wall[2])
    for z,w,h,m in ((14.48,18.44,.21,"Gilt edge"),(18.07,18.70,.2,"Champagne brass"),(18.32,18.94,.29,"Fumed oak")):
        wall_box(wall,"Portal cornice",8,.68,z,(w,1.67,h),m,.065)


def main_room():
    section("Main saloon")
    paving("Saloon",-25,25,-13,49,"Honed pearl marble",8,10)
    for inset,w,z,mat in ((2.5,.44,.009,"Midnight enamel"),(3.03,.095,.01,"Champagne brass"),(3.23,.08,.01,"Patinated bronze")):
        border(-25+inset,25-inset,-13+inset,49-inset,w,z,mat)
    # A cross threshold at the two passage entrances and the arrival carpet frame.
    for y in (6.6,11.0,42.55):
        box("Long stone inlay",(0,y,.010),(44.2,.37,.013),"Midnight enamel",.0)
        box("Inlaid brass filament",(0,y+.27,.011),(44.2,.052,.014),"Champagne brass",.0)
    wall_sections(MAIN_REAR,50,28.5,"Parchment limestone")
    wall_sections(MAIN_FRONT,50,28.5,"Parchment limestone")
    wall_sections(MAIN_WEST,62,28.5,"Parchment limestone",(0,16,14.4))
    # For the east wall, local +u points south. A distinct sign coordinate system keeps words legible.
    wall_sections(MAIN_EAST,62,28.5,"Parchment limestone",(-16,0,14.4))
    portal(MAIN_WEST,"Movie Theater")
    portal((25,34,-PI/2),"Art Gallery")
    for i in (-23.5,-16.0,-7.2,7.2,16.0,23.5):
        pilaster(MAIN_REAR,i,28.5,width=1.0 if abs(i)<10 else 1.35)
    for side in (MAIN_WEST,MAIN_EAST):
        for yy in (-10,7.3,38.4,47):
            u=(yy-18)*(1 if side==MAIN_WEST else -1)
            pilaster(side,u,28.5,1.40)
            if yy in (7.3,38.4):sconce(side,u,11.1)
    for xx in (-19.7,19.7):
        sconce(MAIN_REAR,xx,10.7)
    for u in (-11.7,11.7):
        fan_banner(MAIN_REAR,u,15.5,5.6,13.8)
        bench("Waiting banquette",u,46.4,7.8,back=True)
        torchiere(MAIN_REAR,u+(4.9 if u<0 else -4.9))
    for x in (-20.7,20.7):
        pot("Saloon kentia",x,44.8,1.05,36+int(x))
    for x in (-13.4,13.4):
        bench("Arrival bench",x,4.3,6.7,PI/2)
        pot("Entrance dwarf palm",x,9.30,.91,75+int(x))
    # A separate turned plinth supports the P20 foot; retain an independent insertion pivot.
    for name,z,profile,material in (
        ("Marble step",0,[(8.42,0),(8.62,.13),(8.62,.44),(8.4,.65)],"Honed pearl marble"),
        ("Skirt molding",.63,[(8.25,0),(8.45,.09),(8.42,.24),(8.14,.32)],"Patinated bronze"),
        ("Curved marble drum",.91,[(8.04,0),(8.21,.16),(8.21,.82),(8.04,.92)],"Honed pearl marble"),
        ("Continuous brass band",1.79,[(8.04,0),(8.19,.06),(8.19,.30),(8.00,.39)],"Champagne brass"),
        ("Dais cap",2.14,[(7.97,0),(8.11,.12),(8.09,.33),(7.89,.51)],"Honed pearl marble")):
        turned(name,(0,31.5,z),profile,material,96)
    # A raised perimeter cove throws amber reflected light onto the recessed ceiling.
    with roof():
        for w,dist in ((MAIN_FRONT,50),(MAIN_REAR,50),(MAIN_WEST,62),(MAIN_EAST,62)):
            for z,offset,thick,depth,mat in ((26.00,.60,.53,.74,"Fumed oak"),(26.34,.88,.15,1.05,"Gilt edge"),
                                             (26.44,.69,.07,.54,"Amber alabaster"),(26.78,.41,.14,.34,"Champagne brass")):
                wall_box(w,"Continuous cove",0,offset,z,(dist,depth,thick),mat,.035)
        for x in (-17,0,17):
            for yy in (-10.6,46.6):
                light("Cove ceiling reflection",(x,yy,26.4),(x,yy,28.6),370,5.0,(1,.64,.32),'RECTANGLE',1.0)
    # Dado paneling and gilt band are continuous right up to the portal jambs.
    for w,sign in ((MAIN_WEST,1),(MAIN_EAST,-1)):
        for lo,hi in ((-12.8,17.4),(34.65,48.8)):
            for z,depth,ht,mat in ((2.41,.24,2.10,"Honed pearl marble"),(3.48,.36,.20,"Champagne brass"),(3.64,.29,.13,"Fumed oak")):
                wall_box(w,"Stone side dado",sign*((lo+hi)/2-18),.37+depth/2,z,(hi-lo,depth,ht),mat,.03)
    coffer(0,18,50,62,28.5,5,7,True)
    chandelier()
    # Large foil and clerestory bounces give a soft warm studio interior; practicals remain localized.
    light("Lobby | front daylight",(-9,-9,18),(0,31.5,10),3300,18,(1,.94,.85),'RECTANGLE',11)
    light("Lobby | high side key",(-19,16,23),(0,31.5,12),6600,7,(1,.84,.64))
    light("Lobby | cool stone return",(19,11,15),(0,31.5,10),720,14,(.77,.86,1))
    light("Lobby | rear ceiling bounce",(0,44,24),(0,29,8),1300,10,(1,.80,.57))
    for x in (-17,17):
        for y in (4,37):
            light("Lobby | ceiling well",(x,y,26),(x,y+2,.2),1080,4,(1,.84,.66))
    for x in (-11.7,11.7):
        light("Banner wash",(x,43,23),(x,48.4,13),420,3,(1,.81,.56))
    for xx in (-23,23):
        light("Portal wash",(xx*.70,18.0,21),(xx,25,15.8),220,4,(1,.86,.62))


def bolster_mesh():
    """Upholstered back with a rounded shoulder and shallow crown on both sides."""
    from functools import lru_cache
    existing=bpy.data.meshes.get("Cinema | pressed mohair back")
    if existing:return existing
    verts=[]; faces=[]; sides=52
    for y,scale in ((-.34,.84),(-.315,.91),(-.24,.979),(-.12,1),(.12,1),(.23,.975),(.31,.90),(.34,.82)):
        for j in range(sides):
            t=TAU*j/sides; co=math.cos(t);si=math.sin(t)
            x=math.copysign(abs(co)**.50,co)*1.39*scale
            z=math.copysign(abs(si)**.52,si)*1.37*scale
            verts.append((x,y-.10*z,z))
    faces.append(tuple(range(sides)))
    for j in range(7):
        for i in range(sides):
            k=j*sides+i;n=j*sides+(i+1)%sides
            faces.append((k,k+sides,n+sides,n))
    faces.append(tuple(range(8*sides-1,7*sides-1,-1)))
    return a.make_mesh("Cinema | pressed mohair back",verts,faces,"Claret velvet",smooth=True)


def seat(x,y,idx):
    # Seat backs tilt away from the screen. Each unit has an independent wooden shell and padded face.
    label="Cinema chair %02d | "%idx
    box(label+"pedestal",(x,y, .51),(.97,1.16,1.0),"Ebony",.13)
    box(label+"hinge rail",(x,y,1.20),(2.53,2.0,.35),"Quarter-cut walnut",.15)
    box(label+"seat cushion",(x,y+.08,1.54),(2.55,2.04,.51),"Claret velvet",.24)
    a.attach(label+"rolled mohair back",bolster_mesh(),(x,y-1.0,2.52))
    box(label+"walnut lower back rail",(x,y-1.24,1.36),(2.14,.23,.22),"Quarter-cut walnut",.09)
    for dx in (-1.0,1.0):
        rod(label+"brass back boss",(x+dx,y-1.35,1.37),(x+dx,y-1.38,1.37),.085,"Champagne brass",12)
    for sign in (-1,1):
        box(label+"arm cheek",(x+sign*1.44,y+.02,1.24),(.24,1.87,1.91),"Fumed oak",.11)
        box(label+"arm brass cap",(x+sign*1.44,y+.03,2.23),(.32,2.0,.15),"Champagne brass",.06)
        box(label+"armrest",(x+sign*1.44,y+.03,2.33),(.29,1.96,.13),"Claret velvet",.055)
        if sign*x>0:
            box(label+"step lamp",(x+sign*1.44,y-.92,.59),(.15,.05,.22),"Aisle light",.02)


def arch(wall,u,z_center,r,outer,depth,material,tag):
    verts=[]; faces=[]
    for i in range(65):
        t=i*PI/64
        for rr,n in ((r,0),(outer,0),(outer,depth),(r,depth)):
            verts.append(local(wall,u+rr*math.cos(t),n,z_center+rr*math.sin(t)))
    for i in range(64):
        for j in range(4):
            k=i*4+j; nex=i*4+(j+1)%4
            faces.append((k,nex,nex+4,k+4))
    faces.extend([(3,2,1,0),tuple(range(256,260))])
    panel(tag,verts,material,faces)
    for sign in(-1,1):
        wall_box(wall,tag+" return",u+sign*(r+outer)/2,depth/2,z_center/2,(outer-r,depth,z_center),material,.04)


def tv_screen():
    """Slightly convex, rounded-rectangle CRT glass with an inset raster image."""
    x0,y_back,z0=-47.5,45.65,7.68
    # Original 4:3 face, softly curved and rounded at its corners.
    ww,hh=7.84,5.88
    verts=[]; uv=[]; faces=[]; nx,ny=40,32
    for iy in range(ny+1):
        v=iy/ny; yy=(v-.5)*2
        trim=.052*abs(yy)**8
        for ix in range(nx+1):
            u=ix/nx; xx=(u-.5)*2
            x=xx*(1-trim)
            z=yy*(1-.046*abs(xx)**8)
            depth=.29*(1-x*x)*(1-yy*yy)
            verts.append((x0-.72+ww*x/2,y_back-1.69-depth,z0+hh*z/2))
            uv.append((u,v))
            if ix<nx and iy<ny:
                k=iy*(nx+1)+ix; faces.append((k,k+1,k+nx+2,k+nx+1))
    panel("CRT | phosphor glass and aerial image",verts,"Aerial phosphor",faces,uv)
    for side in (-1,1):
        # Bent wire aerials, ball tips and a spun central socket.
        join=(x0+side*.24,y_back,11.38); cap=(x0+side*3.35,y_back+.15,14.40)
        rod("Telescopic aerial",join,cap,.063,"Champagne brass",12,.031)
        turned("Polished antenna tip",cap,[(.082,0),(.090,.073),(.045,.12)],"Gilt edge",16)
    turned("Antenna swivel",(x0,y_back,11.24),[(.55,0),(.49,.17),(.30,.34)],"Patinated bronze",32)
    # Cabinet stands clear of wall, with vent slots and concentric knobs.
    box("Walnut television cabinet",(x0,y_back,z0),(11.22,3.34,7.35),"Fumed oak",.36)
    box("CRT | ebony bezel",(x0-.72,y_back-1.50,z0),(8.42,.43,6.45),"Ebony",.21)
    cp=(x0-.72,y_back-1.70,z0)
    frame("CRT | fine metallic surround",*cp,8.12,6.15,.06,.065,"Patinated bronze")
    for z in (9.51,7.92):
        for radius,n,mat in ((.63,1.69,"Ebony"),(.54,1.81,"Patinated bronze"),(.42,1.96,"Quarter-cut walnut")):
            rod("Channel dial",(x0+4.40,y_back-n,z),(x0+4.40,y_back-n-.16,z),radius,mat,32)
        box("Knob indicator",(x0+4.40,y_back-2.16,z),(.09,.065,.65),"Gilt edge",.025,(0,.65,0))
    box("Speaker inset",(x0+4.42,y_back-1.67,5.90),(1.40,.13,1.83),"Ebony",.10)
    for j in range(10):
        box("Speaker grille slot",(x0+4.42,y_back-1.78,5.11+j*.167),(1.32,.07,.068),"Quarter-cut walnut",.023)
    for dx in (-4.4,4.4):
        box("Television isolator",(x0+dx,y_back,3.88),(.89,1.75,.27),"Ebony",.09)
    box("Console | walnut table",(x0,y_back,.5+3.12),(15.3,5.5,.43),"Quarter-cut walnut",.18)
    box("Console | gold fillet",(x0,y_back,3.41),(15.06,5.31,.12),"Champagne brass",.05)
    for dx in (-6.55,6.55):
        for dy in (-1.96,1.96):
            turned("Console tapered leg",(x0+dx,y_back+dy,0),[(.16,0),(.17,.47),(.26,.54),(.35,3.41)],"Quarter-cut walnut",12)
            turned("Console brass sabot",(x0+dx,y_back+dy,0),[(.18,0),(.18,.43)],"Champagne brass",12)


def theater():
    section("Picture house")
    paving("Cinema",-70,-25,9,50,"Pale terrazzo",7,7)
    wall_sections(FILM_REAR,45,21,"Quarter-cut walnut")
    wall_sections(FILM_SIDE,41,21,"Quarter-cut walnut")
    wall_sections((-47.5,9,PI),45,21,"Quarter-cut walnut")
    # Inward-facing finish on the shared wall with the exact same aperture as the saloon.
    wall_sections((-25.395,29.5,-PI/2),41,21,"Quarter-cut walnut",(-4.5,11.5,14.4),.14)
    for dx in (-15,-9,9,15):
        wall_box(FILM_REAR,"Green velvet panel",dx,.38,8.8,(4.3,.17,13.8),"Teal silk",.085)
        for v in range(-6,7):
            wall_box(FILM_REAR,"Acoustic flute",dx+v*.29,.515,8.8,(.075,.11,13.7),"Midnight enamel",.033)
    arch((-47.5,49.52,0),0,8.30,12.2,13.25,.36,"Ivory lacquer","Proscenium arch")
    arch((-47.5,49.09,0),0,8.30,12.45,12.59,.06,"Champagne brass","Proscenium brass ribbon")
    # Vertical panel boundaries, brass edge lines and the matching period wall ornaments.
    for xx in range(-22,23,3):
        wall_box(FILM_REAR,"Veneer joint",xx,.343,10.5,(.035,.05,20.6),"Fumed oak",0)
    def deco_wall_art(u,film):
        wall=FILM_REAR;z=10.55
        if not film:
            for j in range(16):
                t=TAU*j/16
                rr=2.3 if j%2==0 else 1.61
                base=local(wall,u,.66,z)
                ray=local(wall,u+rr*math.cos(t),.66,z+rr*math.sin(t))
                rod("Sunburst radius",base,ray,.065,"Gilt edge",8,.019)
            rod("Sunburst medallion",local(wall,u,.68,z),local(wall,u,.84,z),.48,"Champagne brass",40)
        else:
            wall_box(wall,"Movie camera plaque",u,.58,z,(4.34,.22,5.1),"Midnight enamel",.10)
            cp=local(wall,u,.74,z); frame("Cinema plaque beading",*cp,4.38,5.14,.12,.09,"Gilt edge")
            rod("Camera spindle",local(wall,u-.57,.78,z+.62),local(wall,u-.57,.86,z+.62),.49,"Gilt edge",32)
            rod("Camera spindle",local(wall,u+.48,.78,z+.70),local(wall,u+.48,.86,z+.70),.55,"Gilt edge",32)
            wall_box(wall,"Camera outline",u,.82,z-.10,(1.52,.10,.75),"Gilt edge",.10)
            for dx in(-.84,.84):
                rod("Camera tripod emblem",local(wall,u,.85,z-.5),local(wall,u+dx,.85,z-1.75),.055,"Gilt edge",8)
    deco_wall_art(-20.7,False);deco_wall_art(20.7,True)
    for xx in (-16.4,16.4):
        sconce(FILM_REAR,xx,9.5,"uplight")
    # Repeated inset wall paneling and a decorative, wordless film-reel medallion.
    for u in (-16,-7,3,13):
        pilaster(FILM_SIDE,u,21,1.05)
        if u!=-16: sconce(FILM_SIDE,u,8.30,"uplight")
    for xx in (-63,-32):
        pot("Cinema parlor palm",xx,46.3,.84,abs(xx))
    x=-47.5
    box("Central teal carpet",(x,28.45,.04),(8.36,38.28,.09),"Petrol moquette",.04)
    for sign in(-1,1):
        box("Carpet | brass border",(x+sign*4.02,28.45,.10),(.10,38.28,.04),"Gilt silk",.0)
        box("Carpet | secondary band",(x+sign*3.81,28.45,.10),(.065,38.28,.04),"Gilt silk",.0)
    idx=0
    for row in range(4):
        y=15.6+row*5.78
        for sign in(-1,1):
            for j in range(3):
                idx+=1
                seat(x+sign*(6.05+3.27*j),y,idx)
    tv_screen()
    coffer(x,29.5,45,41,21,4,4)
    light("Cinema | rear ambient",(-48,12,16),(-47,34,5),2800,15,(1,.87,.78))
    light("Cinema | stage key",(-52,38,16),(-47.5,46,7),1720,6,(1,.82,.61))
    light("Cinema | stage fill",(-37,38,12),(-47.5,46,7),690,5,(.72,.84,.97))
    for xx in (-64,-31):
        light("Column bounce on burgundy", (xx,18,7.2),(xx+(-47.5-xx)*.38,28,2.5),1030,4.2,(1,.77,.65),'RECTANGLE',7.5)
    for xx in (-58,-37):
        light("Warm arch grazing wash",(xx,47,3),(xx,49,15),420,2.2,(1,.67,.40))
    for y in (18,31,42):
        for xx in(-59,-36):
            light("Cinema ceiling lamp",(xx,y,19),(xx,y,1.0),520,3.3,(1,.77,.58))


def painting(wall,u,index,height):
    from hashlib import sha256
    path=a.REF/("portrait-%d.jpeg"%index)
    material="Canvas %02d | supplied portrait"%index
    m=image_mat(material,path,.83)
    img=next(n.image for n in m.node_tree.nodes if n.type=="TEX_IMAGE")
    width=height*img.size[0]/img.size[1]
    z=9.1; group="Portrait %02d"%index
    wall_box(wall,group+" | stretcher",u,.54,z,(width+.42,.39,height+.42),"Fumed oak",.045)
    # Geometry UVs use the complete raster extent; each point is inset from the surrounding molding.
    coords=[local(wall,u+i*width/2,.782,z+j*height/2) for i,j in ((-1,-1),(1,-1),(1,1),(-1,1))]
    panel(group+" | canvas",coords,material,uv=[(0,0),(1,0),(1,1),(0,1)])
    for off,depth,thickness,mat in ((.09,.81,.075,"Gilt edge"),(.27,.86,.16,"Patinated bronze"),
                                    (.54,.89,.23,"Champagne brass"),(.73,.87,.10,"Fumed oak"),(.86,.92,.12,"Gilt edge")):
        cp=local(wall,u,depth,z)
        frame(group+" | frame "+mat,*cp,width+off,height+off,.19,thickness,mat,wall[2])
    # Brass fixture, offset from the framed art. Aim each picture light below its shade.
    top=z+height/2+1.58
    p=lambda dx,n,zz:local(wall,u+dx,n,zz)
    for dx in (-.53,.53):
        rod("Picture lamp | swing arm",p(dx,.40,top-.18),p(dx,1.12,top+.39),.064,"Champagne brass",12)
    rod("Picture lamp | mounting plate",p(0,.35,top+.07),p(0,.62,top+.07),.33,"Champagne brass",28)
    light("Picture lamp | halo",p(0,1.30,top+.48),p(0,.33,top+1.08),63,.52,(1,.69,.37))
    rod("Picture lamp | shade",p(-1.96,1.17,top+.24),p(1.96,1.17,top+.24),.20,"Champagne brass",24)
    rod("Picture lamp | opal slit",p(-1.83,1.21,top+.10),p(1.83,1.21,top+.10),.10,"Amber alabaster",20)
    light("Picture lamp | wall wash",p(0,1.46,top-.082),p(0,.70,z+height*.15),310,2.6,(1,.82,.57),'RECTANGLE',.5)
    eye=local(wall,u,11.8,z)
    cam=camera("A2 | Framed portrait %02d"%index,eye,local(wall,u,.78,z),45,(720,720),max(width+2.25,height+2.0))
    PAINTINGS.append({"portrait":index,"source":str(path.relative_to(a.ROOT)),"source_sha256":sha256(path.read_bytes()).hexdigest(),
                      "raster_px":list(img.size),"canvas":group+" | canvas","material":material,
                      "frame_prefix":group+" | frame","size_studs":[round(width,5),height],
                      "center_blender":list(local(wall,u,.782,z)),"camera":cam.name})


def gallery():
    section("Portrait gallery")
    paving("Gallery",25,65,9,49,"Pale terrazzo",6,6)
    for wall,w in ((GALLERY_REAR,40),(GALLERY_EAST,40),(GALLERY_FRONT,40)):
        wall_sections(wall,w,19.2,"Parchment limestone")
    wall_sections((25.395,29,PI/2),40,19.2,"Parchment limestone",(-11,5,14.4),.14)
    coffer(45,29,40,40,19.2,4,5)
    for y in (11.15,47):
        for x in (26.8,63.2):
            turned("Gallery corner stop",(x,y,.02),[(.23,0),(.24,.25),(.15,.36)],"Champagne brass",20)
    painting(GALLERY_REAR,-9.6,3,10.2)
    painting(GALLERY_REAR,9.5,5,10.2)
    painting(GALLERY_EAST,-10,1,10.2)
    painting(GALLERY_EAST,8.4,4,8.6)
    painting(GALLERY_FRONT,-9.2,2,8.6)
    painting(GALLERY_FRONT,9.1,6,8.6)
    box("Gallery Axminster rug",(45,29,.037),(17.7,10.3,.09),"Petrol moquette",.055,-.23*PI)
    for zoff,mat in ((.13,"Gilt silk"),(.25,"Midnight enamel")):
        # Border strips transform with the rug so their full return remains visible.
        p=(45,29,-.23*PI)
        for u in(-1,1):wall_box(p,"Rug | bound selvedge",u*(8.85-zoff),0,.088,(.08,10.3-zoff*2,.016),mat,0)
        for n in(-1,1):wall_box(p,"Rug | bound selvedge",0,n*(5.15-zoff),.088,(17.7-zoff*2,.08,.016),mat,0)
    bench("Gallery ottoman",45,29,12.8,-.23*PI)
    for x in(33,54):
        for y in(18,39):
            light("Gallery ceiling bounce",(x,y,17),(x,y,1),1420,5.2,(1,.94,.85))
    light("Gallery | entrance daylight",(27,22,13),(53,40,8),2100,11,(.85,.91,1))
    light("Gallery | reverse bounce",(58,39,13),(41,12,8),1400,9,(1,.93,.85))
