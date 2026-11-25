"""Independent OBJ scar-data check; no production parser/audit import."""
from pathlib import Path
import json,hashlib
root=Path.cwd();source=root/'assets/blender/military-outpost/military-outpost.blend';export=root/'assets/exports/military-outpost'
catalog=json.loads((root/'assets/blender/military-outpost/panel-catalog.json').read_text())
def parse(path):
 vertices=[];faces=[];material=None
 for line in path.read_text().splitlines():
  parts=line.split()
  if not parts:continue
  if parts[0]=='v':vertices.append(tuple(map(float,parts[1:])))
  elif parts[0]=='usemtl':material=parts[1]
  elif parts[0]=='f':faces.append((tuple(int(token.split('/')[0])-1 for token in parts[1:]),material))
 return vertices,faces
records=[]
for family in catalog['families']:
 pristine_vertices,pristine_faces=parse(export/family['states']['Pristine']['mesh'])
 light_vertices,light_faces=parse(export/family['states']['Light']['mesh'])
 assert (pristine_vertices,pristine_faces)!=(light_vertices,light_faces),('identical Light',family['id'])
 pristine_materials={m for _,m in pristine_faces};scar_materials={m for _,m in light_faces}-pristine_materials
 assert scar_materials,('no distinct damage materials',family['id'])
 sides={'front':0,'back':0}
 for indices,material in light_faces:
  if material not in scar_materials:continue
  y=sum(light_vertices[i][1] for i in indices)/len(indices)
  if y<-.1:sides['front']+=1
  elif y>.1:sides['back']+=1
 assert all(sides.values()),('missing two-sided scars',family['id'],sides)
 records.append(dict(family=family['id'],pristine_triangles=len(pristine_faces),light_triangles=len(light_faces),distinct_scar_materials=sorted(scar_materials),scar_triangles_by_side=sides))
print(json.dumps(dict(suite='P16-independent-Light',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),discovered=len(records),passed=len(records),failed=0,records=records)))
