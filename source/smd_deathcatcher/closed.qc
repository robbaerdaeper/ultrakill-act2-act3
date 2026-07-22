$modelname "ultrakill_deathcatcher/closed.mdl"
$scale 4000
$body "body" "closed_ref.smd"
$cdmaterials "models/ultrakill_deathcatcher/"
$illumposition 0 0 12
$surfaceprop "concrete"
$contents "solid"
$staticprop
$origin 0 0 25
$sequence Idle "anims/idle" loop fps 30
// No $collisionmodel: nextbot uses ENT.CollisionBounds for hitbox. The .phy
// hull pushed the entity upward during SetModel swaps because closed/open
// had concave collision but animated.mdl had none.
