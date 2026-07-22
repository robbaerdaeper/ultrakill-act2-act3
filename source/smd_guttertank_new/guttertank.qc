// Guttertank (Greater Machine, Layer 7) — canon 1:1 port.
// SMD source: guttertank_build_assets.py (prefab-skeleton bake, no Blender).
// Prefab: gameprefabs 'Guttertank'; model child scale 3 => 1 model unit = 3 m.
// Strict canon scale would be $scale 120 (~360 su, canon envelope 8-9 m) but
// the shipped Gutterman sibling is 174 su, so we match: $scale 60 (~180 su).
// Controller state speeds are encoded in $sequence fps (30 * speed).
$modelname "ultrakill_prelude_test/guttertank.mdl"
$upaxis Y
$origin 0 0 0 0
$scale 60.0

$body "body" "guttertank_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/guttertank/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0

// canon points: rocket muzzle (Shootpoint under Cannon_end), chest/weakPoint
// (Spine = EnemyIdentifier.weakPoint). "head" LAST: ukcoin ricochets target
// the last attachment.
$attachment "muzzle" "Shootpoint" 0 0 0
$attachment "chest"  "Spine" 0 0 0
$attachment "head"   "Spine" 0 0 0

$hboxset "default"
$hbox 3 "Hips" -0.375 -0.150 -0.375 0.375 0.350 0.375
$hbox 2 "Spine" -0.500 -0.075 -0.850 0.500 1.175 0.550
$hbox 2 "Spine" -0.300 0.160 0.375 0.300 1.160 1.125
$hbox 4 "Shoulder_L" -0.150 -0.275 -0.330 0.150 0.475 0.330
$hbox 4 "Uppearm_L" -0.150 0.000 -0.225 0.150 0.660 0.225
$hbox 4 "Forearm_L" -0.350 -0.250 -0.175 0.150 0.750 0.175
$hbox 4 "Hand_L" -0.150 0.000 -0.100 0.150 0.400 0.100
$hbox 5 "Shoulder_R" -0.150 -0.275 -0.330 0.150 0.475 0.330
$hbox 5 "Uppearm_R" -0.150 0.000 -0.225 0.150 0.660 0.225
$hbox 5 "Cannon" -0.500 -0.600 -0.300 0.100 1.900 0.300
$hbox 6 "Leg_L" -0.315 -0.137 -0.092 0.185 0.663 0.408
$hbox 6 "Foot_L" -0.200 -0.250 -0.200 0.200 0.750 0.200
$hbox 7 "Leg_R" -0.315 -0.137 -0.092 0.185 0.663 0.408
$hbox 7 "Foot_R" -0.200 -0.250 -0.200 0.200 0.750 0.200

$sequence Idle         "guttertank_idle" loop fps 30
$sequence Walk         "guttertank_walk" loop fps 37.5
$sequence Punch        "guttertank_punch" fps 36
$sequence Shoot        "guttertank_shoot" fps 37.5
$sequence Landmine     "guttertank_landmine" fps 45
$sequence Death        "guttertank_death" fps 30
$sequence PunchStagger "guttertank_punchstagger" fps 30

$collisionmodel "guttertank_phys.smd" {
}
