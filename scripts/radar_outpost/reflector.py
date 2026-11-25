"""Segmented parabolic reflector, receiver cage, elevation mechanism and azimuth drive."""
import math
from mathutils import Vector
from meshwork import Mesh, TAU


def polar(r, a, z):
    return Vector((r*math.cos(a), r*math.sin(a), z))


def mount(group):
    drum = Mesh()
    drum.rod((0, 0, .02), (0, 0, .46), 5.95, 'slate', 32)
    drum.rod((0, 0, .46), (0, 0, 1.05), 5.62, 'iron', 24, 5.42)
    drum.rod((0, 0, 1.05), (0, 0, 7.8), 5.3, 'black', 16, 3.55)
    for i in range(16):
        a = i*TAU/16

        def plate(z0, z1, r0, r1, mat):
            ends = [a+.013, a+TAU/16-.013]
            drum.loft([polar(r, t, z0) for r, t in [(r0-.2, ends[0]), (r0, ends[0]), (r0, ends[1]), (r0-.2, ends[1])]],
                      [polar(r, t, z1) for r, t in [(r1-.2, ends[0]), (r1, ends[0]), (r1, ends[1]), (r1-.2, ends[1])]], mat)
        for z0, z1, r0, r1, mat in [(1.08, 2.9, 5.45, 4.98, 'bone'), (2.9, 3.53, 4.98, 4.83, 'red'), (3.53, 6.55, 4.83, 4.13, 'bone'), (6.55, 7.75, 4.13, 3.85, 'slate')]:
            plate(z0, z1, r0, r1, mat)
        angle = a+TAU/32
        drum.rod(polar(5.18, angle, 1.04), polar(5.18, angle, 1.22), .13, 'silver', 6)
        if i % 2 == 0:
            for j in range(5):
                z = 4+j*.32
                r = 4.9-(z-3.53)*.23
                drum.rod(polar(r, angle-.116, z), polar(r, angle+.116, z), .12, 'black', 4)
    for z0, z1, r, mat in [(7.75, 8.12, 4.48, 'iron'), (8.12, 8.65, 4.52, 'gold'), (8.65, 9.04, 4.52, 'slate'), (9.04, 9.45, 3.91, 'silver'), (9.45, 10.35, 3.65, 'black'), (10.35, 10.69, 3.78, 'iron')]:
        drum.rod((0, 0, z0), (0, 0, z1), r, mat, 48)
    for i in range(32):
        a = TAU*i/32
        drum.rod(polar(4.51, a, 8.76), polar(4.60, a, 8.76), .105, 'silver', 6)
    for i in range(8):
        a = TAU*i/8+.20
        for offset in (-.032, .032):
            drum.rod(polar(5.57, a+offset, .75), polar(4.43, a+offset, 5.14), .12, 'slate', 8)
            drum.rod(polar(5.18, a+offset, 2.12), polar(4.65, a+offset, 4.19), .16, 'silver', 8)
        drum.rod(polar(4.49, a-.085, 6.36), polar(4.49, a+.085, 6.36), .145,
                 'ember' if i % 2 == 0 else 'iron', 6)
        for j in range(3):
            angle = a+.21+j*.030
            drum.rod(polar(4.56, angle, 8.21), polar(4.56, angle+.029, 8.56), .051, 'slate', 4)
    for i in (1, 5, 9, 13):
        a = TAU*i/16
        for j in range(4):
            z = 1.60+j*.73
            r = 5.58-.24*(z-1.60)
            drum.rod(polar(r, a-.11, z), polar(r, a+.11, z), .067, 'silver')
            for sign in (-1, 1):
                drum.rod(polar(r-.2, a+sign*.11, z), polar(r, a+sign*.11, z), .067, 'iron')
    drum.finish('Azimuth drive • battered plinth and bearing', group, role='stationary-mechanism')


