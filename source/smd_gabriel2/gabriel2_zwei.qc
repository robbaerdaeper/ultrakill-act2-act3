// Gabriel 2nd summoned sword (spiral swords zweihander, light construct).
// Static bake of the GabrielThrownZwei prefab mesh (units = meters).
$modelname "ultrakill_prelude_test/gabriel2_zwei.mdl"
$upaxis Y
$origin 0 0 0 0
$scale 18.0 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 40)
$body "body" "gabriel2_zwei.smd"
$cdmaterials "models/ultrakill_prelude_test/gabriel2/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0
$sequence Idle "gabriel2_zwei" fps 30
$collisionmodel "gabriel2_zwei_phys.smd" {
}
