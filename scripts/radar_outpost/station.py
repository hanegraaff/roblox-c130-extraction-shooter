"""Stable walking surfaces, supporting frame, safety railings and station equipment."""
import math
from mathutils import Vector
from meshwork import Mesh, TAU
from layout import OUTLINE, WELL, BAYS, STAIRS, UPPER, ROOF, STEPS, RISE, RUN, gallery_wedges
from envelope import Bay


def line(mesh, a, b, z, r, mat, n=6):
    mesh.rod((*a, z), (*b, z), r, mat, n)


def guard(mesh, a, b, z1, z2=None):
    z2 = z1 if z2 is None else z2
    p, q = Vector((*a, z1)), Vector((*b, z2))
    n = max(1, math.ceil((q-p).length/4.6))
    for j in range(n+1):
        foot = p.lerp(q, j/n)
        mesh.rod(foot, foot+Vector((0, 0, 1.88)), .068, 'gold', 6)
        mesh.rod(foot, foot+Vector((0, 0, .22)), .13, 'slate', 6)
    for h, r, mat in [(.76, .05, 'iron'), (1.76, .094, 'gold')]:
        delta = Vector((0, 0, h))
        mesh.rod(p+delta, q+delta, r, mat, 8)


def decks(static, dress):
    foundation = Mesh()
    foundation.prism(OUTLINE, -.66, 0, 'floor')
    foundation.finish('Foundation • 64 x 48', static, role='walkable')
    deck = Mesh()
    for poly in gallery_wedges():
        deck.prism(poly, 9.45, 10, 'floor')
    deck.finish('Observation gallery • continuous loop', static, (0, 0, 10), role='walkable')
    for name, cx, ascent in STAIRS:
        walk, metal = Mesh(), Mesh()
        for i in range(STEPS):
            a = ascent*(-15+i*RUN)
            b = a+ascent*RUN
            top = (i+1)*RISE
            walk.block(cx-4, cx+4, min(a, b), max(a, b), top-.37, top, 'iron')
            leading = a+ascent*.09
            metal.block(cx-3.94, cx+3.94, leading-.07, leading+.07, top+.004, top+.024, 'gold')
            for j in range(3):
                y = a+ascent*(.54+j*.4)
                metal.block(cx-3.63, cx+3.63, y-.022, y+.022, top+.003, top+.012, 'slate')
        for sign in (-1, 1):
            x = cx+sign*3.89
            metal.rod((x, -15*ascent, .17), (x, 15*ascent, 9.56), .24, 'slate', 4)
            guard(metal, (x, -14.8*ascent), (x, 14.9*ascent), .59, 10)
        walk.finish(name+' open-riser flight', static, (cx, -15*ascent, 0), role='walkable')
        metal.finish(name+' stair • nosings, handrails and stringers', dress, role='dressing')
    trim = Mesh()
    for a, b in zip(WELL, WELL[1:]+WELL[:1]):
        # The high stair landings have level, unrailed entry into the gallery.
        high = (a[1] == b[1] == 15 and max(a[0], b[0]) <= -
                14.3) or (a[1] == b[1] == -15 and min(a[0], b[0]) >= 14.3)
        if high:
            continue
        guard(trim, a, b, 10)
        line(trim, a, b, 9.48, .21, 'slate', 4)
    trim.finish('Gallery • inner guard and fascia', dress, role='dressing')


def frame(static, dress):
    for label, a, b, gate in BAYS:
        bay = Bay(label, a, b, gate)
        half = bay.span/2
        mesh, detail = Mesh(), Mesh()
        mesh.transform = detail.transform = bay.wall_point
        # Column at the common boundary; buttresses sit on that same stable strip.
        x = -half
        mesh.block(x-.23, x+.23, -.64, .22, 0, ROOF, 'slate')
        mesh.block(-half, half, -.82, .15, 9.58, 10.0, 'slate')
        mesh.block(-half, half, -.84, .22, ROOF-.29, ROOF-.01, 'iron')
        if len(label) == 3 or gate or label in ('S1', 'N1'):
            foot = x+.23 if len(label) == 3 else x
            mesh.loft([(foot+d, y, .02) for d, y in [(-.77, -.59), (.77, -.59), (.64, .73), (-.64, .73)]],
                      [(x+d, y, 8.93) for d, y in [(-.27, -.59), (.27, -.59), (.27, .16), (-.27, .16)]], 'iron')
        if label in ('S2', 'S4', 'N2', 'N4', 'E2', 'W2'):
            # Cant the broad external boot toward its slender upper fixing plate.
            foot = x-.66
            mesh.loft([(foot+d, y, .03) for d, y in [(-.73, -.45), (.73, -.45), (.63, .88), (-.63, .88)]],
                      [(x+d, y, 8.77) for d, y in [(-.42, -.45), (.42, -.45), (.36, .28), (-.36, .28)]], 'slate')
            for j in range(5):
                f = (j+.5)/5
                bx = foot*(1-f)+x*f
                y = .88*(1-f)+.28*f
                detail.rod((bx, y-.04, .03+8.74*f), (bx, y+.07, .03+8.74*f), .128, 'silver', 6)
        # A narrow brace supports each gallery projection.
        detail.rod((x, -.74, 7.13), (x, -2.65, 9.43), .19, 'iron', 4)
        for z in (1.2, 8.65, 11.12, 17.75):
            detail.rod((x, .24, z), (x, .33, z), .104, 'silver', 6)
        # Interior soffit light with a black gasket and amber diffuser.
        detail.block(-1.47, 1.47, -1.18, -.67, 17.90, 18.22, 'black', .06)
        detail.block(-1.29, 1.29, -1.195, -.71, 17.88, 18.12, 'ember', .04)
        # High-luminance strips under both balconies read from the open yard.
        for z, depth in [(9.30, 1.15), (18.28, 1.32)]:
            detail.block(-1.99, 1.99, -depth-.32, -depth+.22, z-.18, z+.1, 'slate', .07)
            detail.block(-1.8, 1.8, -depth-.34, -depth+.1, z-.204, z-.14, 'ember', .06)
        for height in (2.0, 7.9, 13.5, 17.5):
            detail.block(x-.36, x+.36, -.7, .27, height, height+.16, 'iron')
        if label in ('S2', 'E3', 'N2', 'W3'):
            for y_offset in (1.56, 1.8):
                detail.rod((x, -y_offset, .38), (x, -y_offset, 8.92), .073, 'brass')
        mesh.finish('Frame '+label, static, role='support')
        detail.finish('Frame fittings '+label, dress, role='dressing')


