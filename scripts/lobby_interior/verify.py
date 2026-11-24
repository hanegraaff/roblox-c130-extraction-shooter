"""Reopen the P21 source and reimport its clean GLB using Blender 5.3.

Run with blender -b --python-exit-code 1 --python scripts/lobby_interior/verify.py
and optionally add -- --report /path/to/report.json after the script name.
This is a read-only check against the approved P20 geometry and the supplied
portrait bytes. Clearance uses the actual meshes in both Blender scenes.
"""
from hashlib import sha256
import json
from math import ceil, cos, radians, sin, tan
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/blender/lobby-interior/waiting-lobby.blend"
EXPORT = ROOT / "assets/exports/lobby-interior/waiting-lobby.glb"
CATALOG = ROOT / "assets/blender/lobby-interior/assembly.json"
BUST = ROOT / "assets/exports/lobby-bust/lobby-bust.glb"
P20_DIGEST = "842661e46702b8730fc334026941069bb1c34341a74fb3fcb280aaff1ee7ad90"
PIVOT = "Waiting Lobby | deck surface pivot"
BUST_PIVOT = "Lobby Bust · base center"
EPS = .001
# Shared ceiling camera probes face the indicated heading. At each the camera
# sits six studs behind the target and 15 degrees above its 4.8-stud eye.
CAMERA_STATIONS = (
    ((0,0),(0,1)),((0,15),(0,1)),
    ((-25,26),(-1,0)),((-25,26),(1,0)),((25,26),(1,0)),((25,26),(-1,0)),
    ((-47.5,26),(0,1)),((-47.5,26),(0,-1)),
    ((36.4,35.5),(0,1)),((57,35.5),(1,0)),((53,18.5),(0,-1))
)
# The outer cross aisle behind the last row has less room than the center aisle.
# The path deliberately goes around the installed seats and the gallery bench.
ROUTES = {
    "waiting_to_operator":[(0,0),(0,15)],
    "operator_to_cinema_front":[(0,15),(-11.5,21.5),(-17,26),(-25,26),(-30.4,26),(-30.4,11.78),
                                (-47.5,11.78),(-47.5,38.7)],
    "operator_to_gallery_north":[(0,15),(11.5,21.5),(17,26),(25,26),(32.5,26),(32.7,36.5),
                                 (36.0,41.6),(54.5,41.6)],
    "gallery_to_south_paintings":[(54.5,41.6),(59.2,37.6),(59.2,18.3),
                                  (54.2,15.2),(35.9,15.2),(31.8,22),(25,26)]
}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def site_and_inputs(catalog):
    """Bind clearance to the actual protected deck and the six distinct original JPEG files."""
    world=json.loads((ROOT/"assets/world/Battlefield.model.json").read_text())
    by_name={child["Name"]:child for child in world["Children"]}
    anchors={c["Name"]:c["Properties"]["CFrame"][:3] for c in by_name["Anchors"]["Children"]}
    deck=next(o["Properties"] for o in by_name["LobbyStation"]["Children"] if o["Name"]=="LobbyDeck")
    assert anchors["Lobby"]==catalog["existing_anchors_roblox"]["Lobby"] and anchors["Operator"]==catalog["existing_anchors_roblox"]["Operator"]
    assert deck["Size"]==catalog["existing_deck_studs"]
    x,y,z=deck["CFrame"][:3]
    assert catalog["pivot_roblox"]==[x,y+deck["Size"][1]/2,z]
    assert catalog["p20_instances"]==1 and catalog["p20_sculpt_commit"].startswith("62cd82c")
    portraits=catalog["paintings"]
    assert len(portraits)==6 and {p["portrait"] for p in portraits}==set(range(1,7))
    assert len({p["source_sha256"] for p in portraits})==6
    for p in portraits:
        assert p["source"]==f'src/images/redesigned-lobby/portrait-{p["portrait"]}.jpeg'
        assert p["material"]==f'Canvas {p["portrait"]:02d} | supplied portrait'
        assert p["canvas"]==f'Portrait {p["portrait"]:02d} | canvas'


