"""Bake original wear, painted station signs and instrument graphics to packed PNGs."""
import math
from pathlib import Path
import struct
import zlib
import bpy
import numpy as np
from meshwork import MATERIALS

# Linear lighting and glTF use the same baked sRGB albedo and constant PBR factors.
PALETTE = {
    'bone': ('#c2b59e', .24, .74), 'chalk': ('#ded4b9', .27, .69), 'red': ('#905044', .35, .71),
    'slate': ('#444d4e', .58, .56), 'iron': ('#686d69', .68, .50), 'black': ('#292e30', .45, .69),
    'gold': ('#e0a340', .42, .53), 'brass': ('#bb8554', .7, .49), 'floor': ('#8d8e83', .20, .82),
    'ivory': ('#e5dbc3', .35, .53), 'silver': ('#bac1bc', .76, .38),
    'rubber': ('#302f2d', .03, .90), 'scorch': ('#4c3d34', .20, .9),
    'ember': ('#ffbb63', .09, .35), 'teal': ('#75c8b3', .24, .35)}
FONT = {
    'A': '01110 10001 10001 11111 10001 10001 10001', 'B': '11110 10001 10001 11110 10001 10001 11110', 'C': '01111 10000 10000 10000 10000 10000 01111',
    'D': '11110 10001 10001 10001 10001 10001 11110', 'E': '11111 10000 10000 11110 10000 10000 11111', 'F': '11111 10000 10000 11110 10000 10000 10000',
    'G': '01111 10000 10000 10111 10001 10001 01111', 'H': '10001 10001 10001 11111 10001 10001 10001', 'I': '11111 00100 00100 00100 00100 00100 11111',
    'J': '00111 00010 00010 00010 00010 10010 01100', 'K': '10001 10010 10100 11000 10100 10010 10001', 'L': '10000 10000 10000 10000 10000 10000 11111',
    'M': '10001 11011 10101 10101 10001 10001 10001', 'N': '10001 11001 11001 10101 10011 10011 10001', 'O': '01110 10001 10001 10001 10001 10001 01110',
    'P': '11110 10001 10001 11110 10000 10000 10000', 'Q': '01110 10001 10001 10001 10101 10010 01101', 'R': '11110 10001 10001 11110 10100 10010 10001',
    'S': '01111 10000 10000 01110 00001 00001 11110', 'T': '11111 00100 00100 00100 00100 00100 00100', 'U': '10001 10001 10001 10001 10001 10001 01110',
    'V': '10001 10001 10001 10001 10001 01010 00100', 'W': '10001 10001 10001 10101 10101 11011 10001', 'X': '10001 10001 01010 00100 01010 10001 10001',
    'Y': '10001 10001 01010 00100 00100 00100 00100', 'Z': '11111 00001 00010 00100 01000 10000 11111', '0': '01110 10001 10011 10101 11001 10001 01110',
    '1': '00100 01100 00100 00100 00100 00100 01110', '2': '01110 10001 00001 00010 00100 01000 11111', '3': '11110 00001 00001 01110 00001 00001 11110',
    '4': '00010 00110 01010 10010 11111 00010 00010', '5': '11111 10000 10000 11110 00001 00001 11110', '6': '01110 10000 10000 11110 10001 10001 01110',
    '7': '11111 00001 00010 00100 01000 01000 01000', '8': '01110 10001 10001 01110 10001 10001 01110', '9': '01110 10001 10001 01111 00001 00001 01110',
    '/': '00001 00001 00010 00100 01000 10000 10000', '-': '00000 00000 00000 11111 00000 00000 00000'}


def lettering(img, text, x, y, scale, color):
    for c in text:
        for j, row in enumerate(FONT.get(c, '').split()):
            for i, bit in enumerate(row):
                if bit == '1':
                    img[y+j*scale:y+(j+1)*scale, x+i*scale:x+(i+1)*scale] = color
        x += scale*6


def png(path, pixels):
    def chunk(key, data):
        return struct.pack('!I', len(data))+key+data+struct.pack('!I', zlib.crc32(key+data) & 0xffffffff)
    h, w, _ = pixels.shape
    scan = b''.join(b'\0'+row.tobytes() for row in pixels.astype(np.uint8))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('!2I5B', w, h, 8, 2, 0, 0, 0)) +
                     chunk(b'IDAT', zlib.compress(scan, 9))+chunk(b'IEND', b''))


def color(hexcode):
    return np.array(list(bytes.fromhex(hexcode[1:])), dtype=float)


