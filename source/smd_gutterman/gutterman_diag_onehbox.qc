$modelname "ultrakill_prelude_test/diag/gutterman_onehbox.mdl"
$upaxis Y
$scale 6000.0

$bodygroup "body"
{
    studio "gutterman_body.smd"
    studio "gutterman_casketless_body.smd"
}

$bodygroup "shield"
{
    studio "gutterman_shield.smd"
    blank
}

$bodygroup "casket_door"
{
    studio "gutterman_casket_door.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"

// Explicit hitboxes = studiomdl auto-set minus "Shield 1": the physical shield
// is a separate helper entity (zero damage); a body hitbox there would leak
// owner damage and leave a phantom hit zone after the shield breaks.
$hboxset "default"
$hbox 0 "Spine_02" -58.55 -32.45 -44.86 36.99 82.55 60.68

$sequence Idle            "idle"            loop fps 30
$sequence Walk            "walk"            loop fps 40.5
$sequence IdleShieldless  "idleshieldless"  loop fps 30
$sequence WalkShieldless  "walkshieldless"  loop fps 30
$sequence ShieldBreak     "shieldbreak"          fps 30
$sequence ShieldBash      "shieldbash"           fps 45
$sequence Smack           "smack"                fps 37.5
$sequence Death           "death"                fps 19.5
$sequence Shoot           "shoot"           loop fps 60

// Canon Shoot Layer combos: full-body locomotion + right-arm minigun fire
// (GuttermanMask drives Shoulder_R..Barrels only; merged at bake time).
// NOTE: the 3-way aim_pitch blend variant of these sequences made the model
// invisible in game (degenerate sequence bbox?) — reverted to plain sequences.
$sequence ShootIdle            "shootidle"            loop fps 30
$sequence ShootWalk            "shootwalk"            loop fps 40.5
$sequence ShootIdleShieldless  "shootidleshieldless"  loop fps 30
$sequence ShootWalkShieldless  "shootwalkshieldless"  loop fps 30

$collisionmodel "gutterman_collision.smd"
{
    $mass 500
}