def raw_glb(catalog):
    """Verify clean static nodes, self-contained texture payloads and render budgets."""
    data=EXPORT.read_bytes()
    magic,version,size,jlen,kind=struct.unpack_from("<4sIIII",data)
    assert magic==b"glTF" and version==2 and size==len(data) and kind==0x4e4f534a
    g=json.loads(data[20:20+jlen]); buf=data[28+jlen:]
    assert len(g["buffers"])==1 and "uri" not in g["buffers"][0]
    assert not ({"animations","skins","cameras"} & g.keys())
    assert "KHR_lights_punctual" not in g.get("extensionsUsed",[])
    assert len(g["scenes"])==1 and len(g["scenes"][0]["nodes"])==1
    assert g["nodes"][g["scenes"][0]["nodes"][0]]["name"]==PIVOT
    hashes={}
    for im in g["images"]:
        assert "uri" not in im
        view=g["bufferViews"][im["bufferView"]];start=view.get("byteOffset",0)
        hashes[im["name"]]=sha256(buf[start:start+view["byteLength"]]).hexdigest()
    assert hashes["aerial-screen"]==catalog["screen"]["source_sha256"]
    for p in catalog["paintings"]:
        assert hashes["portrait-%d"%p["portrait"]]==p["source_sha256"]==digest(ROOT/p["source"])
    # Every index exported is a triangle index. Count reused kit meshes once
    # for storage and once per node for a realistic assembled triangle total.
    tri=[sum(g["accessors"][p["indices"]]["count"]//3 for p in m["primitives"]) for m in g["meshes"]]
    assert all(0<n<20000 for n in tri)
    assert SOURCE.stat().st_size<20*1024**2 and EXPORT.stat().st_size<20*1024**2
    return {"nodes":len(g["nodes"]),"mesh_objects":sum("mesh" in n for n in g["nodes"]),
            "unique_meshes":len(tri),"materials":len(g["materials"]),"embedded_images":len(hashes),
            "assembled_triangles":sum(tri[n["mesh"]] for n in g["nodes"] if "mesh" in n),
            "unique_triangles":sum(tri),"largest_mesh_triangles":max(tri),
            "source_bytes":SOURCE.stat().st_size,"export_bytes":len(data)}


def import_glb(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path),import_pack_images=True)
    bpy.context.view_layer.update()


def mesh_parts(root):
    return {p.name:p for p in root.children_recursive if p.type=="MESH"}


def bust_points(root):
    """Return real mesh positions in the approved prop's local coordinates."""
    inv=root.matrix_world.inverted()
    data={}
    for name,obj in mesh_parts(root).items():
        m=obj.data;m.calc_loop_triangles()
        matrix=inv@obj.matrix_world
        data[name]={"coords":[matrix@v.co for v in m.vertices],"triangles":len(m.loop_triangles),
                    "materials":sorted(mat.name for mat in m.materials)}
    assert len(data)==34
    return data


def approve_bust(ref,root):
    assert (root.location-Vector((0,31.5,2.65))).length<EPS
    assert max(abs(v-1) for v in root.scale)<EPS
    assert sum(abs(v) for v in root.rotation_euler)<EPS
    actual=bust_points(root); assert set(actual)==set(ref)
    discrepancy=0.
    for name,baseline in ref.items():
        current=actual[name]
        assert baseline["triangles"]==current["triangles"] and baseline["materials"]==current["materials"], name
        for src,dst in ((baseline["coords"],current["coords"]),(current["coords"],baseline["coords"])):
            tree=KDTree(len(dst))
            for i,p in enumerate(dst):tree.insert(p,i)
            tree.balance()
            largest=max(tree.find(p)[2] for p in src)
            assert largest<EPS,(name,largest)
            discrepancy=max(discrepancy,largest)
    return discrepancy


def arch_facing(part):
    """Test outward winding of both axial faces and both radial lips on the real arch mesh."""
    mesh=part.data
    mesh.calc_loop_triangles()
    verts=[part.matrix_world@v.co for v in mesh.vertices]
    tris=[tuple(t.vertices) for t in mesh.loop_triangles]
    origin=verts[0]
    rel=[v-origin for v in verts]
    volume=sum(rel[i].dot(rel[j].cross(rel[k])) for i,j,k in tris)/6
    assert volume>0,(part.name,"nonpositive closed arch volume",volume)
    bvh=BVHTree.FromPolygons(verts,tris,all_triangles=True)
    outer=max(v.z for v in verts)-8.3
    inner=min(abs(v.x+47.5) for v in verts if abs(v.z-8.3)<EPS)
    front=min(v.y for v in verts);back=max(v.y for v in verts)
    center=Vector((-47.5,(front+back)/2,8.3))
    hits=0
    for degrees in (13,36,61,88,112,139,167):
        angle=radians(degrees);radial=Vector((cos(angle),0,sin(angle)))
        mid=center+radial*((outer+inner)/2)
        across=Vector((0,1,0))
        for origin,direction in ((mid-across,across),(mid+across,-across),
                                 (center+radial*(outer+1),-radial),(center+radial*(inner-1),radial)):
            point,normal,face,_=bvh.ray_cast(origin,direction,2.5)
            assert face is not None and normal.dot(direction)<-.98,(part.name,degrees,normal)
            hits+=1
    return {"signed_volume":round(volume,4),"outward_first_hits":hits}


def auth_scene(root,catalog,reference):
    """Measure all object bounds, then prove canvas UV orientation, dimensions and bytes."""
    graph=bpy.context.evaluated_depsgraph_get()
    source_parts=mesh_parts(root)
    bounds={};areas={};totals={}
    for name,obj in source_parts.items():
        evaluated=obj.evaluated_get(graph)
        # The saved object can use Euler rotation while glTF reimports a quaternion.
        # Transform real vertices in both cases, including bevels on diagonal forms.
        world=evaluated.matrix_world
        coords=[world@v.co for v in evaluated.data.vertices]
        lo=[min(p[i] for p in coords) for i in range(3)]
        hi=[max(p[i] for p in coords) for i in range(3)]
        bounds[name]=lo+hi
        mesh=evaluated.data;mesh.calc_loop_triangles()
        totals[name]=len(mesh.loop_triangles)
    assert set(o.name for o in root.children_recursive if o.type=="EMPTY")=={BUST_PIVOT}
    assert sum(o.name==BUST_PIVOT for o in bpy.context.scene.objects)==1
    bust_delta=approve_bust(reference,bpy.data.objects[BUST_PIVOT])
    for p in catalog["paintings"]:
        obj=source_parts[p["canvas"]];mat,=list(obj.data.materials)
        assert mat.name==p["material"] and len([n for n in source_parts if n.startswith(p["frame_prefix"])])>=12
        image,=[n.image for n in mat.node_tree.nodes if n.type=="TEX_IMAGE"]
        assert image.packed_file and sha256(image.packed_file.data).hexdigest()==p["source_sha256"]
        assert tuple(image.size)==tuple(p["raster_px"])
        uv=obj.data.uv_layers.active.data;world=obj.matrix_world
        points={}
        for f in obj.data.polygons:
            normal=(world.to_3x3()@f.normal).normalized()
            for i in f.loop_indices:
                key=tuple(round(v,3) for v in uv[i].uv)
                points[key]=world@obj.data.vertices[obj.data.loops[i].vertex_index].co
        assert set(points)=={(0,0),(1,0),(1,1),(0,1)}
        # Map three labelled display corners back into the source raster. For the
        # three EXIF-6 sources the left edge becomes the physical top.
        is_turned=p["portrait"] in (2,4,6)
        assert p["clockwise_degrees"]==(90 if is_turned else 0)
        orientation=list(image.size)[::-1] if is_turned else list(image.size)
        assert p["display_raster_px"]==orientation
        bl,br,tl=((1,0),(1,1),(0,0)) if is_turned else ((0,0),(1,0),(0,1))
        right=points[br]-points[bl];up=points[tl]-points[bl]
        assert up.normalized().z>.9999 and abs(right.z)<EPS
        assert right.cross(up).normalized().dot(normal)>.9999
        w,h=p["size_studs"]; assert abs(w-right.length)<EPS and abs(h-up.length)<EPS
        if is_turned:
            assert abs(w-7.65)<EPS and abs(h-10.20)<EPS
        assert abs(right.length/up.length-orientation[0]/orientation[1])<EPS
        center=sum(points.values(),Vector((0,0,0)))*.25
        assert (center-Vector(p["center_blender"])).length<EPS
        areas[p["portrait"]]=round(right.length*up.length,3)
    # Packed source image data are sufficient even if a scratch path was deleted after the build.
    assert not bpy.data.libraries
    for im in bpy.data.images:
        if im.type=="IMAGE" and im.source=="FILE":
            assert im.packed_file,(im.name,im.filepath)
    arches={name:arch_facing(source_parts[name]) for name in ("Proscenium arch","Proscenium brass ribbon")}
    return bounds,totals,bust_delta,areas,arches


def ray(origin,direction,distance=300):
    return bpy.context.scene.ray_cast(bpy.context.evaluated_depsgraph_get(),
                                      Vector(origin),Vector(direction),distance=distance)


def assert_clear(origin,end,label):
    vec=Vector(end)-Vector(origin)
    result=ray(origin,vec.normalized(),vec.length)
    assert not result[0],(label,result[4].name,tuple(round(v,2) for v in origin),tuple(round(v,2) for v in result[1]))


def actual_width(x,y,z):
    distances=[]
    for dy in (-1,1):
        hit=ray((x,y,z),(0,dy,0));assert hit[0]
        distances.append(abs(hit[1].y-y))
    return round(sum(distances),3)


def clearance(catalog):
    """Sweep the body's horizontal sections over continuous floor support at 0.60-stud intervals."""
    counts={}
    for name,path in ROUTES.items():
        n=0
        for a,b in zip(path,path[1:]):
            begin,end=Vector(a),Vector(b)
            steps=ceil((end-begin).length/.60)
            for j in range(steps+1):
                x,y=begin.lerp(end,j/steps)
                for dx,dy in ((0,0),(-1.92,-1.92),(-1.92,1.92),(1.92,-1.92),(1.92,1.92)):
                    hit=ray((x+dx,y+dy,.24),(0,0,-1),.63)
                    if hit[0] and hit[2].z < .90:
                        # A ray exactly on the 0.018-stud tile chamfer may hit its
                        # steep lip. The continuous structural mortar lies below it.
                        hit=ray((x+dx,y+dy,hit[1].z-.0003),(0,0,-1),.075)
                    assert hit[0] and hit[2].z>.9,(name,"unsupported",x+dx,y+dy)
                for z in (.30,1.63,3,5.90):
                    for off in(-1.98,0,1.98):
                        assert_clear((x-2,y+off,z),(x+2,y+off,z),name)
                        assert_clear((x+off,y-2,z),(x+off,y+2,z),name)
                n+=1
        counts[name]=n
    for (x,y),(dx,dy) in CAMERA_STATIONS:
        start=Vector((x,y,4.8));finish=start+Vector((-dx*6,-dy*6,6*tan(radians(15))))
        for offset in ((0,0,0),(-.45,0,0),(.45,0,0),(0,-.45,0),(0,.45,0),(0,0,.45),(0,0,-.45)):
            assert_clear(start+Vector(offset),finish+Vector(offset),"Camera 6 stud follow")
    portals={}
    for side in(-25,25):
        hit=ray((side,26,.2),(0,0,1));assert hit[0]
        width=min(actual_width(x,26,z) for x in (side-.23,side,side+.23) for z in(1.,3.,5.9))
        height=round(hit[1].z,3)
        assert abs(width-15.740)<EPS and abs(height-14.375)<EPS,(side,width,height)
        portals[str(side)]={"sampled_body_width_studs":width,"center_headroom_studs":height}
    x,y=-47.5,27.16
    left=ray((x,y,1.3),(-1,0,0));right=ray((x,y,1.3),(1,0,0))
    assert "arm" in left[4].name.lower() and "arm" in right[4].name.lower()
    aisle=round(right[1].x-left[1].x,3);assert aisle>=8.4
    # Anchor camera sightline to the actual eyes. The face or approved glasses may be the
    # first surface on this ray because pupils sit in carved eye sockets.
    eyes=[]
    for eye in (p for p in bpy.data.objects if p.name.startswith("06 | Pupil")):
        center=eye.matrix_world@(sum((Vector(pt) for pt in eye.bound_box),Vector((0,0,0)))/8)
        start=Vector((0,0,4.8));vec=center-start;hit=ray(start,vec.normalized(),vec.length+.4)
        assert hit[0] and hit[4].name.startswith(("05","06","09")),(eye.name,hit[4].name)
        eyes.append(hit[4].name)
    assert len(eyes)==2
    viewing={}
    for p in catalog["paintings"]:
        obj=bpy.data.objects[p["canvas"]]
        center=Vector(p["center_blender"])
        normal=(obj.matrix_world.to_3x3()@obj.data.polygons[0].normal).normalized()
        eye=center+11.018*normal;eye.z=4.8
        towards=center-eye;hit=ray(eye,towards.normalized(),towards.length+.05)
        assert hit[0] and hit[4].name==obj.name,(obj.name,hit[4].name)
        for z in (.3,3.,5.9):
            for off in(-1.98,0,1.98):
                assert_clear((eye.x-2,eye.y+off,z),(eye.x+2,eye.y+off,z),"Gallery viewing pocket")
                assert_clear((eye.x+off,eye.y-2,z),(eye.x+off,eye.y+2,z),"Gallery viewing pocket")
        viewing[p["portrait"]]=round((eye.xy-center.xy).length,3)
    return {"body_stations":counts,"body_envelope_studs":[4,4,6],"camera_stations":len(CAMERA_STATIONS),
            "camera_distance_studs":6,"camera_radius_studs":.45,"doorways":portals,
            "theater_aisle_studs":aisle,"waiting_eye_first_hits":eyes,
            "gallery_player_viewing_distance_studs":viewing}


def main():
    catalog=json.loads(CATALOG.read_text());assert digest(BUST)==catalog["p20_glb_sha256"]==P20_DIGEST
    for p in (SOURCE,EXPORT,CATALOG):
        manifest=json.loads((ROOT/"assets/manifest.json").read_text())
        exact=[row for row in manifest["assets"] if row["local_path"]==str(p.relative_to(ROOT))]
        assert len(exact)==1 and exact[0]["sha256"]==digest(p)
    site_and_inputs(catalog)
    stats=raw_glb(catalog)
    import_glb(BUST);reference=bust_points(bpy.data.objects[BUST_PIVOT])
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene=bpy.context.scene
    assert {o.name for o in scene.objects if o.type=='CAMERA'}==set(catalog["review_cameras"].values())
    actual_anchor=bpy.data.objects[catalog["review_cameras"]["spawn-view"]].location
    assert (actual_anchor-Vector((0,0,4.8))).length<EPS
    b1,t1,d1,areas,arches=auth_scene(bpy.data.objects[PIVOT],catalog,reference)
    walk=clearance(catalog)
    import_glb(EXPORT)
    scene=bpy.context.scene; assert all(o.type in("MESH","EMPTY") for o in scene.objects)
    root,=[obj for obj in scene.objects if obj.parent is None];assert root.name==PIVOT
    b2,t2,d2,areas2,arches2=auth_scene(root,catalog,reference)
    assert walk==clearance(catalog) and areas==areas2 and arches==arches2
    assert t1==t2 and set(b1)==set(b2),("source/GLB object triangle sets differ",set(t1)^set(t2))
    for name,coords in b1.items():
        assert max(abs(a-b) for a,b in zip(coords,b2[name]))<EPS,(name,coords,b2[name])
    report={"blender":bpy.app.version_string,"source_sha256":digest(SOURCE),"export_sha256":digest(EXPORT),
            "approved_bust_sha256":P20_DIGEST,"bust_max_vertex_delta_studs":{"source":d1,"glb":d2},
            "proscenium_facing_source_and_glb":arches,"gallery_canvas_area_sq_studs":areas,"source_and_glb_routes":walk,"inventory":stats}
    if "--report" in sys.argv:
        Path(sys.argv[sys.argv.index("--report")+1]).write_text(json.dumps(report,indent=2)+"\n")
    print("P21_REOPEN_REIMPORT_AND_CLEARANCE_PASS",flush=True)
    print(json.dumps(report,indent=2))


if __name__=="__main__":main()