def markings(group):
    mesh = Mesh()
    mesh.ring(6.7, 7.03, .004, .021, 'gold', 80)
    mesh.ring(7.11, 7.18, .004, .018, 'bone', 80)
    for i in range(84):
        a = i*TAU/84
        r = 7.5 if i % 7 else 7.85
        mesh.rod((7.23*math.cos(a), 7.23*math.sin(a), .027),
                 (r*math.cos(a), r*math.sin(a), .027), .051, 'slate', 4)
    # Structural expansion joints are flush with the finish; embedded drains flank the approaches.
    for x in range(-24, 25, 8):
        mesh.block(x-.026, x+.026, -23.85, 23.85, .002, .009, 'iron')
    for y in range(-16, 17, 8):
        mesh.block(-31.8, 31.8, y-.026, y+.026, .002, .009, 'iron')
    for y in (-18.1, 18.1):
        for x in (-10, -4, 2, 8):
            mesh.block(x, x+3.7, y-.29, y+.29, .012, .036, 'slate')
            for i in range(13):
                mesh.block(x+.12+i*.27, x+.22+i*.27, y-.245, y+.245, .036, .05, 'iron')
    for sign in (-1, 1):
        cx = sign*8
        for x in (cx-4.7, cx+4.7):
            mesh.block(x-.07, x+.07, min(-sign*23.8, -sign*14.0),
                       max(-sign*23.8, -sign*14.0), .008, .021, 'gold')
    mesh.finish('Service floor • swing clearance, drains and lane paint', group, role='dressing')


def console(group):
    mesh = Mesh()
    mesh.block(-2.32, 2.32, -.82, .82, 0, .28, 'slate', .2)
    mesh.block(-1.84, 1.84, -.59, .54, .28, 1.57, 'iron', .14)
    xy = [(-2.53, -.85), (2.53, -.85), (2.53, .79), (-2.53, .79)]
    mesh.loft([(x, y, 1.54) for x, y in xy], [(x, y, 2.18+(y+.85)*.50) for x, y in xy], 'slate')
    for x0, x1 in [(-2.33, .59), (.72, 1.84)]:
        points = [(x0, -.54), (x1, -.54), (x1, .62), (x0, .62)]
        mesh.plate([(x, y, 2.206+(y+.85)*.50) for x, y in points], 'scope')
    for i in range(6):
        mesh.rod((-1.94+i*.57, -.7, 2.29), (-1.94+i*.57, -.7, 2.37), .093, 'gold' if i < 2 else 'teal', 8)
    for j in range(3):
        mesh.block(-1.23, 1.23, -.62, -.58, .56+j*.19, .63+j*.19, 'black')
    obj = mesh.finish('Scope console / N1', group, role='dressing')
    for i, (x, y, ang) in enumerate([(-12.85, 21.2, 0), (12.85, 21.2, 0), (-13.45, -21.2, math.pi), (29, 7, -math.pi/2), (-29, -7, math.pi/2)]):
        copy = obj if i == 0 else obj.copy()
        if i:
            group.objects.link(copy)
        copy.name = 'Observation scope '+str(i+1)
        copy.location = (x, y, 10)
        copy.rotation_euler.z = ang


def utilities(group):
    # Free-standing pump skids, with open space above the units and beside each entry.
    for i, (x, y, ang) in enumerate([(2.1, 20.0, 0), (11, 19.6, 0), (-12, -19.6, math.pi)]):
        m = Mesh()
        m.block(-2.7, 2.7, -1.1, 1.1, .02, .31, 'slate', .18)
        for j in (-1, 1):
            m.rod((-.98, j*.48, 1.08), (1.14, j*.48, 1.08), .43, 'gold', 12)
            for s in (-1.08, -.79, .85, 1.16):
                m.rod((s, j*.48, 1.08), (s+.12, j*.48, 1.08), .49, 'iron', 12)
            m.rod((-1.55, j*.48, 1.08), (-.95, j*.48, 1.08), .23, 'brass', 8)
            m.rod((-1.55, j*.48, .31), (-1.55, j*.48, 1.08), .23, 'brass', 8)
            m.rod((1.16, j*.48, 1.08), (1.77, j*.48, 1.08), .20, 'iron')
        m.block(1.57, 2.27, -.84, .84, .32, 2.3, 'bone', .13)
        m.block(1.64, 2.19, -.88, -.84, 1.49, 1.82, 'black')
        m.block(1.73, 1.91, -.91, -.88, 1.56, 1.69, 'teal')
        obj = m.finish('Hydraulic skid '+str(i+1), group, role='dressing')
        obj.location = (x, y, 0)
        obj.rotation_euler.z = ang
