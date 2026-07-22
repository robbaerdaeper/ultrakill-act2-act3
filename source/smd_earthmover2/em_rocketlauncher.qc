// Earthmover Defense System — Rocket Launcher (CentaurRocketLauncher, 7-4).
// Префаб root scale 10 => $scale 400 (канон 1:1). Origin у верха стойки.
// Наведение: Lua ManipulateBoneAngles на кость Hinge_1 (DroneFlesh-паттерн).
$modelname "ultrakill_prelude_test/em_rocketlauncher.mdl"
$upaxis Y
$scale 400.0

$body "body" "rocket_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/earthmover/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0

$attachment "muzzle" "ShootPoint" 0 0 0
$attachment "hinge" "Hinge_1" 0 0 0

$hboxset "default"
$hbox 0 "CentaurRocketLauncher" -0.08 -0.65 -0.28 0.53 0.06 0.17

$sequence idle "rocket_ref" loop fps 30

$collisionmodel "rocket_phys.smd" {
}