def material(name, rgb, metal, rough, tex=None, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*((rgb/255)**2.2), 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = m.diffuse_color
    bs.inputs['Metallic'].default_value = metal
    bs.inputs['Roughness'].default_value = rough
    if emission:
        bs.inputs['Emission Color'].default_value = m.diffuse_color
        bs.inputs['Emission Strength'].default_value = emission
    if tex:
        img = bpy.data.images.load(str(tex))
        img.pack()
        img.filepath = '//'+tex.name
        node = m.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = img
        m.node_tree.links.new(node.outputs['Color'], bs.inputs['Base Color'])
    MATERIALS[name] = m


def smooth_noise(n, size, rng):
    grid = rng.normal(size=(size, size))
    x = np.arange(n)*size/n
    i = x.astype(int)
    t = (x-i)**2*(3-2*(x-i))
    row = grid[:, i]*(1-t)+grid[:, (i+1) % size]*t
    return row[i]*(1-t[:, None])+row[(i+1) % size]*t[:, None]


def prepare(folder):
    rng = np.random.default_rng(7007)
    for k, (hexcode, m, r) in PALETTE.items():
        base = color(hexcode)
        if k in ('ember', 'teal', 'rubber', 'scorch'):
            material(k, base, m, r, emission={'ember': 3, 'teal': 1}.get(k, 0))
            continue
        n = 256
        field = smooth_noise(n, 5, rng)*3.8+smooth_noise(n, 18, rng)*2.9+rng.normal(0, 2, (n, n))
        field += np.repeat(smooth_noise(n, 30, rng)[:1], n, axis=0)*1.5
        chip = smooth_noise(n, 14, rng)+.5*smooth_noise(n, 47, rng)+rng.normal(0, .26, (n, n))
        img = base+field[:, :, None]
        img[chip > 2.15] = img[chip > 2.15]*.52+np.array([32, 22, 18])
        for _ in range(28):
            x, y = rng.integers(0, n, 2)
            span = int(rng.integers(2, 15))
            img[y:y+1, x:x+span] *= rng.uniform(.71, .92)
        tex = folder/(k+'.png')
        png(tex, img.clip(0, 255))
        material(k, base, m, r, tex)
    for idx, (name, title, sub) in enumerate([('gateS', 'VESPER / 07', 'SOUTH   /   TRACKING ARRAY'), ('gateE', 'RELAY / 02', 'EAST   /   TRANSIT'), ('gateN', 'SERVICE', 'NORTH   /   HYDRAULICS'), ('gateW', 'INTAKE', 'WEST   /   MAINTENANCE')]):
        img = np.zeros((112, 512, 3))+[39, 53, 55]
        img[:4] = [229, 170, 69]
        img[12:99, 13:20] = [208, 143, 71]
        lettering(img, title, 34, 15, 6, [231, 222, 198])
        lettering(img, sub, 36, 79, 2, [188, 194, 175])
        for x in range(428, 493, 12):
            for y in range(21, 55):
                img[y, x-(y-21)//4:x+4-(y-21)//4] = [221, 161, 57]
        img += rng.normal(0, 2, (112, 512, 1))
        tex = folder/(name+'.png')
        png(tex, img.clip(0, 255))
        material(name, np.array([151, 150, 128]), .27, .63, tex)
    for name, digits in [('sector07', '07'), ('sector02', '02')]:
        img = np.zeros((128, 192, 3))+[131, 69, 55]
        img[6:9, 7:184] = [186, 131, 104]
        lettering(img, digits, 12, 21, 11, [230, 217, 186])
        lettering(img, 'VESPER', 13, 107, 2, [215, 186, 152])
        for j in range(4):
            img[23+j*13:27+j*13, 158:179] = [213, 174, 131]
        img += rng.normal(0, 4, (128, 192, 1))
        tex = folder/(name+'.png')
        png(tex, img.clip(0, 255))
        material(name, np.array([146, 88, 70]), .32, .70, tex)
    img = np.zeros((192, 384, 3))+[21, 42, 42]
    yy, xx = np.indices(img.shape[:2])
    dx, dy = xx-101, yy-95
    rad = np.hypot(dx, dy)
    for radius in [16, 32, 48, 64, 80]:
        img[np.abs(rad-radius) < .9] = [93, 151, 124]
    img[(rad < 81) & ((abs(dx) < 1) | (abs(dy) < 1))] = [109, 161, 129]
    img[(rad < 81) & (abs(dy+.61*dx) < 1.5) & (dx > 0)] = [181, 218, 153]
    for x, y in [(66, 67), (135, 82), (129, 116), (92, 139)]:
        img[y-2:y+2, x-2:x+2] = [239, 204, 108]
    lettering(img, 'VESPER', 206, 15, 3, [203, 199, 149])
    lettering(img, 'AZ / 247', 207, 55, 2, [119, 178, 145])
    lettering(img, 'SCAN 04', 207, 80, 2, [119, 178, 145])
    for i in range(32):
        h = int(14+11*math.sin(i*1.66)+17*math.sin(i*.19)**2)
        img[165-h:165, 205+i*5:208+i*5] = [104, 171, 132]
    tex = folder/'scope.png'
    png(tex, img)
    material('scope', np.array([102, 149, 120]), .1, .47, tex, .10)
