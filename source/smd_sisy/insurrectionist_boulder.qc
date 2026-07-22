// Insurrectionist boulder (dead Malicious Face) — flying-attack entity model.
$modelname "ultrakill_prelude_test/insurrectionist_boulder.mdl"
$upaxis Y
$scale 50.0 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 100)
$body "boulder" "sisy_boulder_solo.smd"
$cdmaterials "models/ultrakill_prelude_test/insurrectionist/"
$surfaceprop "flesh"
$illumposition 0 0 0
$sequence idle "sisy_boulder_solo" fps 1
$collisionmodel "sisy_boulder_phys.smd" {
}
