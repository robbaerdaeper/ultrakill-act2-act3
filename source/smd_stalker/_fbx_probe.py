"""Inspect the AssetStudio-exported Stalker FBX in Blender."""
import bpy

FBX = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\assetstudio_stalker\FBX_Animator\Stalker\Stalker.fbx"

bpy.ops.wm.read_factory_settings(use_empty=True)

# Try to enable Source Tools
try:
    bpy.ops.preferences.addon_enable(module="io_scene_valvesource")
    print("[probe] Source Tools enabled")
except Exception as e:
    print(f"[probe] addon_enable: {e}")

# Import FBX with animations
bpy.ops.import_scene.fbx(filepath=FBX, use_anim=True, anim_offset=1.0)

print("\n[probe] === objects ===")
for o in bpy.data.objects:
    print(f"  {o.type:10s} '{o.name}' parent={o.parent.name if o.parent else 'NONE'} scale={list(o.scale)}")

print("\n[probe] === armatures ===")
for a in bpy.data.armatures:
    print(f"  '{a.name}' bones={len(a.bones)}")
    for b in a.bones:
        parent = b.parent.name if b.parent else 'ROOT'
        print(f"    {b.name} parent={parent}")

print("\n[probe] === meshes ===")
for m in bpy.data.meshes:
    print(f"  '{m.name}' verts={len(m.vertices)} polys={len(m.polygons)}")

print("\n[probe] === actions (animations) ===")
for act in bpy.data.actions:
    fr_start, fr_end = act.frame_range
    print(f"  '{act.name}' frames=[{fr_start:.0f}..{fr_end:.0f}] duration={(fr_end-fr_start)/30:.2f}s @ 30fps")

print("\n[probe] DONE")
