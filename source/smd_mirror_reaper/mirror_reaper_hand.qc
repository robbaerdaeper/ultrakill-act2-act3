// Mirror Reaper Phantom Hand (GroundWave) — 2026-07-03 port.
// Canon world height 6.74 m; 1 canon m = 0.004613 bone units => $scale 8671.
$modelname "ultrakill_prelude_test/mirror_reaper_hand.mdl"
$upaxis Y
$origin 0 0 0 0
$scale 8671.0

$body "body" "mirror_reaper_hand_body_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/mirror_reaper/"

$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

$attachment "palm" "Bone" 0 0 0

$sequence HandIdle "handidle" loop fps 30
$sequence HandGrab "handgrab"      fps 30

$collisionmodel "mirror_reaper_hand_phys.smd" {
}
