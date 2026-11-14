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

    def tearDown(self):self.temporary.cleanup()

    def check(self):return audit.inspect_package(self.root,check_lock=False,check_evidence=False)

    def test_real_saved_package(self):
        report=self.check();self.assertEqual(report['failed'],0);self.assertEqual(report['passed'],4)

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


if __name__=='__main__':unittest.main()
