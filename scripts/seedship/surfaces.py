"""Pack seamless original mineral, alloy and basalt maps in portable PBR materials."""
import math
import struct
import zlib
from pathlib import Path

import bpy
import numpy as np
from meshwork import MATERIALS


def write_png(path, pixels):
    height, width = pixels.shape[:2]
    def chunk(tag, payload):
        return struct.pack('>I', len(payload)) + tag + payload + struct.pack('>I', zlib.crc32(tag + payload))
    rows = b''.join(b'\0' + row.tobytes() for row in pixels.astype('uint8'))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


def mineral_maps(folder, name, low, high, fleck, seed):
    rng = np.random.default_rng(seed)
    size = 512
    y, x = np.mgrid[0:size, 0:size] / size
    def noise(count):
        lattice = rng.random((count, count))
        xx, yy = x * count, y * count
        ix, iy = xx.astype(int), yy.astype(int)
        fx, fy = xx - ix, yy - iy
        fx, fy = fx*fx*(3-2*fx), fy*fy*(3-2*fy)
        def sample(dx, dy):
            return lattice[(iy+dy) % count, (ix+dx) % count]
        return (sample(0, 0)*(1-fx)+sample(1, 0)*fx)*(1-fy)+(sample(0, 1)*(1-fx)+sample(1, 1)*fx)*fy
    grain = rng.random((size, size))
    broad, medium, fine = noise(4), noise(13), noise(55)
    folded = x*2-y*3+1.7*broad+.32*medium+.045*fine
    band = np.abs(np.sin(folded*math.tau))
    hair = np.exp(-band*band/.002)
    crystals = np.maximum(0, (noise(31)*.66 + grain*.34-.72)*3)
    blend = np.clip(.11+.38*broad+.28*medium+.15*fine+.12*grain+.05*np.cos(folded*math.tau), 0, 1)
    rgb = np.array(low)+(np.array(high)-low)*blend[:,:,None]
    rgb += (hair*.58+crystals*.8)[:,:,None]*np.array(fleck)
    rgb -= np.exp(-((band-.085)/.025)**2)[:,:,None]*8
    relief = .26*fine+.15*medium+.05*grain-.15*hair
    dx = np.roll(relief, 1, axis=1)-np.roll(relief, -1, axis=1)
    dy = np.roll(relief, 1, axis=0)-np.roll(relief, -1, axis=0)
    normal = np.stack((dx*2.1, -dy*2.1, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[:,:,None]
    paths = []
    for suffix, pixels in [('color', rgb), ('normal', (normal*.5+.5)*255)]:
        path = folder / f'{name}-{suffix}.png'
        write_png(path, np.clip(pixels, 0, 255))
        image = bpy.data.images.load(str(path))
        if suffix == 'normal':
            image.colorspace_settings.name = 'Non-Color'
        image.pack()
        paths.append(image)
    return paths


def prepare(folder: Path):
    maps = {
        'shell': mineral_maps(folder, 'Vitreous nacre', (116,105,120), (228,211,185), (23,45,18), 19),
        'smoke': mineral_maps(folder, 'Smoked shell stratum', (87,72,91), (185,162,166), (47,45,16), 66),
        'frame': mineral_maps(folder, 'Folded amethyst alloy', (43,34,58), (141,101,140), (58,37,13), 52),
        'deck': mineral_maps(folder, 'Polished vesicular basalt', (30,31,46), (104,92,110), (55,38,23), 81),
    }
    # Display swatches are linear. The imported maps carry the sRGB paint colors.
    specs = [
        ('pearl','01 • Vitreous nacre',(.65,.54,.52),.29,.40,'shell'),
        ('mauve','02 • Smoky nacre',(.43,.34,.4),.49,.48,'smoke'),
        ('amethyst','03 • Folded amethyst',(.17,.095,.20),.67,.33,'frame'),
        ('edge','04 • Rhodium bevel',(.31,.22,.32),.80,.32,None),
        ('night','05 • Anodised graphite',(.041,.034,.060),.72,.36,None),
        ('deck','06 • Vesicular basalt',(.10,.08,.13),.37,.39,'deck'),
        ('brass','07 • Palladium gold',(.55,.35,.147),.83,.29,None),
        ('raw','08 • Cleaved matrix',(.21,.17,.24),.15,.77,None),
        ('mint','09 • Phosphor / jade',(.30,.84,.43),.23,.23,None),
        ('white','10 • Phosphor / heart',(.81,1,.53),.12,.20,None),
        ('green','11 • Olivine prism',(.24,.48,.22),.41,.20,None),
        ('olive','12 • Prismatic shadow',(.08,.21,.16),.57,.25,None),
        ('amber','13 • Amber pollen',(.95,.47,.09),.30,.25,None),
        ('glass','15 • Peridot ampoule',(.27,.55,.40),.16,.18,None),
        ('silver','14 • Brushed platinum',(.49,.46,.53),.78,.36,None),
    ]
    for key, title, color, metal, rough, tile in specs:
        mat = bpy.data.materials.new(title)
        MATERIALS[key] = mat
        mat.diffuse_color = (*color, 1)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        shader = nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (*color,1)
        shader.inputs['Metallic'].default_value = metal
        shader.inputs['Roughness'].default_value = rough
        if key in ('mint','white','amber','green'):
            shader.inputs['Emission Color'].default_value = (*color,1)
            shader.inputs['Emission Strength'].default_value = {'mint':1.5,'white':3.0,'amber':.42,'green':.20}[key]
        if key=='glass':
            shader.inputs['Alpha'].default_value=.16
            mat.diffuse_color=(*color,.16)
            mat.surface_render_method='BLENDED'
        if tile:
            tex = nodes.new('ShaderNodeTexImage')
            tex.image = maps[tile][0]
            links.new(tex.outputs['Color'], shader.inputs['Base Color'])
            tex = nodes.new('ShaderNodeTexImage')
            tex.image = maps[tile][1]
            bump = nodes.new('ShaderNodeNormalMap')
            bump.inputs['Strength'].default_value = .42
            links.new(tex.outputs['Color'], bump.inputs['Color'])
            links.new(bump.outputs['Normal'], shader.inputs['Normal'])
