"""Adversarial asset audits; actual exports are positive controls, not test doubles."""
from __future__ import annotations
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('p16_audit',ROOT/'scripts/p16_audit.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)


class P16RejectionTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(prefix='p16-rejection-')
        self.root=Path(self.temporary.name)
        for path in ('assets/blender/military-outpost','assets/exports/military-outpost','assets/world','docs/evidence/p16'):
            shutil.copytree(ROOT/path,self.root/path)
        (self.root/'scripts').mkdir(exist_ok=True)
        shutil.copyfile(ROOT/'scripts/p16_blender_review.py',self.root/'scripts/p16_blender_review.py')

    def tearDown(self):self.temporary.cleanup()

    def check(self):return audit.inspect_package(self.root,check_lock=False,check_evidence=False)

    def test_real_saved_package(self):
        report=self.check();self.assertEqual(report['failed'],0);self.assertEqual(report['passed'],5)

    def test_invisible_heavy_collider_is_rejected(self):
        path=self.root/'assets/exports/military-outpost/corrugated_wall-heavy-collision.obj'
        path.write_bytes((self.root/'assets/exports/military-outpost/corrugated_wall-pristine-collision.obj').read_bytes())
        with self.assertRaises(AssertionError):self.check()

    def test_light_opening_is_rejected(self):
        path=self.root/'assets/exports/military-outpost/corrugated_wall-light.obj'
        path.write_bytes((self.root/'assets/exports/military-outpost/corrugated_wall-heavy.obj').read_bytes())
        with self.assertRaises(AssertionError):self.check()

    def test_total_hidden_solid_is_rejected(self):
        path=self.root/'assets/exports/military-outpost/corrugated_wall-total.obj'
        path.write_bytes((self.root/'assets/exports/military-outpost/corrugated_wall-pristine.obj').read_bytes())
        with self.assertRaises(AssertionError):self.check()

    def test_shifted_legacy_identity_is_rejected(self):
        path=self.root/'assets/blender/military-outpost/panel-catalog.json';data=json.loads(path.read_text())
        data['identity_migration']['mapping'][0]['pivot_blender'][0]+=.1
        path.write_text(json.dumps(data))
        with self.assertRaises(AssertionError):self.check()

    def test_invalid_uv_index_is_rejected(self):
        path=self.root/'assets/exports/military-outpost/corrugated_wall-pristine.obj'
        path.write_text(path.read_text()+'\nf 1/9999999 2/1 3/1\n')
        with self.assertRaises(AssertionError):self.check()

    def test_oversized_fragment_is_rejected(self):
        path=self.root/'assets/exports/military-outpost/corrugated_wall-fragment-1.obj'
        path.write_text(path.read_text().replace('v 0.65','v 2.65'))
        with self.assertRaises(AssertionError):self.check()

    def test_missing_baked_texture_is_rejected(self):
        (self.root/'assets/exports/military-outpost/textures/teal.png').unlink()
        with self.assertRaises(OSError):self.check()

    def test_empty_fbx_is_rejected(self):
        (self.root/'assets/exports/military-outpost/outpost-assembly-v1.fbx').write_bytes(b'Kaydara FBX Binary')
        with self.assertRaises(AssertionError):self.check()

    def corrupt_box(self,geometry,name,lo,hi):
        vertices=[(x,y,z) for z in (lo[2],hi[2]) for y in (lo[1],hi[1]) for x in (lo[0],hi[0])]
        quads=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
        first=len(geometry['vertices']);geometry['vertices'].extend(vertices)
        for a,b,c,d in quads:
            geometry['triangles'].extend(((first+a,first+b,first+c),(first+a,first+c,first+d)))
            geometry['triangle_objects'].extend((name,name))

    def test_internal_stair_beam_corruption_is_rejected(self):
        geometry=audit.parse_obj(self.root/'assets/exports/military-outpost/outpost-assembly-v1.obj')
        self.corrupt_box(geometry,'Regression_internal_full_cross_beam',(-15,-.75,8.125),(15,.75,10.125))
        with self.assertRaisesRegex(AssertionError,'P16Navigation obstructed'):audit.inspect_navigation(geometry)

    def test_restored_external_full_deck_is_rejected(self):
        geometry=audit.parse_obj(self.root/'assets/exports/military-outpost/outpost-assembly-v1.obj')
        self.corrupt_box(geometry,'Regression_external_full_balcony',(16.5,-24,9.575),(22.5,24,10.125))
        with self.assertRaisesRegex(AssertionError,'P16Navigation obstructed'):audit.inspect_navigation(geometry)

    def test_body_width_obstruction_missed_by_center_ray_is_rejected(self):
        geometry=audit.parse_obj(self.root/'assets/exports/military-outpost/outpost-assembly-v1.obj')
        self.corrupt_box(geometry,'Regression_stair_side_obstruction',(-11.8,-.75,7),(-11.5,.75,8))
        with self.assertRaisesRegex(AssertionError,'P16Navigation obstructed'):audit.inspect_navigation(geometry)

    def test_all_current_tool_and_render_proofs(self):audit.validate_proofs(self.root)

    def test_stale_panel_library_proof_rejected_after_lock_refresh(self):
        path=self.root/'assets/exports/military-outpost/panel-library-v1.fbx';path.write_bytes(path.read_bytes()+b'stale')
        audit.write_lock(self.root)
        with self.assertRaisesRegex(AssertionError,'stale panel library'):audit.validate_proofs(self.root)

    def test_stale_kit_proof_rejected_after_lock_refresh(self):
        entry=audit.load(self.root/'assets/blender/military-outpost/reusable-kit.json')['assets'][0]
        path=self.root/'assets/exports/military-outpost'/entry['fbx'];path.write_bytes(path.read_bytes()+b'stale')
        audit.write_lock(self.root)
        with self.assertRaisesRegex(AssertionError,'stale kit'):audit.validate_proofs(self.root)

    def test_missing_required_render_is_rejected(self):
        (self.root/'docs/evidence/p16/floor-2.png').unlink()
        with self.assertRaisesRegex(AssertionError,'required render'):audit.validate_proofs(self.root)

    def test_stale_render_bytes_are_rejected(self):
        path=self.root/'docs/evidence/p16/floor-2.png';path.write_bytes(path.read_bytes()+b'stale')
        with self.assertRaisesRegex(AssertionError,'stale/corrupt render'):audit.validate_proofs(self.root)

    def test_stale_render_source_is_rejected(self):
        path=self.root/'docs/evidence/p16/render-manifest.json';data=json.loads(path.read_text());data['source_sha256']='0'*64;path.write_text(json.dumps(data))
        with self.assertRaisesRegex(AssertionError,'stale render source'):audit.validate_proofs(self.root)

    def test_stale_render_script_is_rejected(self):
        path=self.root/'scripts/p16_blender_review.py';path.write_text(path.read_text()+'\n# changed render program\n')
        with self.assertRaisesRegex(AssertionError,'stale render script'):audit.validate_proofs(self.root)


if __name__=='__main__':unittest.main()
