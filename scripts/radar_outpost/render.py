"""Render the review cameras from the saved Blender source. Optional --preview writes into build/."""
import hashlib
import json
import bpy
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[2]
scene = bpy.context.scene
preview = '--preview' in sys.argv
dest = root/('build/radar-previews' if preview else 'docs/images/radar-outpost')
dest.mkdir(parents=True, exist_ok=True)
if preview:
    scene.render.resolution_percentage = 53
    scene.cycles.samples = 4
source = Path(bpy.data.filepath)
source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
saved = []
for name in ['Exterior', 'Approach', 'Atrium', 'Gallery', 'Receiver', 'Overhead']:
    scene.camera = bpy.data.objects[name]
    scene.render.filepath = str(dest/(name.lower()+'.jpg'))
    bpy.ops.render.render(write_still=True)
    image_path = Path(scene.render.filepath)
    saved.append({'camera': name, 'path': image_path.name,
                 'sha256': hashlib.sha256(image_path.read_bytes()).hexdigest()})
if not preview:
    assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash, "Source changed during render"
    (dest/'renders.json').write_text(json.dumps({
        'source': source.name, 'sha256': source_hash,
        'engine': scene.render.engine, 'size': [scene.render.resolution_x, scene.render.resolution_y],
        'samples': scene.cycles.samples, 'views': saved}, indent=2)+'\n')
