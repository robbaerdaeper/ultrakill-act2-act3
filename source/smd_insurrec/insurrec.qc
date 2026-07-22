$modelname "ultrakill_prelude_test/insurrec.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 35.0
$body "body" "insurrec_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "flesh"
$contents "solid"

$sequence Idle "insurrec_ref" loop fps 30

$collisionmodel "insurrec_ref.smd" {
    $concave
    $maxconvexpieces 16
}
