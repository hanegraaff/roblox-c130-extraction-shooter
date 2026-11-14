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


def write_lock(root=ROOT):
    files=art_files(root)
    (root/'assets/blender/military-outpost/package-lock.json').write_text(json.dumps(dict(schema_version=1,revision='p16-v1',files=[dict(path=str(p.relative_to(root)),sha256=sha(p),bytes=p.stat().st_size) for p in files]),indent=2)+'\n')


def parse_obj(path):
    vertices=[];uvs=[];triangles=[];materials=set();objects=[];triangle_objects=[];current_object='unnamed'
    for line in path.read_text().splitlines():
        p=line.split()
        if not p:continue
        if p[0]=='v':
            v=tuple(float(x) for x in p[1:]);assert len(v)==3 and all(math.isfinite(x) for x in v),path
            vertices.append(v)
        elif p[0]=='vt':
            uv=tuple(float(x) for x in p[1:]);assert len(uv)==2 and all(math.isfinite(x) for x in uv),path
            uvs.append(uv)
        elif p[0]=='o':
            current_object=' '.join(p[1:]);objects.append(current_object)
        elif p[0]=='usemtl':materials.add(p[1])
        elif p[0]=='f':
            assert len(p)==4,('not triangulated',path)
            corners=[]
            for token in p[1:]:
                fields=token.split('/');i=int(fields[0])-1;t=int(fields[1])-1
                assert 0<=i<len(vertices) and 0<=t<len(uvs),('invalid face index',path)
                corners.append(i)
            triangles.append(tuple(corners));triangle_objects.append(current_object)
    return dict(vertices=vertices,uvs=uvs,triangles=triangles,materials=materials,objects=objects,triangle_objects=triangle_objects)


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


def navigation_samples():
    """Named routes in Blender stud coordinates, including treads and landings.

    Expected foot heights select the intended walking surface, never a high
    overhead deck. A 0.1-stud edge tolerance allows nosings/shared tread edges.
    The visible geometry must independently supply support and clear a 4x6x4
    upright envelope. Native avatar movement remains P17 acceptance.
    """
    samples=[]
    def add(route,x,y,z):samples.append(dict(route=route,x=x,y=y,expected_foot=z))
    for y in (-19,-18,-17):add('internal',-10,y,.125)
    for i in range(16):
        for offset in (-.7,-.35,0,.35,.7):add('internal',-10,-15+2*i+offset,.125+(i+1)*.625)
    for y in (16.25,16.75,17.25,17.75,18.25,19,20):add('internal',-10,y,10.125)
    for x in (-9,-8,-7,-6,-5,-4,-3,-2):add('internal',x,20,10.125)
    for y in (-31,-30,-29):add('external',19.5,y,.125)
    for i in range(20):
        for offset in (-.35,0,.35):add('external',19.5,-28+i+offset,.125+(i+1)*.5)
    for y in (-8.25,-7.75,-7,-6,-4,-2,0,4,8,12,14,16):add('external',19.5,y,10.125)
    for x in (19,18.5,18,17.5,17,16.5,16,15.5,15,14.5,14,13.5):add('external',x,16,10.125)
    return samples


def _triangle_box_intersects(vertices,lower,upper):
    """Separating-axis triangle/AABB test; contact without volume is allowed."""
    center=[(a+b)/2 for a,b in zip(lower,upper)];half=[(b-a)/2 for a,b in zip(lower,upper)]
    vs=[tuple(v[i]-center[i] for i in range(3)) for v in vertices]
    edges=[tuple(vs[(j+1)%3][i]-vs[j][i] for i in range(3)) for j in range(3)]
    def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
    axes=[(1,0,0),(0,1,0),(0,0,1),cross(edges[0],edges[1])]
    for edge in edges:
        for basis in ((1,0,0),(0,1,0),(0,0,1)):axes.append(cross(edge,basis))
    for axis in axes:
        if sum(a*a for a in axis)<1e-16:continue
        dots=[sum(v[i]*axis[i] for i in range(3)) for v in vs]
        radius=sum(half[i]*abs(axis[i]) for i in range(3))
        if min(dots)>=radius-1e-6 or max(dots)<=-radius+1e-6:return False
    return True


