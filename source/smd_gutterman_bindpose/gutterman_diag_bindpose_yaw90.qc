$modelname "ultrakill_prelude_test/gutterman_diag_bindpose_yaw90.mdl"
$origin 0 0 0 90
$scale 2500.0
$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"
$body "body" "gutterman_bindpose_body.smd"
$sequence Ref "gutterman_bindpose_body" loop fps 1
$sequence IdleAbs "idle_abs" loop fps 30
$sequence WalkAbs "walk_abs" loop fps 30
