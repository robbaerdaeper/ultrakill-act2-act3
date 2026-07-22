$modelname "ultrakill_prelude_test/guttertank.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 25.0
$body "body" "guttertank_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "metal_bouncy"
$contents "solid"

$sequence Idle "guttertank_ref" loop fps 30

$collisionmodel "guttertank_ref.smd" {
    $concave
    $maxconvexpieces 24
}
