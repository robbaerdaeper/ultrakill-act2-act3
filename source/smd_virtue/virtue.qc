$modelname "ultrakill_prelude_test/virtue.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 25.0
$body "body" "virtue_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "metal_box"
$contents "solid"

$sequence Idle "virtue_ref" loop fps 30

$collisionmodel "virtue_ref.smd" {
    $concave
    $maxconvexpieces 24
}
