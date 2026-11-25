"""Original raster artwork for the recovery terminal and the numbered case plate."""
import math

import bpy
import numpy as np
from meshwork import MATERIALS
from surfaces import write_png

# Five-bit rows of an original dot-matrix instrument alphabet.
FONT = {
    'A':[14,17,17,31,17,17,17], 'B':[30,17,17,30,17,17,30], 'C':[15,16,16,16,16,16,15],
    'D':[28,18,17,17,17,18,28], 'E':[31,16,16,30,16,16,31], 'F':[31,16,16,30,16,16,16],
    'G':[15,16,16,19,17,17,15], 'H':[17,17,17,31,17,17,17], 'I':[31,4,4,4,4,4,31],
    'J':[7,2,2,2,18,18,12], 'K':[17,18,20,24,20,18,17], 'L':[16,16,16,16,16,16,31],
    'M':[17,27,21,21,17,17,17], 'N':[17,25,21,19,17,17,17], 'O':[14,17,17,17,17,17,14],
    'P':[30,17,17,30,16,16,16], 'Q':[14,17,17,17,21,18,13], 'R':[30,17,17,30,20,18,17],
    'S':[15,16,16,14,1,1,30], 'T':[31,4,4,4,4,4,4], 'U':[17,17,17,17,17,17,14],
    'V':[17,17,17,17,17,10,4], 'W':[17,17,17,21,21,21,10], 'X':[17,17,10,4,10,17,17],
    'Y':[17,17,10,4,4,4,4], 'Z':[31,1,2,4,8,16,31], '0':[14,17,19,21,25,17,14],
    '1':[4,12,4,4,4,4,14], '2':[14,17,1,2,4,8,31], '3':[30,1,1,14,1,1,30],
    '4':[2,6,10,18,31,2,2], '5':[31,16,16,30,1,1,30], '6':[14,16,16,30,17,17,14],
    '7':[31,1,2,4,8,8,8], '8':[14,17,17,14,17,17,14], '9':[14,17,17,15,1,1,14],
    '-':[0,0,0,14,0,0,0], '/':[1,1,2,4,8,16,16], ' ':[0]*7,
}
CYAN=(151,237,211)
GOLD=(234,169,84)


def prepare(folder):
    pixels = np.full((384,512,3), (12,29,32), dtype=np.uint8)

    def line(a,b,color):
        count=max(abs(int(b[0]-a[0])),abs(int(b[1]-a[1])))+1
        x=np.linspace(a[0],b[0],count).round().astype(int)
        y=np.linspace(a[1],b[1],count).round().astype(int)
        pixels[y,x]=color

    def poly(points,color):
        for a,b in zip(points,points[1:]):
            line(a,b,color)

    def text(x,y,word,scale=1,color=CYAN):
        for letter in word:
            for r,bits in enumerate(FONT[letter]):
                for col in range(5):
                    if bits & (16>>col):
                        pixels[y+r*scale:y+(r+1)*scale,x+col*scale:x+(col+1)*scale]=color
            x+=6*scale

    pixels[9:14,12:500]=GOLD
    text(14,23,'S-4  /  EXOBIOLOGY',2)
    text(360,25,'CASE 07   SERIES 03',1,GOLD)
    pixels[49:50,12:500]=CYAN
    for x in range(14,500,13):
        pixels[58:242,x]=(28,66,66)
    for y in range(60,242,13):
        pixels[y,14:500]=(28,66,66)
    for i in range(10):
        angle=np.linspace(0,math.tau,95)
        head=[(int(120+math.cos(a)*(61-i*4.8)*(1+.21*math.sin(a))),
               int(146-math.sin(a)*(72-i*5.3))) for a in angle]
        poly(head,(65+i*7,137+i*5,137+i*4))
    for side in (-1,1):
        for j in range(3):
            eye=[(120+side*(16+k),153-.36*k+(6.5-j)*math.sin(k*math.pi/30)) for k in range(31)]
            poly(eye,CYAN)
            poly([(x,y-9*math.sin(k*math.pi/30)) for k,(x,y) in enumerate(eye)],CYAN)
    line((120,64),(120,220),GOLD)
    line((44,143),(194,143),GOLD)
    text(20,223,'AXIAL   /   074')
    for j,title in enumerate(['NEURAL FIELD','PHASE COHERENCE','RESONANCE']):
        y=64+59*j
        text(229,y,title,1,GOLD)
        wave=[(x,y+26+int(math.sin((x-228)*(.059+j*.016))*math.sin((x-228)*.027)*12+
                           4*math.sin((x-228)*.26))) for x in range(229,495)]
        poly(wave,CYAN)
    pixels[247:249,12:500]=GOLD
    text(15,257,'SPECIMEN 07',3)
    text(315,263,'PASSIVE SCAN',2)
    pixels[300:,:,:]=(202,185,140)
    pixels[305:379,7:505]=(30,39,37)
    text(18,317,'GROOM LAKE  /  RECOVERY',2,(211,206,168))
    text(18,344,'S-4   SPECIMEN  07',3,(239,216,159))
    for x in range(419,489,4):
        pixels[321:366,x:x+(1+x%3)]=(199,191,154)
    path=folder/'Field diagnostic phosphor.png'
    write_png(path,pixels)
    image=bpy.data.images.load(str(path))
    image.pack()
    for key,name,strength in [('readout','20 • Diagnostic phosphor',.70),('caseplate','21 • Museum brass enamel',0)]:
        mat=bpy.data.materials.new(name)
        MATERIALS[key]=mat
        mat.use_nodes=True
        p=mat.node_tree.nodes.get('Principled BSDF')
        p.inputs['Roughness'].default_value=.35
        p.inputs['Metallic'].default_value=.33 if key=='caseplate' else .10
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image=image
        mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
        if strength:
            mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Emission Color'])
            p.inputs['Emission Strength'].default_value=strength


def display(mesh, center, right, up, key):
    """Map the monitor or brass plate section to an oriented, front-facing rectangle."""
    from mathutils import Vector
    p,u,v=Vector(center),Vector(right)/2,Vector(up)/2
    top,bottom=(1,1-287/384) if key=='readout' else (1-300/384,.002)
    mesh.plate([p-u-v,p+u-v,p+u+v,p-u+v],key,[(.002,bottom),(.998,bottom),(.998,top),(.002,top)])
