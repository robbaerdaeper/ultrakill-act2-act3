"""Probe Virtue.glb for mesh count / material names / skinning."""
import json
import struct
from pathlib import Path
from pygltflib import GLTF2

GLB = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\extracted\Assets\PrefabHierarchyObject\Virtue.glb"

g = GLTF2().load(GLB)
print(f"scenes: {len(g.scenes)}  nodes: {len(g.nodes)}  meshes: {len(g.meshes)}  materials: {len(g.materials)}  skins: {len(g.skins) if g.skins else 0}")

for i, m in enumerate(g.meshes):
    print(f"\nMESH {i}: name={m.name!r}  primitives={len(m.primitives)}")
    for j, p in enumerate(m.primitives):
        mat_name = g.materials[p.material].name if p.material is not None else "<none>"
        print(f"  prim {j}: material={mat_name!r}  attrs={list(p.attributes.__dict__.keys()) if p.attributes else None}")
        # extract attribute accessors
        if p.attributes:
            for k, acc_idx in p.attributes.__dict__.items():
                if acc_idx is not None:
                    acc = g.accessors[acc_idx]
                    print(f"    {k}: count={acc.count} type={acc.type} componentType={acc.componentType}")

print("\nNODES:")
for i, n in enumerate(g.nodes):
    print(f"  {i}: name={n.name!r}  mesh={n.mesh}  children={n.children}  translation={n.translation}  scale={n.scale}")
