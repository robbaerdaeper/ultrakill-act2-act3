// Earthmover Defense System — Mortar Launcher (CentaurMortar, 7-4).
// Префаб root scale 10 => $scale 10*40 = 400 (канон 1:1, ~9.4 м).
// Origin префаба у ВЕРХА: меш уходит вниз до y=-0.84 (-336 su) — Lua поднимает.
$modelname "ultrakill_prelude_test/em_mortar.mdl"
$upaxis Y
$scale 400.0

$body "body" "mortar_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/earthmover/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0

$attachment "muzzle" "ShootPoint" 0 0 0
$attachment "barrel" "Barrel3" 0 0 0

$hboxset "default"
$hbox 0 "CentaurMortar" -0.55 -0.85 -0.27 0.38 0.1 0.27

$sequence idle   "mortar_ref" loop fps 30
$sequence deploy "mortar_deploy" fps 30
$sequence shoot  "mortar_shoot" fps 30

$collisionmodel "mortar_phys.smd" {
}
