// Minos parasite (snake) — phase-2 eye parasites of the Corpse of King Minos.
// Model node = 'Parasite' GO (corpse-model units, snake x2 folded): $scale 200.
$modelname "ultrakill_prelude_test/minos_parasite.mdl"
$upaxis Y
$scale 200.0

$body "body" "parasite_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/minos/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

$attachment "muzzle" "ProjectileSpawnPos_(1)" 0 0 0
$attachment "head"   "neck" 0 0 0

$hboxset "default"
$hbox 1 "neck" -0.6 -0.6 -0.6 0.6 1.8 0.9
$hbox 0 "Spine.001" -0.6 -3 -0.6 0.6 0.5 0.6

$sequence Idle   "parasite_idle" loop fps 30
$sequence Spawn  "parasite_spawn" fps 30
$sequence Shoot1 "parasite_shoot1" fps 30
$sequence Shoot2 "parasite_shoot2" fps 30

$collisionmodel "parasite_phys.smd" {
}
