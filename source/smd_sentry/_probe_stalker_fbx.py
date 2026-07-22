"""Probe Stalker.fbx for comparison."""
import bpy

FBX = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\assetstudio_stalker\FBX_Animator\Stalker\Stalker.fbx"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX, use_anim=False)

types = {}
for o in bpy.data.objects:
    types[o.type] = types.get(o.type, 0) + 1
print("Stalker.fbx TYPES:", types)

print("meshes:", len(bpy.data.meshes), "armatures:", len(bpy.data.armatures))
for o in bpy.data.objects:
    if o.type == 'MESH':
        print(f"MESH {o.name}: verts={len(o.data.vertices)} mats={[m.name for m in o.data.materials if m]}")
    elif o.type == 'ARMATURE':
        print(f"ARM {o.name}: bones={len(o.data.bones)}")
