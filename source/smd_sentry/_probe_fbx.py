"""Probe TurretBot.fbx — print mesh names, bone count, materials, vertex groups."""
import bpy, sys

FBX = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\assetstudio_turret\FBX_Animator\TurretBot\TurretBot.fbx"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX, use_anim=False)

print("=== OBJECTS ===")
for o in bpy.data.objects:
    print(f"  {o.type:10} {o.name}")

arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
if arm:
    bones = list(arm.data.bones)
    print(f"\n=== ARMATURE: {arm.name} ({len(bones)} bones) ===")
    for b in bones:
        parent = b.parent.name if b.parent else "<root>"
        print(f"  {b.name:30} parent={parent}")
else:
    print("NO ARMATURE")

print("\n=== MESHES ===")
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    print(f"\n-- MESH: {o.name}")
    print(f"   verts={len(o.data.vertices)} polys={len(o.data.polygons)}")
    print(f"   materials: {[m.name if m else None for m in o.data.materials]}")
    print(f"   vertex_groups: {len(o.vertex_groups)}")
    if o.vertex_groups:
        print(f"     first 10: {[vg.name for vg in list(o.vertex_groups)[:10]]}")

print("\n=== MATERIALS ===")
for m in bpy.data.materials:
    print(f"  {m.name}")
