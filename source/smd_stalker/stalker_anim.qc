$modelname "ultrakill_prelude_test/stalker.mdl"
$upaxis Y
$origin 0 0 0 90
$scale 40.0
$body "body" "stalker_rigged_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "metal_box"
$contents "solid"

$sequence Idle    "idle"    loop fps 30
$sequence Walking "walking" loop fps 30
$sequence Running "running" loop fps 30
$sequence Falling "falling" loop fps 30
$sequence Explode "explode"      fps 30

$collisionmodel "stalker_rigged_ref.smd" {
    $concave
    $maxconvexpieces 24
}
