$modelname "ultrakill_prelude_test/panopticon.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 30.0
$body "body" "panopticon_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "flesh"
$contents "solid"

$sequence Idle "panopticon_ref" loop fps 30

$collisionmodel "panopticon_ref.smd" {
    $concave
    $maxconvexpieces 24
}