def build(group, technical):
    mount(group)
    # u is the horizontal elevation axle. w is the receiving face normal.
    w = Vector((.11, .85, .51)).normalized()
    u = Vector((-w.y, w.x, 0)).normalized()
    v = w.cross(u)
    base = Vector((0, 0, 18.72))
    flat = Vector((w.x, w.y, 0)).normalized()
    g = Mesh()
    g.transform = lambda p: u*p.x+flat*p.y+Vector((0, 0, p.z))
    for sign in (-1, 1):
        x = sign*2.24
        # Plated elevation cheeks with sloping sides and an actual axial bearing.
        yz = [(-2.52, 10.56), (2.15, 10.56), (2.27, 13.34), (.83, 17.25), (-.84, 17.25), (-2.18, 13.35)]
        g.loft([(x-.45, y, z) for y, z in yz], [(x+.45, y, z) for y, z in yz], 'bone')
        for r, length, mat in [(1.31, .29, 'black'), (1.02, .42, 'iron'), (.66, .51, 'brass'), (.31, .6, 'slate')]:
            g.rod((x+sign*.44, 0, 16.22), (x+sign*(.44+length), 0, 16.22), r, mat, 20)
        for j in range(8):
            a = j*TAU/8
            g.rod((x+sign*.89, .81*math.cos(a), 16.22+.81*math.sin(a)),
                  (x+sign*.99, .81*math.cos(a), 16.22+.81*math.sin(a)), .08, 'silver', 6)
        p = Vector((sign*2.99, -2.8, 10.37))
        q = Vector((sign*3.09, -4.0, 18.80))
        g.rod(p, q, .27, 'silver', 12)
        g.rod(p, p.lerp(q, .59), .48, 'gold', 12)
        for f in (.04, .16, .54, .9):
            g.rod(p.lerp(q, f), p.lerp(q, f+.035), .52, 'slate', 12)
        g.rod((sign*1.9, -.2, 16.0), q, .38, 'iron', 8)
    g.rod((-2.89, 0, 16.22), (2.89, 0, 16.22), .72, 'iron', 16)
    g.rod((0, 0, 15.8), (0, 0, 18.62), 1.55, 'slate', 12)
    # Exposed elevation gear, perforated indexing drum and bronze service lines.
    for sign in (-1, 1):
        x = sign*2.44
        g.rod((x, -1.72, 12.0), (x+sign*.49, -1.72, 12.0), .67, 'slate', 16)
        g.rod((x+sign*.49, -1.72, 12.0), (x+sign*.65, -1.72, 12.0), .43, 'gold', 12)
        for j in range(13):
            a = j*.175+1.8
            g.rod((x+sign*.49, 1.48*math.cos(a), 16.22+1.48*math.sin(a)),
                  (x+sign*.69, 1.48*math.cos(a), 16.22+1.48*math.sin(a)), .17, 'iron', 4)
        for p, q in [((-1.70, 11), (-1.70, 13.4)), ((-1.70, 13.4), (-.74, 14.6))]:
            g.rod((x+sign*.49, *p), (x+sign*.49, *q), .076, 'brass', 8)
    g.finish('Elevation yoke • trunnions and hydraulic rams', group, role='mechanism')

    def world(p):
        return base+u*p.x+v*p.y+w*p.z

    def at(radius, angle, offset=0):
        return polar(radius, angle, 3.5*(radius/12.9)**2+offset)

    def sheet(m, r0, r1, a, b, offset, mat):
        ps = [at(r0, a, offset), at(r1, a, offset), at(r1, b, offset), at(r0, b, offset)]
        m.loft([p-Vector((0, 0, .085)) for p in ps], ps, mat)
    pedestal = Mesh()
    pedestal.rod((0, 0, 0), (0, 0, .46), 5.95, 'black', 24)
    pedestal.rod((0, 0, .46), (0, 0, 7.75), 5.55, 'black', 16, 3.9)
    pedestal.rod((0, 0, 7.75), (0, 0, 9.08), 4.52, 'black', 32)
    pedestal.rod((0, 0, 9.08), (0, 0, 10.69), 3.78, 'black', 24)
    pedestal.finish('Drive pedestal solid', technical, role='mechanism-proxy')
    reflector_proxy = Mesh()
    reflector_proxy.transform = world
    for i in range(24):
        for low, high in [(.05, 3.27), (3.27, 5.72), (5.72, 8.26), (8.26, 10.52), (10.52, 12.68)]:
            sheet(reflector_proxy, low, high, TAU*i/24, TAU*(i+1)/24, 0, 'black')
    reflector_proxy.finish('Reflector shell solid', technical, base, role='mechanism-proxy')
    for quadrant in range(4):
        dish = Mesh()
        dish.transform = world
        for i in range(6*quadrant, 6*quadrant+6):
            a, b = TAU*i/24, TAU*(i+1)/24
            mid = (a+b)/2
            for j, (r0, r1) in enumerate([(1.02, 3.2), (3.27, 5.65), (5.74, 8.18), (8.28, 10.44), (10.53, 12.58)]):
                mat = 'chalk' if (i+2*j) % 9 == 0 else 'ivory'
                sheet(dish, r0, r1, a+.004, b-.004, 0, mat)
                for radius in ([r0, r1-.12] if j in (2, 4) else [r1-.14]):
                    p = at(radius, a+.021, .015)
                    dish.rod(p, p+Vector((0, 0, .071)), .073, 'iron', 6)
                # A faceted double-curvature back truss: rings and opposing diagonal webs.
                depth = .42+.8*math.sin(math.pi*(r1/14))
                dish.rod(at(r0, a, -.10), at(r1, a, -.1), .092, 'iron', 6)
                dish.rod(at(r0, a, -depth), at(r1, a, -depth), .122, 'brass', 6)
                dish.rod(at(r1, a, -depth), at(r1, b, -depth), .11, 'bone', 6)
                dish.rod(at(r0, a, -depth), at(r1, b, -.15), .079, 'iron', 6)
                dish.rod(at(r0, a, -.15), at(r1, b, -depth), .074, 'brass', 6)
            # Raised face ribs and circumferential seaming on the receiving surface.
            for r0, r1 in [(1.05, 3.29), (3.29, 5.72), (5.72, 8.26), (8.26, 10.52), (10.52, 12.64)]:
                dish.rod(at(r0, a, .045), at(r1, a, .045), .067, 'silver', 6)
            # A fine top lattice crosses the reflector tiles, clearly visible at gallery scale.
            if i % 2 == 0:
                for r0, r1 in [(3.27, 5.69), (5.69, 8.26), (8.26, 10.48), (10.48, 12.65)]:
                    crown = at(r1, a, .29)
                    dish.rod(at(r0, a, .18), crown, .092, 'bone', 6)
                    dish.rod(crown, at(r0, b, .06), .058, 'silver', 6)
                dish.rod(at(8.26, a, .09), at(8.26, a, .35), .15, 'brass', 8)
            for r in (5.69, 10.48):
                dish.rod(at(r, a, .045), at(r, b, .045), .06, 'brass', 6)
            for height, r, thick, mat in [(.09, 12.86, .16, 'chalk'), (-.51, 12.79, .16, 'bone'), (-.92, 12.35, .115, 'brass')]:
                dish.rod(at(r, a, height), at(r, b, height), thick, mat, 8)
            dish.rod(at(12.83, a, -.54), at(12.86, mid, .075), .1, 'iron', 6)
            dish.rod(at(12.86, mid, .075), at(12.83, b, -.54), .1, 'iron', 6)
            if i % 3 == 0:
                sheet(dish, 11.62, 12.5, a+.021, a+.062, .025, 'red')
                sheet(dish, 11.62, 12.5, a+.074, a+.089, .025, 'red')
        dish.finish('Reflector petal bank '+str(quadrant+1), group, base, role='reflector-visual')
    feed = Mesh()
    feed.transform = world
    feed.rod((0, 0, -1.4), (0, 0, .34), 1.08, 'slate', 24)
    for i in range(3):
        a = TAU*i/3+.22
        joint = polar(.67, a, 6.45)
        for offset in (-.105, .105):
            foot = at(9.64, a+offset, .08)
            feed.rod(foot, joint, .125, 'iron', 8)
            feed.rod(foot, foot.lerp(joint, .095), .21, 'gold', 8)
        feed.rod(polar(.67, a, 6.45), polar(.67, a+TAU/3, 6.45), .135, 'bone', 8)
    for z0, z1, r0, r1, mat in [(4.29, 4.5, .51, .55, 'slate'), (4.5, 5.53, .55, .23, 'brass'), (5.53, 6.32, .28, .35, 'silver'), (6.32, 6.65, .74, .74, 'gold'), (6.65, 7.27, .57, .44, 'slate'), (7.27, 7.4, .45, .4, 'bone')]:
        feed.rod((0, 0, z0), (0, 0, z1), r0, mat, 16, r1)
    feed.finish('Receiver • tripod and feedhorn', group, base, role='reflector-visual')
