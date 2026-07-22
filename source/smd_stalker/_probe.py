"""
Stalker GLB probe — runs in Blender headless. Imports the GLB, dumps object/armature/action/mesh info.
"""
import bpy
import os
import sys

input_glb = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\extracted\Assets\PrefabHierarchyObject\Stalker_0.glb"

# Clean default scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Try to enable Source Tools addon
try:
    bpy.ops.preferences.addon_enable(module="io_scene_valvesource")
    print("[probe] Source Tools enabled OK")
except Exception as e:
    print(f"[probe] addon_enable said: {e}")

# Import GLB
print(f"[probe] Importing: {input_glb}")
bpy.ops.import_scene.gltf(filepath=input_glb)

print("\n[probe] === Scene contents ===")
print(f"Objects ({len(bpy.data.objects)}):")
for o in bpy.data.objects:
    parent_name = o.parent.name if o.parent else "(no parent)"
    print(f"  {o.type:12s} '{o.name}' parent={parent_name} scale={list(o.scale)}")

print(f"\nArmatures (data blocks: {len(bpy.data.armatures)}):")
for a in bpy.data.armatures:
    print(f"  Armature '{a.name}' bones={len(a.bones)}")
    for b in list(a.bones)[:10]:
        print(f"    {b.name}")
    if len(a.bones) > 10:
        print(f"    ... and {len(a.bones)-10} more")

print(f"\nMeshes (data blocks: {len(bpy.data.meshes)}):")
for m in bpy.data.meshes:
    print(f"  Mesh '{m.name}' verts={len(m.vertices)} polys={len(m.polygons)}")

print(f"\nActions (animations): {len(bpy.data.actions)}")
for act in bpy.data.actions:
    duration = act.frame_range[1] - act.frame_range[0]
    print(f"  '{act.name}' frames=[{act.frame_range[0]:.0f}..{act.frame_range[1]:.0f}] ({duration:.0f}f)")

# Check if Source Tools API is available
print("\n[probe] === Source Tools probe ===")
try:
    scene = bpy.context.scene
    print(f"  scene.vs available? {hasattr(scene, 'vs')}")
    if hasattr(scene, 'vs'):
        print(f"  scene.vs attrs: {[a for a in dir(scene.vs) if not a.startswith('_')][:20]}")
    obj0 = list(bpy.data.objects)[0]
    print(f"  obj.vs available? {hasattr(obj0, 'vs')}")
    if hasattr(obj0, 'vs'):
        print(f"  obj.vs attrs: {[a for a in dir(obj0.vs) if not a.startswith('_')][:20]}")
except Exception as e:
    print(f"  Source Tools probe error: {e}")

# Check for SMD export operator
print(f"\n[probe] export_scene.smd available? {'smd' in dir(bpy.ops.export_scene)}")

print("[probe] === DONE ===")
