"""Deep probe — map every Mesh data block to its owning Object(s)."""
import bpy

input_glb = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\extracted\Assets\PrefabHierarchyObject\Stalker_0.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_glb)

print(f"[probe3] All MESH-type Objects + their Mesh data:")
for o in bpy.data.objects:
    if o.type == 'MESH':
        m = o.data
        parent = o.parent.name if o.parent else "(no parent)"
        print(f"  Object '{o.name}' parent={parent}  -> Mesh data '{m.name}' v={len(m.vertices)} p={len(m.polygons)}")

print(f"\n[probe3] Mesh data blocks and their users (objects):")
for m in bpy.data.meshes:
    users = [o.name for o in bpy.data.objects if o.type == 'MESH' and o.data == m]
    print(f"  Mesh '{m.name}' v={len(m.vertices)} p={len(m.polygons)} used_by={users}")

print(f"\n[probe3] Collections:")
for c in bpy.data.collections:
    objs = [o.name for o in c.objects]
    print(f"  Collection '{c.name}': {len(objs)} objects = {objs[:10]}{'...' if len(objs)>10 else ''}")

print(f"\n[probe3] Total scene objects (incl hidden):")
print(f"  Visible/scene: {len(bpy.context.scene.objects)}")
print(f"  All data: {len(bpy.data.objects)}")
