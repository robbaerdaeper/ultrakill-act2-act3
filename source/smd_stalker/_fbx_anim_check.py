"""Re-probe FBX with explicit anim import flags."""
import bpy

FBX = r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\assetstudio_stalker\FBX_Animator\Stalker\Stalker.fbx"

bpy.ops.wm.read_factory_settings(use_empty=True)
try: bpy.ops.preferences.addon_enable(module="io_scene_valvesource")
except Exception: pass

# Aggressive anim import
bpy.ops.import_scene.fbx(
    filepath=FBX,
    use_anim=True,
    anim_offset=0.0,
    bake_space_transform=False,
    use_custom_props=True,
    automatic_bone_orientation=False,
)

print(f"\nActions after import: {len(bpy.data.actions)}")
for act in bpy.data.actions:
    print(f"  '{act.name}' frames={act.frame_range}")

print(f"\nNLA tracks per object:")
for o in bpy.data.objects:
    if o.animation_data and o.animation_data.nla_tracks:
        for tr in o.animation_data.nla_tracks:
            for s in tr.strips:
                print(f"  {o.name} track={tr.name} strip={s.name} action={s.action.name if s.action else 'NONE'}")

print(f"\nArmature actions in fcurves:")
arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
if arm:
    print(f"  Armature '{arm.name}' animation_data={'YES' if arm.animation_data else 'NO'}")
    if arm.animation_data:
        print(f"    action={arm.animation_data.action.name if arm.animation_data.action else 'NONE'}")
