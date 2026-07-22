// Sisyphean Insurrectionist — canon Supreme Husk, 1:1 scale.
// SMD source: sisy_build_assets.py (prefab-skeleton bake, no Blender).
// Prefab: gameprefabs 'Sisyphus'. Rig 'ArmStretcherRigIK' scale 2.5 =>
// 1 model unit = 2.5 m = 100 su ($scale 100).
$modelname "ultrakill_prelude_test/insurrectionist.mdl"
$upaxis Y
$scale 50.0 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 100)

$body "body" "sisy_ref.smd"
$body "arm" "sisy_armbg.smd"
$bodygroup "boulder"
{
    studio "sisy_boulderbg.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/insurrectionist/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

// boulder center on the stretchy hand (flying-boulder spawn/FX point).
// "head" LAST: ukcoin ricochets target the last attachment (no head canon —
// use upper chest, spine.003 = canon weakPoint/chest).
$attachment "boulder" "hand.L.006" 0.1137 0.9016 -0.0278
$attachment "chest"   "spine.003" 0.19 0.34 0.05
$attachment "head"    "spine.003" 0.19 0.60 0.05

$hboxset "default"
$hbox 3 "spine" -0.601 -0.230 -0.301 0.600 0.785 0.557
$hbox 3 "spine.001" -0.331 -0.004 -0.296 0.249 0.405 0.376
$hbox 2 "spine.002" -0.267 -0.153 -0.367 0.482 0.845 0.498
$hbox 2 "spine.003" -0.220 -0.148 -0.395 0.595 0.832 0.500
$hbox 4 "shoulder.L" -0.268 -0.049 -0.209 0.278 0.571 0.204
$hbox 4 "upper_arm.L" -0.338 -0.063 -0.277 0.193 1.057 0.211
$hbox 4 "forearm.L" -0.244 0.021 -0.197 0.218 0.977 0.177
$hbox 4 "hand.L" -0.178 0.010 -0.213 0.181 0.537 0.208
$hbox 4 "hand.L.001" -0.191 0.116 -0.197 0.185 0.200 0.222
$hbox 4 "hand.L.002" -0.151 0.022 -0.201 0.233 0.433 0.153
$hbox 4 "hand.L.003" 0.040 0.307 -0.151 0.099 0.353 0.108
$hbox 4 "hand.L.004" -0.101 0.020 -0.114 0.117 0.388 0.112
$hbox 6 "thigh.L" -0.296 -0.118 -0.306 0.251 1.444 0.342
$hbox 6 "shin.L" -0.230 -0.088 -0.161 0.222 1.408 0.359
$hbox 6 "foot.L" -0.157 -0.104 -0.197 0.194 0.715 0.309
$hbox 7 "thigh.R" -0.251 -0.118 -0.306 0.296 1.444 0.342
$hbox 7 "shin.R" -0.222 -0.088 -0.161 0.230 1.193 0.359
$hbox 7 "foot.R" -0.194 -0.165 -0.197 0.157 0.715 0.309
$hbox 9 "hand.L.006" -1.169 -0.097 -1.191 1.397 2.592 1.135

$sequence Idle            "sisy_idle" loop fps 30
$sequence Walking         "sisy_walking" loop fps 30
$sequence Jump            "sisy_jump" fps 30
$sequence Landing         "sisy_landing" fps 30
$sequence Knockdown       "sisy_knockdown" fps 30
$sequence Stomp           "sisy_stomp" fps 30
$sequence OverheadSlam    "sisy_overheadslam" fps 30
$sequence HorizontalSwing "sisy_horizontalswing" fps 30
$sequence Stab            "sisy_stab" fps 30
$sequence AirStab         "sisy_airstab" fps 30
$sequence AirStabCancel   "sisy_airstabcancel" fps 30

$collisionmodel "sisy_phys.smd" {
}
