"""Destructible skin, matched query solids and common origins for each bay."""
import math
from mathutils import Vector
from meshwork import Mesh
from layout import BAYS, ROOF


class Bay:
    def __init__(self, label, a, b, gate):
        self.label = label
        self.a, self.b = Vector(a), Vector(b)
        self.axis = (self.b-self.a).normalized()
        self.out = Vector((self.axis.y, -self.axis.x))
        self.mid = (self.a+self.b)/2
        self.span = (self.b-self.a).length
        self.gate = gate

    def wall_point(self, p):
        x, y, z = p
        # Battered lower skirt and recessed upper observation gallery.
        inset = .16+.098*min(z, 9.8) if z < 10 else 1.10
        pt = self.mid+self.axis*x+self.out*(y-inset)
        return Vector((pt.x, pt.y, z))

    def roof_point(self, p):
        x, y, z = p
        # Loft along the clipped outer perimeter onto the elliptical oculus.
        v = x/self.span+.5
        outer = self.a.lerp(self.b, v)

        def lip(pt):
            scale = 1/math.sqrt((pt.x/24.1)**2+(pt.y/17.6)**2)
            return pt*scale
        inner = lip(self.a).lerp(lip(self.b), v)
        pt = outer.lerp(inner, y)
        return Vector((pt.x, pt.y, z))


