$modelname "ultrakill_prelude_test/fleshprison.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 30.0
$body "body" "fleshprison_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "flesh"
$contents "solid"

$sequence Idle "fleshprison_ref" loop fps 30

$collisionmodel "fleshprison_ref.smd" {
    $concave
    $maxconvexpieces 24
}
