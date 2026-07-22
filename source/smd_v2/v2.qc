$modelname "ultrakill_prelude_test/v2.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 25.0
$body "body" "v2_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "metal_bouncy"
$contents "solid"

$sequence Idle "v2_ref" loop fps 30

$collisionmodel "v2_ref.smd" {
    $concave
    $maxconvexpieces 24
}