def wall(bay, story, stage, proxy=False):
    mesh = Mesh()
    mesh.transform = bay.wall_point
    half = bay.span/2-.27
    base = 0 if story == 1 else 10
    limit = 9.57 if story == 1 else ROOF-.29
    side = max(1.05, half*.2)
    gate = story == 1 and bay.gate
    if gate:
        sill, head, side = 0, 7.8, .96
    elif story == 1:
        sill, head = 3.74, 6.12
    else:
        sill, head, side = 10.78, 16.94, .57
    if stage == 'Heavy':
        ranges = [(-half, -half*.51), (half*.51, half)]
    else:
        ranges = [(-half, half)]

    def part(x0, x1, y0, y1, z0, z1, mat, cosmetic=False):
        if proxy and cosmetic:
            return
        for low, high in ranges:
            mesh.block(max(x0, low), min(x1, high), y0, y1, z0, z1, 'black' if proxy else mat)

    def skin(x0, x1, z0, z1, mat):
        part(x0, x1, -.52, 0, z0, z1, mat)
    # Separate base strata make the oxide belt continuous around chamfered corners.
    bands = [(base, base+.56, 'slate'), (base+.56, 1.84, 'bone'), (1.84, 2.53, 'red'),
             (2.53, sill, 'bone')] if story == 1 else [(base, sill, 'slate')]
    if not gate:
        for low, high, mat in bands:
            if min(sill, high) > low:
                skin(-half, half, low, min(sill, high), mat)
    for x0, x1 in [(-half, -half+side), (half-side, half)]:
        skin(x0, x1, sill, head, 'iron' if story == 2 else 'bone')
    skin(-half, half, head, limit, 'slate' if story == 2 else 'bone')
    # A real, unglazed slot on every lower non-portal bay.
    if story == 1 and not gate:
        for x in (-.20*half, .36*half):
            if stage != 'Heavy' or abs(x) > half*.52:
                mesh.loft([(x+dx, y, sill) for dx, y in [(-.15, -.48), (.15, -.48), (.15, .04), (-.15, .04)]],
                          [(x+.33+dx, y, head)
                           for dx, y in [(-.15, -.48), (.15, -.48), (.15, .04), (-.15, .04)]],
                          'black' if proxy else 'iron')
        part(-half+side, half-side, -.65, .15, sill-.13, sill+.05, 'slate')
        part(-half+.14, half-.14, 0, .06, limit-.8, limit-.65, 'red', True)
    if story == 2:
        part(-half, half, -.57, .08, sill-.14, sill, 'gold', True)
    if gate:
        part(-half, half, -.59, .88, head, head+.25, 'iron')
        part(-half, half, .002, .84, head+.25, limit-.04, 'slate')
        for sign in (-1, 1):
            x = sign*(half-.53)
            part(x-.37, x+.37, -.01, .85, .13, 7.78, 'iron')
            part(x-.19, x+.19, .85, .9, .72, 6.92, 'slate', True)
            part(x-.08, x+.08, .9, .93, 1.0, 5.66, 'ember', True)
        for sign in (-1, 1):
            x = sign*(half-.53)
            part(x-.20, x+.20, 0, .12, .6, 4.86, 'black', True)
            part(x-.08, x+.08, .12, .18, 1, 4.53, 'ember', True)
        for sign in (-1, 1):
            x = sign*(half-side)
            triangle = [(x, 6.42), (x-sign*1.31, 7.78), (x, 7.84)]
            mesh.loft([(a, -.58, z) for a, z in triangle], [(a, .82, z)
                      for a, z in triangle], 'black' if proxy else 'iron')
        if stage in ('Pristine', 'Light') and not proxy:
            w = min(10.4, bay.span-3)
            part(-w/2-.12, w/2+.12, .84, .89, 8.09, 9.52, 'black', True)
            mesh.plate([(-w/2, .91, 8.13), (w/2, .91, 8.13), (w/2, .91, 9.47),
                       (-w/2, .91, 9.47)], 'gate'+bay.label[0])
    if story == 2 and len(bay.label) == 3:
        part(-half, half, -.55, .20, 16.26, 16.94, 'bone')
        part(-half, half, .20, .23, 16.42, 16.67, 'red', True)
    if not proxy and stage in ('Pristine', 'Light'):
        if story == 2:
            for h, r, mat in [(11.02, .065, 'iron'), (11.90, .105, 'gold')]:
                mesh.rod((-half, -.42, h), (half, -.42, h), r, mat)
            for x in (-half*.63, 0, half*.63):
                mesh.rod((x, -.42, sill), (x, -.42, 11.9), .075, 'gold')
            if len(bay.label) == 3:
                for sign in (-1, 1):
                    mesh.rod((sign*(half-.18), -.14, 11.01),
                             (-sign*(half-.18), -.14, 17.23), .145, 'slate', 4)
        if story == 1 and not gate:
            # Stacked sill, recessed fascia panels and inspection-door hardware.
            part(-half, half, .005, .085, .63, .74, 'iron', True)
            part(-half+.13, half-.13, .005, .040, 6.37, 6.60, 'slate', True)
            for x in (-half+.55, half-.55):
                part(x-.26, x+.26, .01, .12, 6.91, 8.8, 'iron', True)
                for j in range(5):
                    part(x-.20, x+.20, .12, .14, 7.14+j*.25, 7.23+j*.25, 'black', True)
            for x in (-half*.58, 0, half*.58):
                part(x-.035, x+.035, .001, .03, .76, 3.0, 'slate', True)
                for z in (.88, 2.8, 6.83, 9.19):
                    mesh.rod((x, .032, z), (x, .085, z), .077, 'silver', 6)
            if bay.label in ('S2', 'E3', 'N2', 'W3', 'SE1', 'NW1'):
                sign = 'sector07' if bay.label in ('S2', 'N2', 'SE1') else 'sector02'
                mesh.plate([(-1.39, .055, 6.76), (1.39, .055, 6.76),
                           (1.39, .055, 8.72), (-1.39, .055, 8.72)], sign)
        if story == 1 and not gate:
            # Squared service lines run along the inner face, below the slit window.
            for j, z in enumerate((1.10, 1.76)):
                start, end = -half+.72, half-1.02-j*.36
                for p, q in [((start, -.76, z), (end, -.76, z)), ((end, -.76, z), (end+.30, -.76, z+.31)),
                             ((end+.30, -.76, z+.31), (end+.30, -.76, z+.80))]:
                    mesh.rod(p, q, .13, 'brass' if j == 0 else 'gold', 8)
                for x in (start+.54, end-.62):
                    mesh.rod((x, -.76, z), (x+.18, -.76, z), .185, 'slate', 8)
            mesh.block(-half+.43, -half+1.50, -.83, -.53, 6.61, 8.57, 'slate', .055)
            mesh.block(-half+.56, -half+1.37, -.88, -.83, 6.82, 8.34, 'iron')
            mesh.block(-half+.65, -half+.96, -.90, -.88, 7.89, 8.08, 'gold')
        if gate:
            w = min(8.5, bay.span-3)
            mesh.block(-w/2-.12, w/2+.12, -.68, -.52, 8.16, 9.42, 'black')
            mesh.plate([(w/2, -.69, 8.19), (-w/2, -.69, 8.19), (-w/2, -.69, 9.37),
                       (w/2, -.69, 9.37)], 'gate'+bay.label[0])
        if gate:
            for sign in (-1, 1):
                x = sign*(half-side)
                # Mitred shoulders dress the frame inside its visible opening.
                for y in (-.57, .06):
                    mesh.rod((x, y, 6.89), (x-sign*.91, y, 7.79), .17, 'iron', 4)
                part(x-.31, x+.31, .02, .17, 4.87, 6.96, 'slate', True)
    if not proxy:
        for x in (-half+.26, half-.26):
            for z in (base+.6, limit-.36):
                mesh.rod((x, 0, z), (x, .095, z), .088, 'silver', 6)
        if stage == 'Light':
            for sign in (-1, 1):
                for j in range(4):
                    x = sign*(half*.48+j*.21)
                    z = limit-.19-j*.10
                    mesh.rod((x, .055, z), (x+sign*.31, .055, z-.2), .065, 'scorch', 4)
            # Paired jagged impact fans occupy both faces of the widest solid band.
            z = 8.70 if story == 1 else 17.53
            for face_y in ((.98, -.72) if gate else (.10, -.58)):
                for j in range(11):
                    angle = math.tau*j/11
                    c = math.cos(angle)
                    h = math.sin(angle)
                    x = c*.51
                    mesh.rod((x, face_y, z+h*.19), (c*(.88+(j % 3)*.24),
                             face_y, z+h*(.33+(j % 2)*.13)), .076, 'scorch', 4)
                mesh.rod((0, face_y-.016, z), (0, face_y+.016, z), .34, 'scorch', 9)
            if not gate and story == 1:
                part(-half*.78, half*.76, 0, .024, 2.19, 2.34, 'scorch', True)
        if stage == 'Heavy':
            for sign in (-1, 1):
                x = sign*half*.52
                part(x-.09, x+.09, 0, .09, head, limit, 'scorch', True)
    return mesh


