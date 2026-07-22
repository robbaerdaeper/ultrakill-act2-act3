// Arena (sandbox) Minotaur — canon 7-1 phase-2 boss, 0.4x scale.
// SMD source: minotaur_build_assets.py (scene-skeleton bake, no Blender).
// Prefab: gameprefabs 'Minotaur' (EnemySpawnableInstance = in-game sandbox unit).
// Minotaur_Rigging02 node scale 2 => 1 model unit = 2 m. Canon 1:1 was
// $scale 80 (40 su/m) — a 440 su giant; sandbox build ships 0.5x:
// $scale 40 => 20 su per canon meter (UKMinotaur.UNIT must match).
$modelname "ultrakill_prelude_test/minotaur.mdl"
$upaxis Y
$scale 40.0

$body "body" "minotaur_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/minotaur/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

// skin 0 = canon arena (broken shell, T_Minotaur_Hurt); skin 1 = pristine
$texturegroup "skinfamilies"
{
    { "minotaur_body"       "minotaur_staff" }
    { "minotaur_body_fresh" "minotaur_staff" }
}

// canon points: hammer head (impact/explosions), meat spawn (Hand_R child
// 'Meat' at (0.176,0.65,0.093)m -> mirrorX), belly, ram check ahead of head.
// "head" LAST: ukcoin ricochets target the last attachment.
$attachment "hammer"   "HammerPoint" 0 0 0
$attachment "staffbase" "Staff" 0 0 0
$attachment "meat"     "Hand_R" -0.176 0.65 0.093
$attachment "belly"    "Belly" 0 0 0
$attachment "weakpoint" "Hurtable" 0 0 0
$attachment "head"     "Head" 0 0 0

$hboxset "default"
// weak point: canon Hurtable box on the fractured head (hitgroup 1)
$hbox 1 "Hurtable" -0.25 -0.75 -0.375 0.25 0.75 0.375
$hbox 1 "Head" -0.792 -0.569 -0.704 0.792 1.408 1.268
$hbox 2 "Spine_02" -2.002 -1.590 -2.344 2.283 2.159 1.506
$hbox 2 "Spine_03" -2.078 -1.942 -1.855 1.534 1.684 1.465
$hbox 2 "Neck" -0.771 -0.333 -0.793 0.645 1.511 0.746
$hbox 3 "Spine_01" -1.773 -0.648 -2.753 2.309 3.122 1.182
$hbox 3 "Belly" -1.749 -1.350 -0.946 1.685 1.416 1.773
$hbox 4 "UpperArm_L" -0.401 -0.921 -0.528 0.663 1.226 0.381
$hbox 4 "Forearm_L" -0.325 -0.385 -0.510 0.354 2.046 0.390
$hbox 4 "LowerHand_L" -0.173 -0.011 -0.166 0.142 0.317 0.173
$hbox 4 "UpperHand_L" -0.152 -0.016 -0.603 0.141 0.574 0.160
$hbox 5 "UpperArm_R" -0.320 -0.090 -0.357 0.469 1.167 0.346
$hbox 5 "Forearm_R" -0.262 -0.449 -0.332 0.471 2.112 0.419
$hbox 5 "Hand_R" -0.289 -0.488 -0.404 0.210 0.885 0.334
$hbox 6 "Rear_Thigh_L" -0.599 -1.167 -0.633 0.625 1.393 0.323
$hbox 6 "Rear_Calf_L" -0.262 -0.254 -0.337 0.308 1.602 0.258
$hbox 6 "Rear_Foot_L" -0.240 -0.143 -0.037 0.236 0.540 0.226
$hbox 6 "Front_Thigh_L" -0.555 -0.745 -0.673 0.450 1.353 0.530
$hbox 6 "Front_Calf_L" -0.567 -0.294 -0.307 0.370 1.399 0.325
$hbox 6 "Front_Foot_L" -0.100 -0.067 -0.315 0.059 0.541 0.373
$hbox 7 "Rear_Thigh_R" -0.598 -1.164 -0.323 0.626 1.393 0.631
$hbox 7 "Rear_Calf_R" -0.262 -0.254 -0.258 0.308 1.520 0.337
$hbox 7 "Rear_Foot_R" -0.240 -0.143 -0.213 0.236 0.540 0.037
$hbox 7 "Front_Thigh_R" -0.581 -1.051 -0.441 0.363 1.821 0.672
$hbox 7 "Front_Calf_R" -0.629 -0.334 -0.374 0.287 1.428 0.271
$hbox 7 "Front_Foot_R" -0.100 -0.067 -0.343 0.059 0.541 0.345

$sequence HurtIdle      "minotaur_hurtidle" loop fps 30
$sequence IdleCalm      "minotaur_idlecalm" loop fps 30
$sequence Run           "minotaur_run" loop fps 30
$sequence HammerTantrum "minotaur_hammertantrum" fps 30
$sequence HammerSmash   "minotaur_hammersmash" fps 30
$sequence MeatHigh      "minotaur_meathigh" fps 30
$sequence MeatLow       "minotaur_meatlow" fps 30
$sequence RamWindup     "minotaur_ramwindup" fps 30
$sequence RamRun        "minotaur_ramrun" loop fps 30
$sequence RamBonk       "minotaur_rambonk" fps 30
$sequence RamSwing      "minotaur_ramswing" fps 30
$sequence RamParried    "minotaur_ramparried" fps 30
$sequence Death         "minotaur_death" fps 30

$collisionmodel "minotaur_phys.smd" {
}
