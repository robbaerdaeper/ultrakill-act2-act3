// Diagnostic compile — no $origin, no $sequence — minimal model to verify mesh visibility

$modelname "ultrakill_prelude_test/filth_diag.mdl"
$cdmaterials "models/ultrakill_prelude_test/filth/"
$surfaceprop "flesh"
$contents "solid"

$body "body" "smd_new/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle" "smd_new/anims/Idle.smd" fps 30

// Force big bbox so HLMV definitely shows it
$bbox -200 -400 -100 200 100 100
