"""Probe Stalker.glb (the un-suffixed variant) — possibly the body source."""
import bpy

input_glb = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\extracted\Assets\PrefabHierarchyObject\Stalker.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_glb)

print(f"[probe2] Imported: {input_glb}")
print(f"\nObjects ({len(bpy.data.objects)}):")
for o in bpy.data.objects:
    parent_name = o.parent.name if o.parent else "(no parent)"
    if o.type == 'MESH':
        # Mesh details
        m = o.data
        print(f"  MESH        '{o.name}' parent={parent_name} mesh_data='{m.name}' verts={len(m.vertices)} polys={len(m.polygons)}")
    elif o.type in ('ARMATURE', 'EMPTY'):
        print(f"  {o.type:11s} '{o.name}' parent={parent_name}")

print(f"\nArmatures: {len(bpy.data.armatures)}")
print(f"Meshes: {len(bpy.data.meshes)}")
print(f"Actions: {len(bpy.data.actions)}")