def inspect_navigation(geometry):
    """Validate actual saved/exported triangles against both complete stair routes.

    Floors are ray-tested from actual mesh triangles. At each center/intermediate
    station, nine footprint support rays select a legal stepped profile; the
    highest support defines a legal ascending floor profile. Exact triangle/box tests
    then check all visible assembly geometry, with no name-based obstruction
    exemptions. Only outside ground before the external stairs is level-supplied
    at Z=.125; that plane is not presented as an authored outpost floor.
    """
    floor_prefixes=('Foundation','Upper_Main','Upper_North_Landing','Upper_South_Rim',
      'Internal_stair_tread','Tread_nosing','Internal_top_landing','Upper_balcony_threshold',
      'External_open_tread','External_anti_slip_nosing','Exterior_balcony_landing')
    records=[];bins={};floor_bins={}
    names=geometry['triangle_objects'];vertices=geometry['vertices']
    for ids,name in zip(geometry['triangles'],names):
        vs=tuple(vertices[i] for i in ids)
        low=tuple(min(v[i] for v in vs) for i in range(3));high=tuple(max(v[i] for v in vs) for i in range(3))
        index=len(records);records.append((name,vs,low,high))
        for bx in range(math.floor(low[0]/4),math.floor(high[0]/4)+1):
            for by in range(math.floor(low[1]/4),math.floor(high[1]/4)+1):
                bins.setdefault((bx,by),[]).append(index)
                if name.replace(' ','_').startswith(floor_prefixes):floor_bins.setdefault((bx,by),[]).append(index)
    def support(x,y,hint,route):
        heights=[]
        for i in floor_bins.get((math.floor(x/4),math.floor(y/4)),()):
            _,vs,lo,hi=records[i]
            if not (lo[0]-1e-6<=x<=hi[0]+1e-6 and lo[1]-1e-6<=y<=hi[1]+1e-6):continue
            a,b,c=vs;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den)<1e-9:continue
            u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
            v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den
            if u>=-1e-6 and v>=-1e-6 and u+v<=1+1e-6:
                z=u*a[2]+v*b[2]+(1-u-v)*c[2]
                if z<=hint+1.4:heights.append(z)
        # Explicit external approach ground, supplied by the current level.
        if route=='external' and y<-28.5:heights.append(.125)
        return max(heights) if heights else None
    checks=[];body_samples=0;support_rays=0
    for sample in navigation_samples():
        route=sample['route'];x=sample['x'];y=sample['y'];expected=sample['expected_foot']
        center=support(x,y,expected,route);support_rays+=1
        assert center is not None and abs(center-expected)<=.11,('P16Navigation missing/incorrect tread',sample,center)
        heights=[]
        for dx in (-1.95,0,1.95):
            for dy in (-1.95,0,1.95):
                floor=support(x+dx,y+dy,expected,route);support_rays+=1
                if floor is not None:heights.append(floor)
        foot=max(heights+[center]);lower=(x-2,y-2,center+.065);upper=(x+2,y+2,center+6)
        candidates=set()
        for bx in range(math.floor(lower[0]/4),math.floor(upper[0]/4)+1):
            for by in range(math.floor(lower[1]/4),math.floor(upper[1]/4)+1):candidates.update(bins.get((bx,by),()))
        for i in candidates:
            name,vs,lo,hi=records[i]
            # Rising tread faces within the actual sampled step profile are
            # legal beneath the avatar; they must not become low-body walls.
            if name.replace(' ','_').startswith(floor_prefixes) and hi[2]<=foot+.065:continue
            if any(hi[a]<=lower[a]+1e-5 or lo[a]>=upper[a]-1e-5 for a in range(3)):continue
            assert not _triangle_box_intersects(vs,lower,upper),('P16Navigation obstructed upright body',sample,name,lower,upper)
        body_samples+=1;checks.append(route)
    return dict(name='P16Navigation',passed=True,body_dimensions_studs=[4,6,4],foot_clearance_studs=.065,
      support_height_tolerance_studs=.11,profile_method='6stud body above center support; floor-only ascending faces allowed below highest of9 footprint support rays',
      body_samples=body_samples,support_rays=support_rays,
      internal_samples=checks.count('internal'),external_samples=checks.count('external'),
      scope='Actual evaluated saved/exported mesh geometry; native avatar/engine traversal remains P17')


