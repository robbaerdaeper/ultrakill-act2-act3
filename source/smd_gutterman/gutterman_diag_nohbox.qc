// DIAG: current gutterman.qc minus the explicit $hboxset block.
// If hull/seq bboxes come out sane -> the explicit hitbox set kills
// studiomdl's auto bbox computation.
$modelname "ultrakill_prelude_test/diag/gutterman_nohbox.mdl"
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

$sequence Idle            "idle"            loop fps 30
$sequence Walk            "walk"            loop fps 40.5
$sequence IdleShieldless  "idleshieldless"  loop fps 30
$sequence WalkShieldless  "walkshieldless"  loop fps 30
$sequence ShieldBreak     "shieldbreak"          fps 30
$sequence ShieldBash      "shieldbash"           fps 45
$sequence Smack           "smack"                fps 37.5
$sequence Death           "death"                fps 19.5
$sequence Shoot           "shoot"           loop fps 60

$sequence ShootIdle            "shootidle"            loop fps 30
$sequence ShootWalk            "shootwalk"            loop fps 40.5
$sequence ShootIdleShieldless  "shootidleshieldless"  loop fps 30
$sequence ShootWalkShieldless  "shootwalkshieldless"  loop fps 30

$collisionmodel "gutterman_collision.smd"
{
    $mass 500
}
