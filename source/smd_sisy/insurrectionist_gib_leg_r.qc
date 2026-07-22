// Insurrectionist leg gib (r) — canon Death() detaches thigh.R subtree.
$modelname "ultrakill_prelude_test/insurrectionist_gib_leg_r.mdl"
$upaxis Y
// tuned 2026-07-07: death gibs read oversized next to the 0.95x body
$scale 40.0 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 80)
$body "leg" "sisy_gib_leg_r.smd"
$cdmaterials "models/ultrakill_prelude_test/insurrectionist/"
$surfaceprop "flesh"
$illumposition 0 0 0
$sequence idle "sisy_gib_leg_r" fps 1
$collisionmodel "sisy_gib_phys.smd" {
}
