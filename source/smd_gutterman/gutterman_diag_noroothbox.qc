$modelname "ultrakill_prelude_test/diag/gutterman_noroothbox.mdl"
$upaxis Y
$scale 6000.0

$bodygroup "body"
{
    studio "gutterman_body.smd"
    studio "gutterman_casketless_body.smd"
}

$bodygroup "shield"
{
    studio "gutterman_shield.smd"
    blank
}

$bodygroup "casket_door"
{
    studio "gutterman_casket_door.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"

// Explicit hitboxes = studiomdl auto-set minus "Shield 1": the physical shield
// is a separate helper entity (zero damage); a body hitbox there would leak
// owner damage and leave a phantom hit zone after the shield breaks.
$hboxset "default"
$hbox 0 "Spine_01" -36.40 -35.82 -41.75 36.40 37.28 34.33
$hbox 0 "Thigh_L" -16.30 -6.94 -17.38 18.82 35.90 17.48
$hbox 0 "Leg_L" -15.06 -17.40 -15.20 15.89 37.79 23.44
$hbox 0 "Thigh_R" -18.83 -6.92 -17.35 16.33 35.89 17.48
$hbox 0 "Leg_R" -15.84 -17.38 -15.21 15.10 37.79 23.45
$hbox 0 "Spine_02" -58.55 -32.45 -44.86 36.99 82.55 60.68
$hbox 0 "Spine_03" -41.06 -9.77 -37.08 41.63 64.20 31.75
$hbox 0 "Upperarm_L" -18.12 -10.84 -24.07 26.87 59.16 22.36
$hbox 0 "Lowerarm_L" -15.76 -12.24 -15.70 16.05 46.06 15.53
$hbox 0 "Hand_L" -11.53 -3.07 -13.04 10.01 21.19 15.47
$hbox 0 "Index_01" -3.77 -2.81 -4.23 3.80 9.27 3.15
$hbox 0 "Index_02" -4.08 -1.89 -4.42 4.18 6.28 2.07
$hbox 0 "Index_03" -3.79 -2.10 -3.72 3.73 7.61 2.14
$hbox 0 "Middle_01" -3.78 -2.81 -4.22 3.79 9.26 3.15
$hbox 0 "Middle_02" -4.09 -1.90 -4.42 4.16 6.27 2.08
$hbox 0 "Middle_03" -3.80 -2.10 -3.72 3.71 7.61 2.15
$hbox 0 "Pinky_01" -3.79 -2.81 -4.20 3.78 9.26 3.17
$hbox 0 "Pinky_02" -4.11 -1.88 -4.40 4.15 6.29 2.10
$hbox 0 "Pinky_03" -3.82 -2.07 -3.71 3.69 7.64 2.16
$hbox 0 "Ring_01" -3.78 -2.81 -4.21 3.79 9.26 3.16
$hbox 0 "Ring_02" -4.09 -1.89 -4.41 4.16 6.28 2.08
$hbox 0 "Ring_03" -3.81 -2.08 -3.71 3.71 7.63 2.16
$hbox 0 "Upperarm_R" -25.14 -10.63 -26.75 19.58 38.80 21.82
$hbox 0 "Arm_R_End" -24.96 -46.84 -31.44 24.96 108.41 24.42
$hbox 0 "Barrels" -10.49 -1.91 -11.05 10.58 4.72 8.99
$hbox 0 "CasketDoor" -30.19 -55.38 -6.71 30.19 58.56 1.72

$sequence Idle            "idle"            loop fps 30
$sequence Walk            "walk"            loop fps 40.5
$sequence IdleShieldless  "idleshieldless"  loop fps 30
$sequence WalkShieldless  "walkshieldless"  loop fps 30
$sequence ShieldBreak     "shieldbreak"          fps 30
$sequence ShieldBash      "shieldbash"           fps 45
$sequence Smack           "smack"                fps 37.5
$sequence Death           "death"                fps 19.5
$sequence Shoot           "shoot"           loop fps 60

// Canon Shoot Layer combos: full-body locomotion + right-arm minigun fire
// (GuttermanMask drives Shoulder_R..Barrels only; merged at bake time).
// NOTE: the 3-way aim_pitch blend variant of these sequences made the model
// invisible in game (degenerate sequence bbox?) — reverted to plain sequences.
$sequence ShootIdle            "shootidle"            loop fps 30
$sequence ShootWalk            "shootwalk"            loop fps 40.5
$sequence ShootIdleShieldless  "shootidleshieldless"  loop fps 30
$sequence ShootWalkShieldless  "shootwalkshieldless"  loop fps 30

$collisionmodel "gutterman_collision.smd"
{
    $mass 500
}
