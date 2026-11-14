# Independent host review: native constructor correction

Base source 48eae4b2f0ebb4b0f069fb21a41973b9a37a297a; current documentation/evidence HEAD b57c49c96227635189ab52a02fd0624a0c073e37, tree b4c99cc60c4780ae19df5fcfcaf7a8eb009cfc91. The correction was still uncommitted during this review. Exact twelve relevant source/test/model file hashes are saved in p17-independent-native-fix-source-snapshot.json. No Studio call, managed edit, commit or publication was made by the tester.

1. **Required native validation remains open; no new material source defect found.** Host verification establishes exact preservation of genuine constructor data for every authored imported MeshPart, independently of the compiler implementation. It does not establish full-building native rendering, ordinary script permission behavior, physical contacts, replicated stages/reset or performance. The new ordinary server fixture must cover all 2,332 templates/clones and bounded floor collision; ordinary client fixture must execute its public AssetMesh read/metadata rejection; stage/reset fixtures must preserve native fields. Current final-source imported render/navigation/targeting, actual multi-client regressions and human approval remain required. The primary's separate native four-sample causal/render roundtrip is useful evidence at that scope, not a replacement for the full building.

2. **Resolved verification defect: invalid negative-test control.** Initially test_compiler_rejects_missing_native_profile_wrong_fidelity_or_unused_capture supplied only one floor with all 407 profiles/2,332 expected uses. Its unchanged input also rejected on coverage. The developer changed it to a valid one-floor/one-profile/uses=1 positive control, then independently mutates missing profile, wrong fidelity and unused capture with specific expected error messages. Independent recheck passes all five native host tests. This is a resolved test-quality finding, not an outstanding product defect.

## Independent facts

- Captured bank is exactly 55,050 bytes, SHA-256 73a7f6dfc224f677453966ae950081016ac71cd195db4a84cd305c0b98e6cc1c. Requests SHA-256 is d916f5cb5897bb9727c3603a2c8d8eaeac83f1044b3b44a772ca40a6bd8f067c.
- All 407 native profiles (320 Box / 87 PreciseConvexDecomposition) match their public receipt, genuine serialized float32 InitialSize, MeshId and exact use coverage across 2,332 target MeshParts. Native capture has one Folder with only direct inert MeshParts; no executable/extra child content.
- All 2,332 generated MeshParts retain exact captured InitialSize, PhysicalConfigData, PhysicsData and AeroMeshData plus the five readable identity/intrinsic/fidelity metadata fields.
- Original target Size stays independent of intrinsic MeshSize. Ground floor target remains approximately 32×1×48 studs; intrinsic size is approximately 1365.333×42.667×2048. Maximum intrinsic/target axis ratio is approximately 42.6667. The validator correctly imposes no 40/64-stud authoring ceiling on original mesh intrinsics.
- After removing only those constructor fields and five new metadata attributes, both generated model trees equal their 48eae4b originals exactly: mesh IDs, target transforms/dimensions, classification, material maps, UV references and all other authored data are unchanged.
- An independently built actual Rojo XML artifact preserves native InitialSize, target Size, MeshId, all three opaque payload byte sequences and all five metadata fields for all 2,332 MeshParts. Artifact SHA-256 c1b467e1769c3c754b941442f28caa35a644e697132a69123a7de2614c4dce59, 10,960,098 bytes. This is a working-tree snapshot, not the eventual final candidate artifact.
- Native XML encodes collision configuration in opaque PhysicalConfigData rather than a separate public CollisionFidelity token. Host byte equality and the public native roundtrip are intentionally separate evidence.
- AssetMesh.validate reads public MeshSize/fidelities and GetAttribute only; it is nonyielding, readonly and resource-free, with no cloud fetch or protected SurfaceAppearance read. Both catalog and full Outpost prepare call it before world cloning/mutation. It rejects absent/version/identity/positive-finite intrinsic/policy mismatches, and verifies the actual original asset intrinsics rather than normalized target Size. Stage cloning remains the existing native clone path.

## Commands, environment and evidence

macOS 26.6.2 arm64, Python 3.10.4, pinned Lune 0.11.1, Rojo 7.7.1.

- /Users/markhanegraaff/.rokit/bin/lune run scripts/p17_native_mesh_xml.luau assets/imports/military-outpost/native-mesh-profiles-v1.rbxm build/p17-independent-native-profiles.rbxmx
- python3 build/p17_independent_native_profiles.py > build/p17-independent-native-profile-review.json
- /Users/markhanegraaff/.rokit/bin/rojo build test.project.json --output build/p17-independent-native-fixed-tests.rbxlx
- python3 build/p17_independent_native_artifact.py > build/p17-independent-native-artifact-review.json
- python3 -m unittest discover -s tests/assets -p 'test_p17_native_meshes.py' -v, repeated only after the negative-control fix: 5 tests / all passed. Final log p17-independent-native-regressions-recheck.txt.

The two independent probe scripts use stdlib parsing/byte comparisons and do not import the proposed compiler/inspector helpers. The first artifact-probe attempt had a tester-only path error because Rojo names the root from its filename; that mapping was corrected before the successful 2,332-part check. No candidate change resulted.

Full verify.py was not independently repeated for this work-in-progress correction; the developer/primary final gate remains responsible for final source identity and full counts. No subjective player-feel assessment was made in this host-only scope.