def roof(bay, stage, proxy=False):
    mesh = Mesh()
    mesh.transform = bay.roof_point
    half = bay.span/2-.05
    high = bay.label in ('S1', 'S4', 'N1', 'N4', 'SE1', 'NE1', 'NW1', 'SW1', 'E1', 'E3', 'W1', 'W3')
    lift = 2.09 if high else .49
    zones = [(-half, -half*.51), (half*.51, half)] if stage == 'Heavy' else [(-half, half)]

    def strip(x0, x1, v0, v1, z0, z1, mat):
        for low, high_x in zones:
            a, b = max(x0, low), min(x1, high_x)
            if a >= b:
                continue
            xy = [(a, v0), (b, v0), (b, v1), (a, v1)]
            mesh.loft([(x, y, z0(y)) for x, y in xy], [(x, y, z1(y))
                      for x, y in xy], 'black' if proxy else mat)

    def top(v):
        return ROOF+.46+lift*(min(v/.31, 1, (1-v)/.19))
    for i, j in [(0, .31), (.31, .81), (.81, 1)]:
        strip(-half, half, i, j, lambda v: ROOF-.23, top, 'bone' if high else 'iron')
        if proxy:
            continue
        for a, b in [(-half, -half+.16), (half-.16, half)]:
            strip(a, b, i, j, top, lambda v: top(v)+.07, 'slate')
    if not proxy:
        strip(-half, half, .04, .14, top, lambda v: top(v)+.021, 'red' if high else 'slate')
        strip(-half, half, .94, .995, top, lambda v: top(v)+.065, 'slate')
        for x in (-half+.52, half-.52):
            strip(x-.22, x+.22, .83, .975, lambda v: top(v)+.08, lambda v: top(v)+.18, 'gold')
        # Recessed joint covers, perimeter capstones and visible fastener heads.
        for fraction in (-.43, .43):
            x = half*fraction
            for a, b in [(0, .31), (.31, .81), (.81, 1)]:
                strip(x-.026, x+.026, a, b, top, lambda v: top(v)+.024, 'slate')
        for x in (-half*.77, -half*.36, half*.36, half*.77):
            strip(x-.12, x+.12, .18, .207, top, lambda v: top(v)+.066, 'silver')
        strip(-half, half, .005, .027, lambda v: ROOF+.02, lambda v: ROOF+.33, 'slate')
        if stage != 'Heavy':
            for x in (-half*.81, half*.81):
                strip(x-.21, x+.21, .78, .905, lambda v: top(v)+.085, lambda v: top(v)+.23, 'gold')
                strip(x-.1, x+.1, .80, .834, lambda v: top(v)+.23, lambda v: top(v)+.26, 'iron')
        if high and stage != 'Heavy':
            for x in (-half*.45, half*.45):
                strip(x-half*.31, x+half*.31, .38, .76, top, lambda v: top(v)+.17, 'black')
                for i in range(7):
                    v = .405+i*.048
                    strip(x-half*.28, x+half*.28, v, v+.016, lambda v: top(v)+.17, lambda v: top(v)+.24, 'iron')
        if bay.label in ('S1', 'S4', 'N1', 'N4') and stage != 'Heavy':
            # Paired roof heat exchangers. Raised end caps and copper lines sit above the louvers.
            for x in (-half*.47, half*.47):
                for side in (-1, 1):
                    u = x+side*half*.285
                    strip(u-.11, u+.11, .37, .78, top, lambda v: top(v)+.42, 'bone')
                    strip(u-.13, u+.13, .41, .46, lambda v: top(v)+.42, lambda v: top(v)+.47, 'gold')
            for v in (.50, .65):
                strip(-half*.86, -half*.15, v, v+.014, lambda v: top(v)+.26, lambda v: top(v)+.31, 'brass')
        if high:
            strip(-half, half, .02, .14, lambda v: ROOF-.76, lambda v: ROOF-.59, 'red')
        if bay.gate and stage != 'Heavy':
            # The inclined fascia is legible to a viewer above the observation level.
            x0, x1 = -half*.82, half*.82
            v0, v1 = .045, .31
            strip(x0-.09, x1+.09, v0-.01, v1, lambda v: top(v)+.024, lambda v: top(v)+.085, 'black')
            mesh.plate([(x0, v0, top(v0)+.10), (x1, v0, top(v0)+.10),
                        (x1, v1, top(v1)+.10), (x0, v1, top(v1)+.10)], 'gate'+bay.label[0])
        if stage == 'Light':
            for i in range(5):
                strip(-half*.52+i*.18, -half*.49+i*.18, .38, .75-i*.038, top, lambda v: top(v)+.036, 'scorch')
        if stage == 'Heavy':
            for sign in (-1, 1):
                x = sign*.55*half
                strip(x-.13, x+.13, .33, .80, top, lambda v: top(v)+.04, 'scorch')
    return mesh


