// Gabriel 2nd combined swords (thrown projectile / Gattai visual).
// Static bake of the GabrielCombinedSwords prefab sword pair (units = meters).
$modelname "ultrakill_prelude_test/gabriel2_combined.mdl"
$upaxis Y
$origin 0 0 0 0
$scale 18.0 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 40)
$body "body" "gabriel2_combined.smd"
$cdmaterials "models/ultrakill_prelude_test/gabriel2/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0
$sequence Idle "gabriel2_combined" fps 30
$collisionmodel "gabriel2_combined_phys.smd" {
}
