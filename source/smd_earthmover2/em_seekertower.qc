// Earthmover Defense System — Seeker Tower (CentaurTower, 7-4).
// Префаб root scale 10 => $scale 400 (канон 1:1, ~8.7 м). Origin у верха.
$modelname "ultrakill_prelude_test/em_seekertower.mdl"
$upaxis Y
$scale 400.0

$body "body" "tower_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/earthmover/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0

$attachment "tip" "Pole_Top" 0 0.6 0
$attachment "muzzle" "Pole_Top" 0 0.3 0

$hboxset "default"
$hbox 0 "CentaurTower" -0.09 -0.86 -0.08 0.09 0.02 0.08

$sequence idle   "tower_ref" loop fps 30
$sequence deploy "tower_deploy" fps 30
$sequence shoot  "tower_shoot" fps 30

$collisionmodel "tower_phys.smd" {
}
