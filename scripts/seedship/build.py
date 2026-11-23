"""Build the review scene, portable assembly and independently selectable damage library."""
import json
import math
from pathlib import Path
import sys
import tempfile

import bpy

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path[:0]=[str(HERE),str(HERE.parent/'radar_outpost')]
from meshwork import collection
from form import Mesh
import decks
import diagnostics
import equipment
import specimen
import hull
import relics
import review
import surfaces

SOURCE=ROOT/'assets/blender/alien-spaceship'
EXPORT=ROOT/'assets/exports/alien-spaceship'


def export(path,groups,include=lambda obj: True):
    bpy.ops.object.select_all(action='DESELECT')
    for g in groups:
        for obj in g.objects:
            if include(obj):
                obj.select_set(True)
    result=bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                                     export_extras=True,export_yup=True,export_cameras=False,export_lights=False)
    assert result=={'FINISHED'},path


def fragments(group):
    names=[]
    for i in range(4):
        m=Mesh()
        pts=[(-.92,-.30),(-.41,-.76),(.75,-.49),(1,.05),(.36,.68),(-.67,.49)]
        pts=[(x*(.61+i*.09),y*(.77+i*.08)) for x,y in pts]
        m.loft([(x*.91,y*.91,-.15) for x,y in pts],[(x,y,.13+.06*math.sin(j+i)) for j,(x,y) in enumerate(pts)],'raw')
        m.loft([(x,y,.13+.06*math.sin(j+i)) for j,(x,y) in enumerate(pts)],[(x*.91+.04,y*.89,.21+.05*math.sin(j+i)) for j,(x,y) in enumerate(pts)],'pearl')
        obj=m.finish(f'Nacre spall {i+1:02d}',group,Role='Fragment',ThermalNonCover=True)
        names.append(obj.name)
    return names


def main():
    SOURCE.mkdir(parents=True,exist_ok=True)
    EXPORT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    stable=collection('01 • Decks, stairs and stable supports')
    frame=collection('02 • Meridian shell frame')
    panels=collection('03 • Nacre hull panels')
    detail=collection('04 • Optical instruments and dressing')
    variants=collection('05 • Damage variants, proxies and spalls')
    stage=collection('06 • Review only')
    with tempfile.TemporaryDirectory() as tmp:
        surfaces.prepare(Path(tmp))
        diagnostics.prepare(Path(tmp))
        specimen.prepare_skin(Path(tmp))
    decks.decks(stable,detail)
    relics.furnish(stable,detail)
    equipment.build(detail)
    specimen.build(detail)
    records=hull.assemble(panels,frame,variants)
    decks.vaulting(frame,panels,frame)
    spalls=fragments(variants)
    bpy.context.view_layer.update()
    export(EXPORT/'prism-seedship.glb',[stable,frame,panels,detail])
    light=lambda obj: obj.get('Appearance') in ('Light','Pristine')
    export(EXPORT/'light-and-intact-proxies.glb',[variants],light)
    export(EXPORT/'heavy-and-fragments.glb',[variants],lambda obj: not light(obj))
    variants.hide_render=True
    variants.hide_viewport=True
    review.setup(stage)
    scene=bpy.context.scene
    scene['Asset']='Prism Seedship'
    scene['Units']='1 Blender unit = 1 stud; origin at ground deck datum, +Z up, south entry faces -Y'
    scene['Cutaway']='Hide collections 02 and 03 together to reveal both decks.'
    bpy.ops.object.select_all(action='DESELECT')
    (SOURCE/'panel-catalog.json').write_text(json.dumps(dict(asset='Prism Seedship',units='stud',
        sourceUp='+Z',sourceFront='-Y',origin='ground-deck center datum',
        exportAxes='glTF +Y up, source (x,y,z) maps to (x,z,-y)',
        total='Remove the full panel and all of its proxies; the stable edge frame remains.',
        fragments=spalls,panels=records),indent=2)+'\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'prism-seedship.blend'),compress=True)
    print('PRISM SEEDSHIP BUILD OK',len(records),'panels')


main()
