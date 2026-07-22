// Insurrectionist leg gib (l) — canon Death() detaches thigh.L subtree.
$modelname "ultrakill_prelude_test/insurrectionist_gib_leg_l.mdl"
$upaxis Y
// tuned 2026-07-07: death gibs read oversized next to the 0.95x body
$scale 40.0 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 80)
$body "leg" "sisy_gib_leg_l.smd"
$cdmaterials "models/ultrakill_prelude_test/insurrectionist/"
$surfaceprop "flesh"
$illumposition 0 0 0
$sequence idle "sisy_gib_leg_l" fps 1
$collisionmodel "sisy_gib_phys.smd" {
}
