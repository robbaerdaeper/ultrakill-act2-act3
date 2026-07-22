$modelname "ultrakill_prelude_test/leviathan.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 30.0
$body "body" "leviathan_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "flesh"
$contents "solid"

$sequence Idle "leviathan_ref" loop fps 30

$collisionmodel "leviathan_ref.smd" {
    $concave
    $maxconvexpieces 24
}
