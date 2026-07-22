$modelname "ultrakill_deathcatcher/heart.mdl"
$scale 4000
$body "body" "heart_ref.smd"
$cdmaterials "models/ultrakill_deathcatcher/"
$illumposition 0 0 12
$surfaceprop "flesh"
$contents "solid"
$staticprop
$origin 0 0 25
$sequence Idle "anims/idle" loop fps 30
$collisionmodel "heart_ref.smd" {
  $concave
}
