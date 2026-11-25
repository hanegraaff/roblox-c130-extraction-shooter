"""Presentation-only desert ground, photographic lighting, scale figures and cameras."""
import math
import random
import bpy
from mathutils import Vector
from meshwork import Mesh, MATERIALS

VIEWS = {
    'Exterior': ((70, -89, 51), (0, 0, 8.4), 50),
    'Approach': ((-73, 82, 28), (0, 0, 11.8), 43),
    'Atrium': ((7.1, -21.4, 4.9), (-1.9, 2.6, 9.05), 19),
    'Gallery': ((-21.3, 18.55, 14.75), (3.4, -.8, 14.8), 19),
    'Receiver': ((19, 37, 34), (0, 0, 19.4), 37),
    'Overhead': ((0, -.1, 112), (0, 0, 0), 50),
}


def person(group, name, x, y, z, angle):
    m = Mesh()
    for sign in (-1, 1):
        a = sign*.37
        m.block(a-.25, a+.25, -.43, .31, 0, .4, 'black', .08)
        m.rod((a, 0, .35), (a*.9, 0, 2.52), .26, 'slate', 6, .33)
        m.rod((sign*.65, 0, 3.96), (sign*.84, -.12, 3.19), .245, 'gold', 8, .18)
        m.rod((sign*.84, -.12, 3.19), (sign*.92, -.18, 2.7), .17, 'slate', 8)
    m.loft([(-.48, -.29, 2.36), (.48, -.29, 2.36), (.48, .29, 2.36), (-.48, .29, 2.36)],
           [(-.62, -.35, 4.11), (.62, -.35, 4.11), (.62, .35, 4.11), (-.62, .35, 4.11)], 'gold')
    m.block(-.50, .50, -.365, -.30, 3.64, 3.79, 'bone')
    m.rod((0, 0, 4.1), (0, 0, 4.61), .26, 'rubber', 8)
    m.rod((0, 0, 4.50), (0, 0, 5.19), .39, 'slate', 12)
    m.rod((0, 0, 5.09), (0, 0, 5.28), .49, 'gold', 12)
    m.rod((0, 0, 5.28), (0, 0, 5.5), .43, 'gold', 12, .26)
    obj = m.finish(name, group)
    obj.location = (x, y, z)
    obj.rotation_euler.z = angle


