"""Author the battlefield's flat, four-stud terrain paint and navigable road network.

Coordinates are world X/Z studs, north is -Z. Run this file to update only the
district-owned folders/properties in the source map. No mesh or texture is generated.
"""
import copy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / "assets/world/Battlefield.model.json"
# The exterior circuit stays beyond Sandbreak's four wreck/relay yards. Each
# portal joins it on axis; all three signed approaches share this circuit.
TRACKS = {
    "Circuit": [(0, 65), (42, 66), (67, 83), (73, 120), (69, 157), (49, 177),
                (0, 178), (-47, 177), (-68, 155), (-73, 120), (-69, 85), (-45, 67), (0, 65)],
    "NorthExit": [(0, 96), (0, 65)], "EastExit": [(31, 120), (73, 120)],
    "SouthExit": [(0, 145), (0, 178)], "WestExit": [(-31, 120), (-73, 120)],
    # Approach the eastern hangar door along its clear local +Z apron aisle, away from the wreck.
    "Hangar": [(-69, 85), (-72, 56), (-64, 23), (-41, -10), (-34, -42),
               (-48, -78), (-70, -95), (-122.083, -124.708)],
    "Radar": [(42, 66), (63, 48), (93, 41), (120, 28), (147, 5), (166, -19), (168, -57)],
    "Depot": [(69, 157), (91, 166), (113, 177), (127, 194), (152, 199), (152, 188)],
}
# Existing integrated shell spans 214 x 148 studs. Keep the south survey clear.
RESERVE = (-106, 106, 186, 332)
SITES = {"LauncherRadar": (174, 3, -42), "LauncherHangar": (-131.31, 3.125, -130.04),
         "LauncherDepot": (157, 3, 198)}
MATERIALS = {"s": "Sand", "t": "Sandstone", "d": "Ground", "p": "Cobblestone",
             "g": "Grass", "l": "LeafyGrass", "a": "Asphalt", "v": "Pavement", ".": "Air"}


PALETTE = {"Sand": (222, 191, 132), "Sandstone": (197, 161, 110), "Ground": (165, 138, 97),
           "Grass": (122, 144, 91), "LeafyGrass": (90, 122, 82), "Cobblestone": (155, 145, 124),
           "Asphalt": (87, 85, 82), "Pavement": (139, 134, 126)}


