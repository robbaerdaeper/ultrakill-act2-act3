// Providence (Lesser Angel, Layer 8) — canon 1:1 flat-quad angel.
// SMD source: providence_build_assets.py (prefab-skeleton bake, no Blender).
// Enemy root scale 3 * model node 4.03105 * 25 su/m => $scale 302.33.
// Polish 2026-07-10: read too big in-game — x0.8 => $scale 241.86.
// Flat billboard model: Lua faces it to the player (Virtue pattern).
$modelname "ultrakill_prelude_test/providence.mdl"
$upaxis Y
$scale 241.86

$body "body" "providence_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/providence/"
$surfaceprop "glass"
$contents "solid"
$illumposition 0 0 0

// eye = projectile origin (canon: fires the magenta orb from the eye)
$attachment "eye" "Providence_Eye" 0 0 0

$hboxset "default"
// flat golden square body around the eye (given some Z depth for traces)
$hbox 1 "Providence_Root" -0.16 -0.17 -0.09 0.16 0.13 0.09

$sequence Idle      "providence_idle" loop fps 30
$sequence Shoot     "providence_shoot" fps 30
$sequence BeamPrep  "providence_beamprep" fps 30
$sequence BeamShoot "providence_beamshoot" fps 30

$collisionmodel "providence_phys.smd" {
}