def setup(group):
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.samples = 32
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 5
    s.render.resolution_x, s.render.resolution_y = 1440, 960
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = 'JPEG'
    s.render.image_settings.quality = 91
    s.view_settings.view_transform = 'AgX'
    s.world = bpy.data.worlds.new('High desert / daylight')
    s.world.use_nodes = True
    n = s.world.node_tree.nodes
    links = s.world.node_tree.links
    bg = n.get('Background')
    # Pale desert haze near the horizon and cooler skylight overhead.
    coord = n.new('ShaderNodeTexCoord')
    split = n.new('ShaderNodeSeparateXYZ')
    links.new(coord.outputs['Generated'], split.inputs[0])
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0
    ramp.color_ramp.elements[0].color = (.96, .66, .44, 1)
    ramp.color_ramp.elements[1].position = .79
    ramp.color_ramp.elements[1].color = (.20, .43, .80, 1)
    absolute = n.new('ShaderNodeMath')
    absolute.operation = 'ABSOLUTE'
    links.new(split.outputs['Z'], absolute.inputs[0])
    links.new(absolute.outputs[0], ramp.inputs[0])
    links.new(ramp.outputs[0], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = .64

    def light(name, kind, loc, target, energy, tint, spread):
        data = bpy.data.lights.new(name, kind)
        obj = bpy.data.objects.new(name, data)
        group.objects.link(obj)
        obj.location = loc
        obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z', 'Y').to_euler()
        data.energy = energy
        data.color = tint
        if kind == 'SUN':
            data.angle = spread
        else:
            data.shape = 'DISK'
            data.size = spread
        return obj
    light('Low afternoon sun', 'SUN', (-47, -62, 73), (0, 0, 0), 3.2, (1.0, .83, .67), .095)
    light('Sky over the oculus', 'AREA', (1, 2, 41), (0, 0, 2), 7200, (.80, .88, 1), 39)
    for i, (x, y) in enumerate([(-15, -16), (15, 16), (13, -17), (-13, 17)]):
        light('Warm interior bounce '+str(i), 'AREA', (x, y, 8.65), (x*.79, y*.74, 1.5), 260, (1, .72, .48), 4)
    # The horizon is a review set. A handful of layered mesa silhouettes
    # give the portals depth when inspecting from the floor and gallery.
    m = bpy.data.materials.new('Review desert dust')
    m.use_nodes = True
    nodes = m.node_tree.nodes
    l = m.node_tree.links
    p = nodes.get('Principled BSDF')
    tex = nodes.new('ShaderNodeTexNoise')
    coord = nodes.new('ShaderNodeTexCoord')
    l.new(coord.outputs['Object'], tex.inputs[0])
    tex.inputs['Scale'].default_value = .35
    tex.inputs['Detail'].default_value = 4.5
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (.19, .115, .069, 1)
    ramp.color_ramp.elements[1].color = (.51, .35, .215, 1)
    l.new(tex.outputs['Fac'], ramp.inputs[0])
    l.new(ramp.outputs[0], p.inputs['Base Color'])
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .19
    bump.inputs['Distance'].default_value = .17
    l.new(tex.outputs['Fac'], bump.inputs['Height'])
    l.new(bump.outputs[0], p.inputs['Normal'])
    MATERIALS['desert'] = m
    stage = Mesh()
    stage.block(-2900, 2900, -2900, 2900, -1.3, -.16, 'desert')
    stage.finish('Backdrop • desert floor', group)
    rng = random.Random(71)
    # Review set only. Low, scattered gravel gives exterior silhouettes a sense of scale.
    gravel = Mesh()
    for i in range(260):
        x, y = rng.uniform(-82, 82), rng.uniform(-70, 70)
        if abs(x) < 34 and abs(y) < 26:
            continue
        rock_size = rng.uniform(.12, .62)
        pts = [(x+rock_size*math.cos(t*math.tau/6)*rng.uniform(.7, 1.65),
                y+rock_size*math.sin(t*math.tau/6)*rng.uniform(.75, 1.1)) for t in range(6)]
        gravel.loft([(px, py, -.18) for px, py in pts],
                    [(x+(px-x)*.64+.07, y+(py-y)*.67, -.14+rock_size*rng.uniform(.32, .65)) for px, py in pts], 'desert')
    gravel.finish('Backdrop • wind-scoured gravel', group)
    ranges = Mesh()
    for i in range(78):
        a = i*math.tau/78
        r = rng.uniform(400, 470)
        x, y = r*math.cos(a), r*math.sin(a)
        sx, sy = rng.uniform(23, 65), rng.uniform(11, 27)
        h = rng.uniform(5, 18)
        coords = [(math.cos(j*math.tau/9)*rng.uniform(.8, 1), math.sin(j*math.tau/9)*rng.uniform(.8, 1))
                  for j in range(9)]

        def cross(width, z):
            return [(x+dx*sx*width, y+dy*sy*width, z+(j % 3)*.16) for j, (dx, dy) in enumerate(coords)]
        for low, high, w0, w1, mat in [(-1, h*.43, 1, .72, 'bone'), (h*.43, h*.52, .72, .70, 'brass'), (h*.52, h*.86, .70, .63, 'bone'), (h*.86, h, .63, .53, 'bone')]:
            ranges.loft(cross(w0, low), cross(w1, high), mat)
    ranges.finish('Backdrop • distant escarpment', group)
    person(group, 'Scale • 5.5 stud operator', -9.6, -4.9, 0, 1.45)
    person(group, 'Scale • gallery technician', 7.5, 18.8, 10, 2.9)
    for name, (pos, target, lens) in VIEWS.items():
        data = bpy.data.cameras.new(name)
        obj = bpy.data.objects.new(name, data)
        group.objects.link(obj)
        obj.location = pos
        obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z', 'Y').to_euler()
        data.lens = lens
        data.clip_end = 800
        if name == 'Overhead':
            data.type = 'ORTHO'
            data.ortho_scale = 82
        if name == 'Exterior':
            s.camera = obj
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.region_3d.view_rotation = s.camera.rotation_euler.to_quaternion()
            space.region_3d.view_distance = 94
            space.region_3d.view_location = (0, 0, 11)
            space.overlay.show_overlays = False
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'CAMERA'
            space.shading.color_type = 'MATERIAL'
            space.shading.light = 'STUDIO'
            space.shading.show_cavity = True
