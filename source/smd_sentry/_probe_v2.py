"""Probe re-exported TurretBot.fbx v2."""
import bpy

FBX = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\assetstudio_sentry_v2\TurretBot\FBX_GameObjects\TurretBot\TurretBot.fbx"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX, use_anim=False)

types = {}
for o in bpy.data.objects:
    types[o.type] = types.get(o.type, 0) + 1
print("TYPES:", types)
print(f"meshes: {len(bpy.data.meshes)} armatures: {len(bpy.data.armatures)}")
for o in bpy.data.objects:
    if o.type == 'MESH':
        print(f"MESH {o.name}: verts={len(o.data.vertices)} polys={len(o.data.polygons)} mats={[m.name if m else None for m in o.data.materials]} vgroups={len(o.vertex_groups)}")
        if o.vertex_groups:
            print(f"  vgroups (first 15): {[vg.name for vg in list(o.vertex_groups)[:15]]}")
    elif o.type == 'ARMATURE':
        print(f"ARM {o.name}: bones={len(o.data.bones)}")
        if o.data.bones:
            print(f"  bones (first 15): {[b.name for b in list(o.data.bones)[:15]]}")