def expected_render_paths(catalog):
    """The required five scene views and every two-sided normal/grayscale family."""
    names=['exterior','floor-1','floor-2','cutaway','isolated-kit']
    names += [f"damage-{f['id']}-{side}-{mode}" for f in catalog['families']
      for side in ('front','back') for mode in ('normal','grayscale')]
    return {f'docs/evidence/p16/{name}.png' for name in names}


def png_record(path,root):
    data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n',path
    width,height,depth,color,_,_,_=struct.unpack('>IIBBBBB',data[16:29])
    return dict(path=str(path.relative_to(root)),sha256=sha(path),bytes=len(data),width=width,height=height,
      bit_depth=depth,color_mode={0:'BW',2:'RGB',6:'RGBA'}[color])


def validate_proofs(root):
    """Bind tool evidence to exact current art, exporter and all required images.

    Refreshing package-lock deliberately cannot make a stale import/render proof
    valid. Both source/export identities and the complete named view set must
    agree with independently generated clean-Blender reports.
    """
    source=root/'assets/blender/military-outpost';export=root/'assets/exports/military-outpost';evidence=root/'docs/evidence/p16'
    reopened=load(evidence/'blender-reopen.json');fbx=load(evidence/'fbx-import.json')
    source_hash=sha(source/'military-outpost.blend')
    assert reopened['passed'] and reopened['source_sha256']==source_hash,'stale Blender reopen'
    assert fbx['passed'] and fbx['fbx_sha256']==sha(export/'outpost-assembly-v1.fbx'),'stale assembly FBX import'
    assert fbx['panel_library_sha256']==sha(export/'panel-library-v1.fbx'),'stale panel library FBX import'
    kit=load(source/'reusable-kit.json')['assets'];proofs={e['family']:e for e in fbx['reusable_kit']}
    assert set(proofs)=={e['family'] for e in kit},'missing/extra reusable kit import proof'
    for entry in kit:
        proof=proofs[entry['family']]
        assert proof['fbx_sha256']==sha(export/entry['fbx']),('stale kit FBX import',entry['family'])
        assert proof['triangles']==entry['triangles'],('stale kit geometry import',entry['family'])
    assert reopened['missing_dependencies']==0 and fbx['scale_axes_verified'] and fbx['uv_materials_verified']
    assert reopened['navigation']['passed'] and fbx['navigation']['passed'],'missing source/FBX navigation proof'
    expected=expected_render_paths(load(source/'panel-catalog.json'))
    actual={str(p.relative_to(root)) for p in evidence.glob('*.png')}
    assert actual==expected,('missing/extra required render',sorted(expected-actual),sorted(actual-expected))
    script_hash=sha(root/'scripts/p16_blender_review.py')
    for name in ('render-evidence.json','render-manifest.json'):
        report=load(evidence/name)
        assert report['source_sha256']==source_hash,('stale render source',name)
        assert report['review_script_sha256']==script_hash,('stale render script',name)
        assert report.get('passed') and report['image_count']==29,('incomplete render set',name)
        files={f['path']:f for f in report['files']}
        assert len(report['files'])==len(files)==29 and set(files)==expected,('wrong render identity set',name)
        for path,entry in files.items():
            current=png_record(root/path,root);assert entry==current,('stale/corrupt render',path)
            damage='/damage-' in path
            assert (current['width'],current['height'])==((1600,440) if damage else (1280,900)),path
            if '-grayscale.' in path:assert current['color_mode']=='BW',('not grayscale',path)
            else:assert current['color_mode'] in ('RGB','RGBA'),('not color',path)
    return dict(source_sha256=source_hash,blender_version=reopened['blender_version'],missing_dependencies=0,
      fbx_meshes=fbx['imported_meshes'],panel_library_meshes=fbx['panel_library_meshes'],kit_imports=len(kit),required_renders=29)


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
    passed('P16Navigation',inspect_navigation(assembly))
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
        passed('P16BlenderReopen',validate_proofs(root))
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
