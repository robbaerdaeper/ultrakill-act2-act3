$modelname "ultrakill_prelude_test/gutterman_diag_pose_ref.mdl"
$scale 2500.0
$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"
$body "body" "gutterman_pose_ref.smd"
$sequence PoseRef "gutterman_pose_ref.smd" loop fps 1
$sequence IdleAbs "idle" loop fps 30
$sequence WalkAbs "walk" loop fps 30
