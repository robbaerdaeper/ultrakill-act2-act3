$modelname "ultrakill_prelude_test/gutterman_pod.mdl"
$upaxis Y
$scale 6000.0

// Canon BombPod_4 (7-2 AutoDropper payload): pod body + bomb shell top + door.
$bodygroup "body"
{
    studio "gutterman_pod_body.smd"
    blank
}

$bodygroup "bomb"
{
    studio "gutterman_pod_bomb.smd"
    blank
}

$bodygroup "door"
{
    studio "gutterman_pod_door.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal"
$contents "solid"

$sequence Idle "gutterman_pod_body" fps 1

$collisionmodel "gutterman_pod_body.smd"
{
    $mass 3000
}
