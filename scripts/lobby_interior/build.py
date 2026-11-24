"""Build the editable waiting lobby, GLB, placement manifest and native review views.

Run in background Blender 5.3 with --python-exit-code 1. The working package
locations are derived from this script, so a clean temporary archive is supported.
Use --preview to render quick views in /tmp, or --no-render for geometry only.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile

import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import atelier as a
import rooms

ACCEPTED_GLB = "842661e46702b8730fc334026941069bb1c34341a74fb3fcb280aaff1ee7ad90"
SOURCE_NAME = "waiting-lobby.blend"
EXPORT_NAME = "waiting-lobby.glb"
PLACEMENT = "assembly.json"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def install_bust():
    """Reconstruct the approved 34 pieces and their skin without editing the P20 source."""
    assert sha(a.P20) == ACCEPTED_GLB, "P20 approval must match the exact imported GLB"
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(a.P20),import_pack_images=True)
    objects=set(bpy.data.objects)-before
    root,=[obj for obj in objects if obj.parent is None]
    assert root.name=="Lobby Bust · base center" and len(objects)==35
    for obj in objects:
        for col in list(obj.users_collection): col.objects.unlink(obj)
        a.C["Approved P20 bust"].objects.link(obj)
    root.parent=a.parent; root.location=(0,31.5,2.65)
    return root


def setup_views():
    a.section("Main saloon")
    views={
        "arrival":a.camera("A1 | Entrance-height composition",(0,-7.6,4.8),(0,32,10.0),18.0,(1280,736)),
        "spawn-view":a.camera("A1 | Exact waiting anchor eye",(0,0,4.8),(0,31.5,10),16.2,(1280,736)),
        "theater":a.camera("A2 | Movie theater aisle",(-47.5,16.2,4.8),(-47.5,45,7.12),28,(1280,736)),
        "gallery-east":a.camera("A2 | Portraits at north and east walls",(29.2,12.8,5.25),(54.0,38.9,7.7),17.2,(1280,736)),
        "gallery-south":a.camera("A2 | Portraits across the bench",(53.8,37.4,5.6),(43.6,13.0,7),22,(1280,736)),
        "circulation":a.camera("A3 | Horizontal section at six studs",(-2.5,18.5,100),(-2.5,18.5,0),38,(1440,900),148),
        "plan":a.camera("A3 | Connected halls",(17,-58,211),(-2,19,2),38,(1440,920),162),
    }
    views["circulation"].data.clip_start = 93.9
    for p in rooms.PAINTINGS: views["portrait-%d"%p["portrait"]]=bpy.data.objects[p["camera"]]
    return views


def guide(name,loc,size):
    obj=a.attach(name,None,loc,col=a.C["Placement guides"]);obj.empty_display_type='CUBE';obj.empty_display_size=.5
    obj.scale=size
    return obj


def metadata(root,views):
    return {
        "schema":1,"assembly":"Waiting Lobby","p20_sculpt_commit":"62cd82c27584da9c70b24d975e49cb1df646e3d6",
        "p20_glb_sha256":ACCEPTED_GLB,"p20_meshes":34,"p20_instances":1,
        "bust_transform_blender":{"translation":list(root.location),"rotation_xyz_degrees":[0,0,0],"scale":[1,1,1]},
        "units":"one Blender unit per Roblox stud","blender_to_site":"Roblox (520 + X, Z, -Y). Pivot at existing deck top under Lobby.",
        "pivot_blender":[0,0,0],"pivot_roblox":[520,0,0],"arrival_forward_blender":[0,1,0],
        "existing_deck_studs":[60,2,60],"existing_anchors_roblox":{"Lobby":[520,3,0],"Operator":[520,3,-15]},
        "floor_limits_blender_xy":{"Main":[-25,-13,25,49],"Movie Theater":[-70,9,-25,50],"Art Gallery":[25,9,65,49]},
        "door_centers_blender":[[-25,26,0],[25,26,0]],"nominal_opening_width_studs":16,"nominal_opening_height_studs":14.4,
        "aisle_edges_blender_x":[-51.95,-43.05],"gallery_bench_center_blender":[45,29,0],
        "collision_guidance":"Use continuous finished floor slabs and three room shells. Keep both modeled openings through all layers; reserve the central aisle and passages. Build obstacle proxies for dais, benches, seats and television console at P22 import.",
        "review_guides":{"avatar_body_studs":[4,4,6],"player_eye_height_studs":4.8,
                         "camera_clearance_fixture":{"trailing_distance_studs":6,"pitch_up_degrees":15,"radius_studs":0.45}},
        "export_selection":"All mesh geometry underneath Waiting Lobby | deck surface pivot, including the 34-part approved bust. Omit cameras, lights and placement guides.",
        "screen":{"mesh":"CRT | phosphor glass and aerial image","image":"aerial-screen.png",
                  "source_sha256":sha(a.SOURCE/"aerial-screen.png")},
        "paintings":sorted(rooms.PAINTINGS,key=lambda p:p["portrait"]),
        "review_cameras":{key:cam.name for key,cam in views.items()}
    }


def link_oil_portraits(path):
    """Link the four approved PNGs verbatim to keep the native master under 20 MiB.

    The Blender export gives each image a dedicated buffer view. Preserve all
    other payloads, rebase their offsets and use ordinary glTF relative URIs.
    Staged Studio batches embed only the images used by their own parts.
    """
    raw=path.read_bytes()
    size=struct.unpack_from("<I",raw,12)[0]
    doc=json.loads(raw[20:20+size])
    binary=raw[28+size:]
    linked=set()
    oils={Path(row["source"]).stem:a.ROOT/row["source"] for row in rooms.PAINTINGS
          if row["source"].endswith("-oil.png")}
    for image in doc["images"]:
        texture=oils.get(image["name"])
        if texture is None: continue
        index=image.pop("bufferView")
        view=doc["bufferViews"][index]
        start=view.get("byteOffset",0)
        assert binary[start:start+view["byteLength"]]==texture.read_bytes()
        image["uri"]=Path(os.path.relpath(texture,path.parent)).as_posix()
        linked.add(index)
    assert len(linked)==len(oils)==4
    views=[];reindexed={};out=bytearray()
    for index,view in enumerate(doc["bufferViews"]):
        if index in linked: continue
        start=view.get("byteOffset",0)
        out.extend(b"\0"*(-len(out)%4))
        views.append(dict(view,byteOffset=len(out)))
        reindexed[index]=len(views)-1
        out.extend(binary[start:start+view["byteLength"]])
    for entry in doc["accessors"]+doc["images"]:
        if "bufferView" in entry: entry["bufferView"]=reindexed[entry["bufferView"]]
    doc["buffers"][0]["byteLength"]=len(out)
    doc["bufferViews"]=views
    info=json.dumps(doc,ensure_ascii=False,separators=(",",":")).encode("utf-8")
    info+=b" "*(-len(info)%4);out.extend(b"\0"*(-len(out)%4))
    with path.open("wb") as f:
        f.write(struct.pack("<4sIIII",b"glTF",2,28+len(info)+len(out),len(info),0x4e4f534a))
        f.write(info);f.write(struct.pack("<II",len(out),0x004e4942));f.write(out)


def refresh_asset_hashes():
    """Refresh the package fingerprints while retaining authored provenance and IDs."""
    path=a.ROOT/"assets/manifest.json"
    manifest=json.loads(path.read_text())
    files=[a.SOURCE/SOURCE_NAME,a.EXPORT/EXPORT_NAME,a.SOURCE/PLACEMENT,a.SOURCE/"aerial-screen.png"]
    files.extend(a.ROOT/row["source"] for row in rooms.PAINTINGS if row["source"].endswith("-oil.png"))
    rows={row["local_path"]:row for row in manifest["assets"]}
    for file in files:
        rows[file.relative_to(a.ROOT).as_posix()]["sha256"]=sha(file)
    path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n")


def render(views,out,preview):
    scene=bpy.context.scene
    # Render the altered display art first so its latest proof is immediately available for review.
    first=("portrait-2","portrait-6","gallery-south","portrait-4","gallery-east")
    ordered=[k for k in first if k in views]+[k for k in views if k not in first]
    for key in ordered:
        cam=views[key]
        scene.camera=cam
        scene.render.resolution_x,scene.render.resolution_y=cam["image_size"]
        scene.render.resolution_percentage=48 if preview else 100
        scene.cycles.samples=(4 if preview else 14) if not key.startswith("portrait") else (3 if preview else 9)
        cut=key in ("plan","circulation")
        a.C["Room ceilings"].hide_render=cut
        if cut:
            world=scene.world.node_tree.nodes.get("Background")
            world.inputs[1].default_value=.65
        scene.render.filepath=str(out/("blender-oil-"+key+".jpg"))
        bpy.ops.render.render(write_still=True)
        if cut: world.inputs[1].default_value=.35
    a.C["Room ceilings"].hide_render=False


def build():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview",action="store_true");parser.add_argument("--no-render",action="store_true")
    parser.add_argument("--keep-manifest",action="store_true",help="Leave hash refresh to the integration owner.")
    opts=parser.parse_args(args)
    for folder in (a.SOURCE,a.EXPORT,a.VIEWS):folder.mkdir(parents=True,exist_ok=True)
    a.init(); scene=bpy.context.scene
    with tempfile.TemporaryDirectory(prefix="p21-original-swatches-") as tmp:
        a.surfaces(Path(tmp))
    a.image_mat("Aerial phosphor",a.SOURCE/"aerial-screen.png",.23,.6)
    rooms.main_room();rooms.theater();rooms.gallery()
    bust=install_bust(); views=setup_views()
    guide("Reference | old deck surface",(0,0,-1),(60,60,2));guide("Reference | Waiting body envelope",(0,0,3.05),(4,4,6))
    guide("Reference | Operator body envelope",(0,15,3.05),(4,4,6))
    a.C["Placement guides"].hide_viewport=True
    scene.world=bpy.data.worlds.new("Warm neutral room ambience");scene.world.use_nodes=True
    world=scene.world.node_tree.nodes.get("Background");world.inputs[0].default_value=(.4,.42,.44,1);world.inputs[1].default_value=.35
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=14
    scene.cycles.max_bounces=6;scene.cycles.use_denoising=True
    scene.view_settings.exposure=-.8
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=93
    scene.camera=views["arrival"];scene.render.resolution_x,scene.render.resolution_y=views["arrival"]["image_size"]
    scene.render.resolution_percentage=100
    bpy.context.view_layer.update()
    # Save in the entrance camera so opening a closed, roofed building shows its interior.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                sp=area.spaces.active;sp.region_3d.view_perspective='CAMERA';sp.region_3d.view_camera_zoom=0
                sp.region_3d.view_distance=34;sp.region_3d.view_location=(0,27,9)
                sp.overlay.show_overlays=False;sp.shading.color_type='TEXTURE'
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active=a.parent
    if opts.preview:
        preview=Path("/tmp/p21-lobby-preview");preview.mkdir(exist_ok=True)
        render({k:v for k,v in views.items() if not k.startswith("portrait")},preview,True)
        return
    bpy.ops.wm.save_as_mainfile(filepath=str(a.SOURCE/SOURCE_NAME),compress=True)
    for obj in (a.parent,*a.parent.children_recursive):
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(a.EXPORT/EXPORT_NAME),export_format='GLB',use_selection=True,
                             export_yup=True,export_apply=True,export_cameras=False,export_lights=False,
                             export_animations=False,export_extras=False)
    link_oil_portraits(a.EXPORT/EXPORT_NAME)
    (a.SOURCE/PLACEMENT).write_text(json.dumps(metadata(bust,views),indent=2,ensure_ascii=False)+"\n")
    if not opts.keep_manifest: refresh_asset_hashes()
    print("P22_OIL_PACKAGE_EXPORTED",flush=True)
    updates=("gallery-east","gallery-south","portrait-2","portrait-3","portrait-4","portrait-6")
    if not opts.no_render: render({key:views[key] for key in updates},a.VIEWS,False)


if __name__=="__main__":build()
