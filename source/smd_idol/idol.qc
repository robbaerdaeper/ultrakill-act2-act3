$modelname "ultrakill_idol/idol.mdl"
$scale 18.0
$body "body" "idol_ref.smd"
$cdmaterials "models/ultrakill_idol/"
$staticprop
$surfaceprop "concrete"
$contents "solid"
$sequence Idle "anims/idle" loop fps 30
$collisionmodel "idol_ref.smd" {
  $concave
  $maxconvexpieces 256
}