def fragments(technical):
    """Four small independent shard pivots per shell material for later debris binding."""
    entries = {}
    for family, skin in [('Wall', 'bone'), ('Roof', 'iron')]:
        names = []
        for index in range(4):
            m = Mesh()
            w = .58+.12*index
            corners = [(-w, -.30), (-.36, -.49), (w*.92, -.27), (w, .18), (-.17, .43)]
            m.loft([(x, y, -.095) for x, y in corners], [(x, y, .06+.08*x/w) for x, y in corners], skin)
            m.rod((-w, -.30, -.06), (-.36, -.49, .015), .04, 'scorch', 4)
            names.append(m.finish(f'{family}_Fragment_{index+1}',
                         technical, role='debris', family=family).name)
        entries[family] = names
    return entries


def build_panels(intact, technical):
    records = []
    for label, a, b, gate in BAYS:
        bay = Bay(label, a, b, gate)
        for kind, story in [('Wall', 1), ('Wall', 2), ('Roof', 2)]:
            ident = f'Warehouse_S0{story}_Radar_{kind}_{label}'
            pivot = bay.roof_point((0, .5, ROOF)) if kind == 'Roof' else bay.wall_point(
                (0, -.26, 4.8 if story == 1 else 14.3))
            make = (lambda stage, proxy: roof(bay, stage, proxy)) if kind == 'Roof' else (
                lambda stage, proxy: wall(bay, story, stage, proxy))
            record = {'id': ident, 'story': f'0{story}', 'surface': kind,
                      'pivotXYZ': [round(v, 5) for v in pivot], 'states': {}}
            for stage in ('Pristine', 'Light', 'Heavy'):
                visual = make(stage, False).finish(ident+'_'+stage, intact if stage ==
                                                   'Pristine' else technical, pivot, panelId=ident, appearance=stage, role='visual')
                proxy_stage = 'Heavy' if stage == 'Heavy' else 'Intact'
                proxy_name = ident+'_Proxy'+proxy_stage
                if stage != 'Light':
                    make(stage, True).finish(proxy_name, technical,
                                             pivot, panelId=ident, role='collision-query')
                record['states'][stage] = {'visual': visual.name, 'solid': proxy_name}
            record['states']['Total'] = {'visual': None, 'solid': None}
            records.append(record)
    return records
