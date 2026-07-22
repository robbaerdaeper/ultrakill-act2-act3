$modelname "ultrakill_prelude_test/stalker.mdl"
$scale 40.0
$body "body"        "stalker_body.smd"
$body "can"         "stalker_can.smd"
$body "can_glass"   "stalker_can_glass.smd"
$body "sand"        "stalker_sand.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "metal_box"
$contents "solid"

$sequence Idle    "idle" loop fps 30
$sequence Walking "idle" loop fps 30
$sequence Running "idle" loop fps 30
$sequence Falling "idle" loop fps 30
$sequence Explode "idle" loop fps 30

$collisionmodel "stalker_body.smd" {
    $concave
    $maxconvexpieces 24
}
