"""Portable checkout audit for P16's real Blender/FBX/OBJ/PNG asset package.

No Blender or third-party Python packages are needed. Projection checks rasterize
actual exported triangles, independently of declared catalog rectangles. The
clean Blender reopen and FBX import reports remain separate engine/tool evidence.
Run `python3 scripts/p16_audit.py --write-lock` only after an intentional re-export;
ordinary verification fails closed on stale/missing/corrupt dependencies.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/blender/military-outpost'
EXPORT=ROOT/'assets/exports/military-outpost'
LOCK=SOURCE/'package-lock.json'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):return json.loads(path.read_text())


def art_files(root=ROOT):
    return sorted(p for base in (root/'assets/blender/military-outpost',root/'assets/exports/military-outpost')
      for p in base.rglob('*') if p.is_file() and p.suffix.lower()!='.md' and p.name!='package-lock.json')


def write_lock():
    files=art_files()
    LOCK.write_text(json.dumps(dict(schema_version=1,revision='p16-v1',files=[dict(path=str(p.relative_to(ROOT)),sha256=sha(p),bytes=p.stat().st_size) for p in files]),indent=2)+'\n')


def parse_obj(path):
    vertices=[];uvs=[];triangles=[];materials=set();objects=[]
    for line in path.read_text().splitlines():
        p=line.split()
        if not p:continue
        if p[0]=='v':
            v=tuple(float(x) for x in p[1:]);assert len(v)==3 and all(math.isfinite(x) for x in v),path
            vertices.append(v)
        elif p[0]=='vt':
            uv=tuple(float(x) for x in p[1:]);assert len(uv)==2 and all(math.isfinite(x) for x in uv),path
            uvs.append(uv)
        elif p[0]=='o':objects.append(' '.join(p[1:]))
        elif p[0]=='usemtl':materials.add(p[1])
        elif p[0]=='f':
            assert len(p)==4,('not triangulated',path)
            corners=[]
            for token in p[1:]:
                fields=token.split('/');i=int(fields[0])-1;t=int(fields[1])-1
                assert 0<=i<len(vertices) and 0<=t<len(uvs),('invalid face index',path)
                corners.append(i)
            triangles.append(tuple(corners))
    return dict(vertices=vertices,uvs=uvs,triangles=triangles,materials=materials,objects=objects)


def projected_mask(obj,w,h,res=128):
    """Union of actual X/Z projected triangles, sampled at cell centers.

    Masks are independent of normals/sidedness and thickness. Resolution along
    each axis is proportional to physical size; errors are bounded by one cell.
    A collider falsely spanning an opening changes sampled cells and rejects.
    """
    nx=res;ny=max(32,round(res*h/w));mask=set();vertices=obj['vertices']
    for ids in obj['triangles']:
        a,b,c=[(vertices[i][0],vertices[i][2]) for i in ids]
        denom=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(denom)<1e-10:continue
        ix0=max(0,math.floor((min(a[0],b[0],c[0])/w+.5)*nx));ix1=min(nx-1,math.floor((max(a[0],b[0],c[0])/w+.5)*nx))
        iz0=max(0,math.floor((min(a[1],b[1],c[1])/h+.5)*ny));iz1=min(ny-1,math.floor((max(a[1],b[1],c[1])/h+.5)*ny))
        for iz in range(iz0,iz1+1):
            z=((iz+.5)/ny-.5)*h
            for ix in range(ix0,ix1+1):
                x=((ix+.5)/nx-.5)*w
                u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(z-c[1]))/denom
                v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(z-c[1]))/denom
                if u>=-1e-9 and v>=-1e-9 and u+v<=1+1e-9:mask.add(iz*nx+ix)
    return mask


def inspect_package(root=ROOT,check_lock=True,check_evidence=True):
    source=root/'assets/blender/military-outpost';export=root/'assets/exports/military-outpost'
    inv=load(source/'asset-inventory.json');catalog=load(source/'panel-catalog.json');material=load(export/'material-map.json')
    results=[]
    def passed(name,detail):results.append(dict(name=name,passed=True,detail=detail))
    # A1 inventory categories must have actual named mesh objects in measured audit.
    counts=inv['category_counts'];objects=inv['objects']
    assert inv['required_categories'] and len(set(inv['required_categories']))==len(inv['required_categories'])
    for category in inv['required_categories']:
        actual=sum(o['asset_category']==category for o in objects)
        assert actual>0 and actual==counts[category],('missing inventory category',category)
    assert all(o['triangles']>0 for o in objects), 'empty mesh'
    passed('P16AssetInventory',dict(categories=len(inv['required_categories']),mesh_objects=len(objects),furnished_floors=2))
    families=catalog['families'];assert len(families)==6 and len({f['id'] for f in families})==6
    mapping=catalog['identity_migration']['mapping'];legacy=[m for m in mapping if 'legacy_pivot_roblox' in m]
    assert len(legacy)==catalog['identity_migration']['legacy_count']==25
    assert len({m['panel_id'] for m in mapping})==len(mapping)==26
    def walk(n):
        if n.get('Name')=='Outpost_Panels':return n['Children']
        for child in n.get('Children',[]):
            found=walk(child)
            if found:return found
    actual_nodes=walk(load(root/'assets/world/Battlefield.model.json'))
    actual={n['Name']:n['Properties'] for n in actual_nodes}
    for m in legacy:
        assert m['legacy_pivot_roblox']==actual[m['panel_id']]['CFrame'],m['panel_id']
        assert m['legacy_size_roblox']==actual[m['panel_id']]['Size'],m['panel_id']
        x,y,z=m['legacy_pivot_roblox'][:3]
        assert m['pivot_blender']==[x-144,-(z-164),y],m['panel_id']
    all_materials={m['material'] for m in material['materials']};geometry=[]
    for family in families:
        w,t,h=family['dimensions_studs'];assert all(math.isfinite(v) and v>0 for v in (w,t,h))
        assert family['pivot']==[0,0,0]
        assert set(family['states'])=={'Pristine','Light','Heavy','Total'}
        masks={};proxies={}
        for state,entry in family['states'].items():
            obj=parse_obj(export/entry['mesh']);proxy=parse_obj(export/entry['collision'])
            assert obj['materials']<=all_materials and proxy['materials']<=all_materials
            masks[state]=projected_mask(obj,w,h);proxies[state]=projected_mask(proxy,w,h)
            assert len(obj['triangles'])>0 if state!='Total' else len(obj['triangles'])==0
        assert masks['Pristine']==proxies['Pristine'],family['id']+' pristine proxy mismatch'
        assert masks['Light']==masks['Pristine']==proxies['Light'],family['id']+' Light opens panel'
        assert not masks['Total'] and not proxies['Total'],family['id']+' Total has a solid'
        pristine=len(masks['Pristine']);removed=1-len(masks['Heavy'])/pristine
        proxy_removed=1-len(proxies['Heavy'])/pristine
        assert .45<=removed<=.55,(family['id'],removed)
        assert .45<=proxy_removed<=.55,(family['id'],proxy_removed)
        # Cosmetic bent lips can intrude into the hole by <1 sample cell; proxies
        # must never block where the actual mesh silhouette is absent.
        extra=proxies['Heavy']-masks['Heavy'];assert not extra,(family['id'],'invisible collider',len(extra))
        difference=len(masks['Heavy']^proxies['Heavy'])/pristine
        assert difference<=.025,(family['id'],'silhouette difference',difference)
        fragments=family['fragments'];assert len(fragments)==family['fragment_cap']==4
        for f in fragments:
            obj=parse_obj(export/f['mesh']);assert obj['triangles'] and obj['uvs'] and obj['materials']<=all_materials
            for axis in range(3):
                size=max(v[axis] for v in obj['vertices'])-min(v[axis] for v in obj['vertices'])
                assert 0<size<=1.5+1e-6,(family['id'],'oversized fragment',size)
        geometry.append(dict(family=family['id'],actual_removed_fraction=removed,proxy_removed_fraction=proxy_removed,
          proxy_extra_cells=len(extra),cosmetic_silhouette_difference=difference,raster_width=128))
    passed('P16DamageCatalog',dict(families=6,states=24,fragments=24,legacy_pivots=25,new_panels=1))
    passed('P16PanelGeometry',geometry)
    # Actual OBJ data validates UV indexing, finite positions, triangle counts and
    # material references independently from the authoring inventory declarations.
    assembly=parse_obj(export/'outpost-assembly-v1.obj')
    assert len(assembly['triangles'])==inv['measured']['assembly_triangles']
    assert len(assembly['objects'])==inv['collections']['01_Stable_Structure']['mesh_objects']+sum(inv['collections'][name]['mesh_objects'] for name in ['02_Destructible_Panels','03_Exterior_Dressing','04_Floor_1_Workshop','05_Floor_2_Command'])
    for key,val in inv['measured'].items():
        if key in inv['budgets']:assert val<=inv['budgets'][key],('budget',key,val)
    assert inv['measured']['materials']==len(all_materials)==12
    for mat in material['materials']:
        path=export/mat['base_color'];data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n';width,height=struct.unpack('>II',data[16:24]);assert(width,height)==(512,512)
    for name in ('outpost-assembly-v1.fbx','panel-library-v1.fbx'):
        data=(export/name).read_bytes();assert data.startswith(b'Kaydara FBX Binary') and len(data)>10000,('empty FBX',name)
    files=art_files(root);total=sum(p.stat().st_size for p in files)
    assert total<=inv['budgets']['package_bytes'],('package byte budget',total)
    assert all(p.stat().st_size<=inv['budgets']['single_file_bytes'] for p in files)
    kit=load(source/'reusable-kit.json')['assets'];assert len(kit)>=7
    for entry in kit:
        obj=parse_obj(export/entry['obj']);assert len(obj['triangles'])==entry['triangles'] and len(obj['objects'])==1
        assert obj['materials']<=all_materials and obj['uvs'] and entry['source_components']
        assert entry['triangles']<=10000,('kit mesh triangle budget',entry['family'])
        assert abs(min(v[2] for v in obj['vertices']))<.001,('kit bottom pivot',entry['family'])
        for axis in (0,1):assert abs(max(v[axis] for v in obj['vertices'])+min(v[axis] for v in obj['vertices']))<.001,('kit center pivot',entry['family'])
        data=(export/entry['fbx']).read_bytes();assert data.startswith(b'Kaydara FBX Binary') and len(data)>10000
    passed('P16ExportAudit',dict(assembly_triangles=len(assembly['triangles']),materials=12,textures=12,reusable_kit_assets=len(kit),package_bytes=total))
    if check_evidence:
        reopened=load(root/'docs/evidence/p16/blender-reopen.json');fbx=load(root/'docs/evidence/p16/fbx-import.json')
        assert reopened['passed'] and reopened['source_sha256']==sha(source/'military-outpost.blend'),'stale Blender reopen'
        assert fbx['passed'] and fbx['fbx_sha256']==sha(export/'outpost-assembly-v1.fbx'),'stale FBX import'
        assert reopened['missing_dependencies']==0 and fbx['scale_axes_verified'] and fbx['uv_materials_verified']
        passed('P16BlenderReopen',dict(source_sha256=reopened['source_sha256'],blender_version=reopened['blender_version'],missing_dependencies=0,fbx_meshes=fbx['imported_meshes']))
    if check_lock:
        lock=load(source/'package-lock.json');expected={f['path']:f for f in lock['files']}
        assert set(expected)=={str(p.relative_to(root)) for p in files},'untracked/missing art file'
        for path,entry in expected.items():
            p=root/path;assert p.stat().st_size==entry['bytes'] and sha(p)==entry['sha256'],('stale/corrupt dependency',path)
        passed('P16Dependencies',dict(files=len(files),sha256_verified=True))
    return dict(suite='P16-assets',discovered=len(results),passed=len(results),failed=0,skipped=0,results=results)


def main():
    p=argparse.ArgumentParser();p.add_argument('--write-lock',action='store_true');p.add_argument('--output',type=Path);args=p.parse_args()
    if args.write_lock:write_lock()
    try:report=inspect_package()
    except (AssertionError,KeyError,ValueError,OSError) as e:
        print(json.dumps(dict(suite='P16-assets',passed=0,failed=1,error=str(e))));return 1
    if args.output:args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report));return 0


if __name__=='__main__':sys.exit(main())
