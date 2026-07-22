$modelname "ultrakill_prelude_test/geryon.mdl"
// Geryon (Supreme Demon, 8-4 boss) - canon 1:1 bake.
// SMD source: geryon_build_assets.py (scene-skeleton bake, no Blender).
// SMD units = Unity metres (model node = enemy root); 25 su/m (Layer 8
// scale family, Providence/Virtue) => $scale 25.
// GMod studiomdl kills hull+sequence bboxes when $hboxset is present
// (gutterman lesson): $bbox restores the hull, sequence bboxes are
// transplanted from the nohbox diag donor by gutterman_patch_seq_bbox.py.
$upaxis Y
$scale 25
$bbox -550 -550 -550 550 550 1050

$body "body" "geryon_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/geryon/"
$surfaceprop "rock"
$contents "solid"
$illumposition 0 62 0

$attachment "lefthand" "MainHand_L" 0.0000 2.1875 -4.3750
$attachment "righthand" "MainHand_R" 0.0000 2.1875 -4.3750
$attachment "bow" "ROOT_BOW" -0.0000 4.3750 0.0000
$attachment "weakpoint" "Weakpoint_1" -0.0000 2.6250 -0.8750

$hboxset "default"
$hbox 2 "Spine_01" -4.3750 -1.7500 -6.1250 4.3750 8.7500 2.6250
$hbox 4 "MainUpperarm_L.001" -2.6250 -4.3750 -2.6250 2.6250 13.1250 2.6250
$hbox 4 "MainForearm_L" -1.7500 -1.7500 -1.7500 1.7500 8.7500 1.7500
$hbox 4 "MainHand_L" -1.7500 0.0000 -0.8750 1.7500 5.2500 0.8750
$hbox 5 "MainUpperarm_R.001" -2.6250 -4.3750 -2.6250 2.6250 13.1250 2.6250
$hbox 5 "MainForearm_R" -1.7500 -1.7500 -1.7500 1.7500 8.7500 1.7500
$hbox 5 "MainHand_R" -1.7500 0.0000 -0.8750 1.7500 5.2500 0.8750
$hbox 2 "Spine_02" -4.3750 -3.5000 -6.1250 4.3750 7.0000 2.6250
$hbox 3 "Spine_03" -4.3750 -3.5000 -4.3750 4.3750 7.0000 2.6250
$hbox 2 "Spine_Body_Base" -3.5000 -3.5000 -5.2500 3.5000 3.5000 1.7500
$hbox 0 "CenterBody_Spine_1" -1.3125 -0.4375 -2.1875 1.3125 3.9375 2.1875
$hbox 0 "CenterBody_Spine2" -1.3125 -1.3125 -2.1875 1.3125 4.8125 2.1875
$hbox 0 "CenterHand_M" -1.0500 -1.3125 -1.7500 0.7000 4.8125 1.7500
$hbox 0 "CenterUpperarm_L" -1.0500 -1.0938 -1.0500 1.0500 4.5938 1.0500
$hbox 0 "CenterForearm_L" -0.7000 -0.8750 -0.7000 0.7000 4.3750 0.7000
$hbox 0 "CenterHand_L" -0.4375 0.4375 -0.3500 0.4375 2.1875 0.3500
$hbox 0 "CenterUpperarm_R" -1.0500 -1.0938 -1.0500 1.0500 4.5938 1.0500
$hbox 0 "CenterForearm_R" -0.7000 -0.8750 -0.7000 0.7000 4.3750 0.7000
$hbox 0 "CenterHand_R" -0.4375 0.4375 -0.3500 0.4375 2.1875 0.3500
$hbox 0 "LeftBody_Spine_1" -0.8750 0.4375 -2.1875 1.7500 4.8125 2.1875
$hbox 0 "LeftBody_Spine_2" -1.0938 -0.4375 -2.1875 1.9688 3.9375 2.1875
$hbox 0 "LeftHand_M" -0.8750 -0.8750 -1.7500 0.8750 4.3750 1.7500
$hbox 0 "LeftUpperarm_L" -1.0500 -1.0938 -1.0500 1.0500 4.5938 1.0500
$hbox 0 "LeftForearm_L" -0.7000 -0.8750 -0.7000 0.7000 4.3750 0.7000
$hbox 0 "LeftHand_L" -0.4813 0.4375 -0.3500 0.8313 2.1875 0.3500
$hbox 0 "LeftUpperarm_R" -1.0500 -1.0938 -1.0500 1.0500 4.5938 1.0500
$hbox 0 "LeftForearm_R" -0.7000 -0.8750 -0.7000 0.7000 4.3750 0.7000
$hbox 0 "LeftHand_R" -0.8313 0.4375 -0.3500 0.4813 2.1875 0.3500
$hbox 0 "RightBody_Spine_1" -0.8750 0.4375 -1.7500 1.7500 4.8125 1.7500
$hbox 0 "RightBody_Spine_2" -1.0938 -0.4375 -2.1875 1.9688 3.9375 2.1875
$hbox 0 "RightHand_M" -0.8750 -0.8750 -1.7500 0.8750 4.3750 1.7500
$hbox 0 "RightUpperarm_L" -0.8750 -0.8750 -0.8750 0.8750 4.3750 0.8750
$hbox 0 "RightForearm_L" -0.7000 -0.8750 -0.7000 0.7000 3.5000 0.7000
$hbox 0 "RightHand_L" -0.1750 0.4375 -0.6563 0.5250 2.1875 0.6563
$hbox 0 "RightUpperarm_R" -0.8750 -0.8750 -0.8750 0.8750 4.3750 0.8750
$hbox 0 "RightForearm_R" -0.7000 -0.8750 -0.7000 0.7000 3.5000 0.7000
$hbox 0 "RightHand_R" -0.5250 0.4375 -0.6563 0.1750 2.1875 0.6563
$hbox 0 "WingElbow_L" -1.3125 -4.3750 -0.4375 2.1875 4.3750 4.8125
$hbox 0 "WingMiddle1_L" -2.1875 -0.8750 -3.5000 0.4375 7.8750 5.2500
$hbox 0 "WingMiddle2_L" -2.6250 -0.8750 -4.8125 0.0000 7.8750 6.5625
$hbox 0 "WingMiddle3_L" -3.9375 -3.9375 -5.6875 0.4375 7.4375 7.4375
$hbox 0 "WingElbow_R" -1.3125 -4.3750 -4.8125 2.1875 4.3750 0.4375
$hbox 0 "WingMiddle1_R" -2.1875 -0.8750 -5.2500 0.4375 7.8750 3.5000
$hbox 0 "WingMiddle2_R" -2.6250 -0.8750 -6.5625 0.0000 7.8750 4.8125
$hbox 0 "WingMiddle3_R" -3.9375 -3.9375 -7.4375 0.4375 7.4375 5.6875
$hbox 0 "Tail_1" -3.0625 -2.6250 -2.6250 3.0625 6.1250 4.3750
$hbox 0 "Tail_2" -4.3750 -7.0000 -4.3750 4.3750 10.5000 4.3750
$hbox 0 "Tail_3" -3.5000 -3.0625 -3.5000 3.5000 10.0625 3.5000
$hbox 0 "Tail_4" -2.6250 -2.6250 -2.6250 2.6250 9.6250 2.6250
$hbox 0 "Tail_5" -2.6250 -2.6250 -2.6250 2.6250 9.6250 2.6250
$hbox 0 "Tail_6" -1.7500 -2.6250 -1.7500 1.7500 6.1250 1.7500
$hbox 0 "Tail_7" -1.7500 -2.6250 -1.7500 1.7500 6.1250 1.7500

$sequence Idle            "geryon_idle" loop fps 30
$sequence BowUp           "geryon_bowup" fps 30
$sequence BowForward      "geryon_bowforward" fps 30
$sequence WaveClap        "geryon_waveclap" fps 30
$sequence PalmProjectiles "geryon_palmprojectiles" fps 30
$sequence StunStart       "geryon_stunstart" fps 30
$sequence StunState       "geryon_stunstate" loop fps 30
$sequence StunStop        "geryon_stunstop" fps 30
$sequence Intro           "geryon_intro" fps 30
$sequence Death           "geryon_death" fps 30
$sequence DeathEnd        "geryon_deathend" loop fps 30

$collisionmodel "geryon_phys.smd" {
    $concave
}