def line_distance(x, z, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    fraction = max(0, min(1, ((x-a[0])*dx + (z-a[1])*dz) / (dx*dx + dz*dz)))
    return math.hypot(x-a[0]-fraction*dx, z-a[1]-fraction*dz)


def distance(x, z, route):
    return min(line_distance(x, z, a, b) for a, b in zip(route, route[1:]))


ROAD = [(79, 100), (107, 106), (140, 118), (185, 127), (208, 147), (212, 185), (225, 218)]
SEGMENTS = [(a,b) for route in TRACKS.values() for a,b in zip(route,route[1:])]


def paint(x, z):
    if math.hypot(x, z) > 360:
        return "."
    if RESERVE[0] <= x <= RESERVE[1] and RESERVE[2] <= z <= RESERVE[3]:
        return "s"
    # Long undulations break the biome edge; short ripples introduce gravel,
    # loam and sparse grass in the transition instead of a straight seam.
    broad = 0.52*math.sin(x/34+z/41) + 0.32*math.cos(z/17-x/49) + 0.16*math.sin(x/11+z/15)
    grit = math.sin(0.19*x+0.13*z) * math.cos(0.11*z-0.08*x)
    forest = math.hypot((x-170)/198, (z+111)/192) - 0.125*broad
    urban = math.hypot((x-178)/139, (z-151)/112) - 0.12*broad
    road = distance(x, z, ROAD)
    lot = max(abs(x-180)-21, abs(z-192)-25)
    if road < 9 + grit or lot < -1 + grit:
        return "p" if broad > 0.62 and grit > 0.3 else "a"
    if road < 13+broad or lot < 2+broad:
        return "v" if grit > -0.25 else "p"
    trail = min(line_distance(x,z,a,b) for a,b in SEGMENTS)
    if trail < 5.7 + 0.9*grit:
        if forest < 1.05:
            return "d" if grit < .7 else "p"
        if urban < 1.15:
            return "p" if broad < .55 else "d"
        return "d" if broad > -.55 else "p"
    if forest < 0.83:
        return "l" if broad > 0.14 else "g"
    if forest < 1.16:
        return "d" if forest + grit*0.09 > 1.01 else "g"
    if urban < 0.83:
        return "p" if broad < .3 else "d"
    if urban < 1.14:
        return "d" if broad + grit*0.12 > -.15 else "s"
    return "t" if broad > 0.67 else "s"


def part(template, name, x, y, z, size, color=None, yaw=0):
    item = copy.deepcopy(template)
    item["Name"] = name
    props = item["Properties"]
    angle = math.radians(yaw)
    c,s = math.cos(angle),math.sin(angle)
    props.update(CFrame=[x,y,z,c,0,s,0,1,0,-s,0,c],Size=size)
    if color:
        props.update(Color=color, Transparency=0, Material="Concrete", CastShadow=False)
    return item


def update():
    world = json.loads(WORLD.read_text())
    nodes = {v["Name"]:v for v in world["Children"]}
    disk = nodes["GroundDisk"]["Properties"]
    # Keep the exact physical disk for containment. Runtime hides the Edit-mode sand preview.
    disk.update(Material="Sand", Color=[0.81,0.68,0.45])
    for segment in nodes["Boundary"]["Children"]:
        segment["Properties"].update(Transparency=0.84, CastShadow=False)
    recipe = nodes["TerrainRecipe"]
    rows = ["".join(paint(x,z) for z in range(-358,360,4)) for x in range(-358,360,4)]
    recipe["Children"] = [recipe["Children"][0], {"Name":"SurfaceRaster","ClassName":"StringValue",
                                                    "Properties":{"Value":"\n".join(rows), "Attributes":{key:{"Color3":[n/255 for n in value]} for key,value in PALETTE.items()}}}]
    anchors = nodes["Anchors"]["Children"]
    template = next(a for a in anchors if a["Name"].startswith("Launcher"))
    anchors[:] = [a for a in anchors if not a["Name"].startswith("Launcher")]
    for name,(x,y,z) in SITES.items():
        anchors.append(part(template,name,x,y,z,[1,0.2,1]))
    marks = []
    for i,x in enumerate((RESERVE[0],RESERVE[1])):
        for j,z in enumerate((RESERVE[2],RESERVE[3])):
            # Short inward-facing survey brackets leave the pad entirely walkable.
            color = [0.62,0.31,0.12]
            marks += [part(template,f"Survey{i}{j}X",x+(1-2*i)*4,.12,z,[8,.06,.8],color),
                      part(template,f"Survey{i}{j}Z",x,.12,z+(1-2*j)*4,[.8,.06,8],color)]
    reserve = nodes.get("SouthBuildingReserve")
    if reserve is None:
        reserve = {"Name":"SouthBuildingReserve", "ClassName":"Model"}
        world["Children"].append(reserve)
    reserve["Properties"] = {"Attributes":{"WidthStuds":{"Float64":212},"DepthStuds":{"Float64":146}}}
    reserve["Children"], marks = marks, []
    for i in range(5):
        for j in range(2):
            marks.append(part(template,f"BayStripe{i}{j}",166+j*24,.10,172+i*9,
                              [10-(i+j)%3,.06,.28],[.68,.65,.52]))
    for i,(a,b) in enumerate(zip(ROAD,ROAD[1:])):
        length=math.dist(a,b)
        for j in range(int(length/13)):
            t=(j+.5)/int(length/13)
            marks.append(part(template,f"RoadDash{i}_{j}",a[0]+t*(b[0]-a[0]),.10,
                              a[1]+t*(b[1]-a[1]),[.42,.06,4+(i+j)%3],[.65,.51,.24],
                              math.degrees(math.atan2(b[0]-a[0],b[1]-a[1]))))
    nodes["Routes"]["Children"] = marks
    WORLD.write_text(json.dumps(world,indent=2)+"\n")


if __name__ == "__main__":
    update()
