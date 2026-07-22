$modelname "ultrakill_prelude_test/ferryman.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 30.0
$body "body" "ferryman_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "metal"
$contents "solid"

$sequence Idle "ferryman_ref" loop fps 30

$collisionmodel "ferryman_ref.smd" {
    $concave
    $maxconvexpieces 16
}
