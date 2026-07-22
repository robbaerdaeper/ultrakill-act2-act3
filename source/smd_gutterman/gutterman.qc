$modelname "ultrakill_prelude_test/gutterman.mdl"
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

// REQUIRED: with an explicit $hboxset this studiomdl skips ALL bounding box
// computation and stamps the world box (+-16384) into the header hull AND
// every sequence bbox (proven by diag bisect 2026-06-10 — any single $hbox
// triggers it). $bbox restores the hull; the per-sequence bboxes must then be
// transplanted from a hitbox-free donor build:
//   1. studiomdl gutterman_diag_nohbox.qc   (same QC minus $hboxset)
//   2. studiomdl gutterman.qc
//   3. python gutterman_patch_seq_bbox.py
$bbox -36 -36 0 36 36 176

// Explicit hitboxes = studiomdl auto-set minus "Shield 1": the physical shield
// is a separate helper entity (zero damage); a body hitbox there would leak
// owner damage and leave a phantom hit zone after the shield breaks.
//
// WARNING: studiomdl multiplies $hbox values by $scale (proven 2026-07-07 —
// final-unit values here shipped as x6000 boxes, "hit anywhere" bug + coins
// homing into the sky). Values below are PRE-scale: desired final units / 6000.
$hboxset "default"
$hbox 0 "Armature" 0.00000000 -0.00105167 0.00000000 0.00271667 0.00000000 0.01118667
$hbox 0 "Spine_01" -0.00606667 -0.00597000 -0.00695833 0.00606667 0.00621333 0.00572167
$hbox 0 "Thigh_L" -0.00271667 -0.00115667 -0.00289667 0.00313667 0.00598333 0.00291333
$hbox 0 "Leg_L" -0.00251000 -0.00290000 -0.00253333 0.00264833 0.00629833 0.00390667
$hbox 0 "Thigh_R" -0.00313833 -0.00115333 -0.00289167 0.00272167 0.00598167 0.00291333
$hbox 0 "Leg_R" -0.00264000 -0.00289667 -0.00253500 0.00251667 0.00629833 0.00390833
$hbox 0 "Spine_02" -0.00975833 -0.00540833 -0.00747667 0.00616500 0.01375833 0.01011333
$hbox 0 "Spine_03" -0.00684333 -0.00162833 -0.00618000 0.00693833 0.01070000 0.00529167
$hbox 0 "Upperarm_L" -0.00302000 -0.00180667 -0.00401167 0.00447833 0.00986000 0.00372667
$hbox 0 "Lowerarm_L" -0.00262667 -0.00204000 -0.00261667 0.00267500 0.00767667 0.00258833
$hbox 0 "Hand_L" -0.00192167 -0.00051167 -0.00217333 0.00166833 0.00353167 0.00257833
$hbox 0 "Index_01" -0.00062833 -0.00046833 -0.00070500 0.00063333 0.00154500 0.00052500
$hbox 0 "Index_02" -0.00068000 -0.00031500 -0.00073667 0.00069667 0.00104667 0.00034500
$hbox 0 "Index_03" -0.00063167 -0.00035000 -0.00062000 0.00062167 0.00126833 0.00035667
$hbox 0 "Middle_01" -0.00063000 -0.00046833 -0.00070333 0.00063167 0.00154333 0.00052500
$hbox 0 "Middle_02" -0.00068167 -0.00031667 -0.00073667 0.00069333 0.00104500 0.00034667
$hbox 0 "Middle_03" -0.00063333 -0.00035000 -0.00062000 0.00061833 0.00126833 0.00035833
$hbox 0 "Pinky_01" -0.00063167 -0.00046833 -0.00070000 0.00063000 0.00154333 0.00052833
$hbox 0 "Pinky_02" -0.00068500 -0.00031333 -0.00073333 0.00069167 0.00104833 0.00035000
$hbox 0 "Pinky_03" -0.00063667 -0.00034500 -0.00061833 0.00061500 0.00127333 0.00036000
$hbox 0 "Ring_01" -0.00063000 -0.00046833 -0.00070167 0.00063167 0.00154333 0.00052667
$hbox 0 "Ring_02" -0.00068167 -0.00031500 -0.00073500 0.00069333 0.00104667 0.00034667
$hbox 0 "Ring_03" -0.00063500 -0.00034667 -0.00061833 0.00061833 0.00127167 0.00036000
$hbox 0 "Upperarm_R" -0.00419000 -0.00177167 -0.00445833 0.00326333 0.00646667 0.00363667
$hbox 0 "Arm_R_End" -0.00416000 -0.00780667 -0.00524000 0.00416000 0.01806833 0.00407000
$hbox 0 "Barrels" -0.00174833 -0.00031833 -0.00184167 0.00176333 0.00078667 0.00149833
$hbox 0 "CasketDoor" -0.00503167 -0.00923000 -0.00111833 0.00503167 0.00976000 0.00028667
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
