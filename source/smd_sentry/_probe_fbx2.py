"""Re-probe TurretBot.fbx with automatic_bone_orientation + force_connect_children."""
import bpy

FBX = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\assetstudio_turret\FBX_Animator\TurretBot\TurretBot.fbx"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(
    filepath=FBX,
    use_anim=False,
    automatic_bone_orientation=True,
    ignore_leaf_bones=False,
    force_connect_children=True,
)

types = {}
for o in bpy.data.objects:
    types[o.type] = types.get(o.type, 0) + 1
print("=== TYPE COUNTS ===", types)

for o in bpy.data.objects:
    if o.type == 'MESH':
        print(f"MESH: {o.name} verts={len(o.data.vertices)} mats={[m.name if m else None for m in o.data.materials]}")
        print(f"  vgroups: {len(o.vertex_groups)} -> {[vg.name for vg in list(o.vertex_groups)[:5]]}")
    elif o.type == 'ARMATURE':
        print(f"ARMATURE: {o.name} bones={len(o.data.bones)}")

print("=== ASSEMBLY ===")
# After this import method, sometimes meshes hide as data blocks even if no Object wraps them
print(f"bpy.data.meshes: {len(bpy.data.meshes)}")
for m in bpy.data.meshes:
    print(f"  mesh data: {m.name} verts={len(m.vertices)}")
print(f"bpy.data.armatures: {len(bpy.data.armatures)}")
for a in bpy.data.armatures:
    print(f"  arm data: {a.name} bones={len(a.bones)}")
