"""Render the saved cameras, optionally at draft size or by exact camera name."""
from pathlib import Path
import sys
import bpy

ROOT=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
draft='draft' in args
cameras=[s for s in args if s!='draft'] or ['Recovery bay','Specimen 07','Field machinery','Resonator bank','Exterior','Flank','Arrival hall','Seed vault','Observation deck','Starboard breach','Open decks']
scene=bpy.context.scene
dest=ROOT/('build/seedship-draft' if draft else 'docs/images/alien-spaceship')
dest.mkdir(parents=True,exist_ok=True)
if draft:
    scene.render.resolution_percentage=54
    scene.cycles.samples=4
for name in cameras:
    scene.camera=bpy.data.objects[name]
    for col in bpy.data.collections:
        if col.name.startswith(('02 •','03 •')):
            col.hide_render=name=='Open decks'
    scene.render.filepath=str(dest/(name.lower().replace(' ','-')+'.jpg'))
    bpy.ops.render.render(write_still=True)
