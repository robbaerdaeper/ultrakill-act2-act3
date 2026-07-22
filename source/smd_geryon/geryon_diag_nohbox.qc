$modelname "ultrakill_prelude_test/diag/geryon_nohbox.mdl"
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
