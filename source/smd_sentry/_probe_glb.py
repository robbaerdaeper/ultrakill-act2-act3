"""Probe TurretBot.glb for meshes + skinning."""
import bpy

GLB = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\extracted\Assets\TurretBot.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

types = {}
for o in bpy.data.objects:
    types[o.type] = types.get(o.type, 0) + 1
print("TYPES:", types)

print("meshes:", len(bpy.data.meshes), "armatures:", len(bpy.data.armatures))
for o in bpy.data.objects:
    if o.type == 'MESH':
        print(f"MESH {o.name}: verts={len(o.data.vertices)} polys={len(o.data.polygons)} mats={[m.name for m in o.data.materials if m]} vgroups={len(o.vertex_groups)}")
        if o.vertex_groups:
            print(f"  first vgroup names: {[vg.name for vg in list(o.vertex_groups)[:15]]}")
    elif o.type == 'ARMATURE':
        print(f"ARM {o.name}: bones={len(o.data.bones)}")
        if o.data.bones:
            print(f"  bone names (first 15): {[b.name for b in list(o.data.bones)[:15]]}")
