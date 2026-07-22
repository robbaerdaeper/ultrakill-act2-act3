// Guttertank rocket — canon RocketEnemy prefab static bake.
$modelname "ultrakill_prelude_test/guttertank_rocket.mdl"
$upaxis Y
$scale 20.0
$staticprop
$body "body" "guttertank_rocket.smd"
$cdmaterials "models/ultrakill_prelude_test/guttertank/"
$surfaceprop "metal"
$illumposition 0 0 0
$sequence idle "guttertank_rocket.smd"
$collisionmodel "guttertank_rocket.smd" {
    $automass
}
