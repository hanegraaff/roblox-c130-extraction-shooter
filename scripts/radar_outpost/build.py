"""Build the editable review source, isolated GLB assembly and damage geometry in Blender."""
import json
import sys
import tempfile
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

# Blender executes -P files outside the script directory.
import surfaces
import station
import review
import reflector
import layout
import envelope
from meshwork import collection

ROOT = HERE.parents[1]
SOURCE = ROOT/'assets/blender/radar-outpost'
EXPORT = ROOT/'assets/exports/radar-outpost'


def export(filename, groups):
    bpy.ops.object.select_all(action='DESELECT')
    for group in groups:
        for obj in group.objects:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/filename), export_format='GLB', use_selection=True,
                              export_extras=True, export_yup=True, export_cameras=False, export_lights=False)


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    EXPORT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    stable = collection('01 • Walkable structure')
    intact = collection('02 • Intact wall and roof panels')
    radar = collection('03 • Azimuth and reflector')
    detail = collection('04 • Railings, instrumentation and service')
    library = collection('05 • Alternate damage meshes and query proxies')
    stage = collection('06 • Review cameras, figures and desert set')
    with tempfile.TemporaryDirectory() as folder:
        surfaces.prepare(Path(folder))
    station.decks(stable, detail)
    station.frame(stable, detail)
    station.markings(detail)
    station.console(detail)
    station.utilities(detail)
    reflector.build(radar, library)
    panels = envelope.build_panels(intact, library)
    debris = envelope.fragments(library)
    bpy.context.view_layer.update()
    export('vesper-array.glb', [stable, intact, radar, detail])
    export('damage-library.glb', [library])
    library.hide_render = True
    library.hide_viewport = True
    review.setup(stage)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.scene['asset'] = 'Vesper Array / Radar Outpost 07'
    bpy.context.scene['scale'] = '1 Blender unit = 1 Roblox stud. Floor-center origin. Front is -Y.'
    catalog = {'asset': 'Vesper Array', 'formatVersion': 1, 'units': 'stud', 'sourceUp': '+Z', 'sourceFront': '-Y',
               'robloxSiteXYZ': layout.SITE, 'pointToSite': '(160 + x, 0.125 + z, -80 - y)',
               'states': 'Pristine in assembly; other visuals and query solids in the library. Total has no geometry.',
               'fragments': debris, 'panels': panels}
    (SOURCE/'panel-catalog.json').write_text(json.dumps(catalog, indent=2)+'\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'vesper-array.blend'), compress=True)
    print('VESPER BUILD OK')


main()
