$modelname "ultrakill_prelude_test/earthmover.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 80.0
$body "body" "earthmover_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "stone"
$contents "solid"

$sequence Idle "earthmover_ref" loop fps 30

$collisionmodel "earthmover_ref.smd" {
    $concave
    $maxconvexpieces 24
}
