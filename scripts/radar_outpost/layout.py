"""Local stud coordinates, blockout boundaries and routes for the Warehouse site."""
from math import atan2, cos, sin, tau
from itertools import pairwise

SITE = (160, .125, -80)
OUTLINE = [(-25, -24), (25, -24), (32, -17), (32, 17), (25, 24),
           (-25, 24), (-32, 17), (-32, -17)]
# Between the stairs the balcony bows around the dish. Both high landings
# meet a straight deck edge, so there is no crescent-shaped gap at the top.
WELL = [(-22.7, -15), (-14.3, -15), (-10, -16.4), (-5, -17.2), (0, -17.45),
        (5, -17.2), (10, -16.4), (14.3, -15), (22.7, -15), (22.7, 15),
        (14.3, 15), (10, 16.4), (5, 17.2), (0, 17.45), (-5, 17.2),
        (-10, 16.4), (-14.3, 15), (-22.7, 15)]
UPPER = 10
ROOF = 18.65
STAIRS = [("West", -18.5, 1), ("East", 18.5, -1)]
STAIR_WIDTH = 8
STEPS = 16
RUN = 30 / STEPS
RISE = UPPER / STEPS
# Segments follow the perimeter counterclockwise; the building is on the left.
BAYS = []


def side(label, points, gate=None):
    for index, (a, b) in enumerate(pairwise(points), 1):
        BAYS.append((label+str(index), a, b, index == gate))


side('S', [(-25, -23.25), (-13, -23.25), (0, -23.25), (16, -23.25), (25, -23.25)], 3)
side('SE', [(25, -23.25), (31.25, -17)])
side('E', [(31.25, -17), (31.25, -6.5), (31.25, 6.5), (31.25, 17)], 2)
side('NE', [(31.25, 17), (25, 23.25)])
side('N', [(25, 23.25), (13, 23.25), (0, 23.25), (-16, 23.25), (-25, 23.25)], 3)
side('NW', [(-25, 23.25), (-31.25, 17)])
side('W', [(-31.25, 17), (-31.25, 6.5), (-31.25, -6.5), (-31.25, -17)], 2)
side('SW', [(-31.25, -17), (-25, -23.25)])


def radial(poly, angle):
    """Intersect a center ray with a convex perimeter in the XY plane."""
    x, y = cos(angle), sin(angle)
    for a, b in zip(poly, poly[1:]+poly[:1]):
        dx, dy = b[0]-a[0], b[1]-a[1]
        det = x*dy-y*dx
        if abs(det) < 1e-8:
            continue
        t = (a[0]*dy-a[1]*dx)/det
        u = (a[0]*y-a[1]*x)/det
        if t > 0 and -1e-6 <= u <= 1+1e-6:
            return (t*x, t*y)
    raise ValueError(angle)


def gallery_wedges():
    angles = sorted({round(atan2(y, x) % tau, 8) for x, y in OUTLINE+WELL})
    for a, b in zip(angles, angles[1:]+angles[:1]):
        yield [radial(OUTLINE, a), radial(OUTLINE, b), radial(WELL, b), radial(WELL, a)]


if __name__ == '__main__':
    assert BAYS[2][1:] == ((0, -23.25), (16, -23.25), True)
    assert len(list(gallery_wedges())) >= len(WELL)
    assert STEPS*RISE == UPPER and STEPS*RUN == 30
    assert 32-22.7-1 > 8 and 24-17.45-.7 > 5.5
    print("64 x 48 studs; Warehouse south approach x=8; four gates; two 8-wide flights; upper at +10.")
