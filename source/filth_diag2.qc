// Diagnostic 2: use PRELUDE Melee_Husk.smd (known good) — to test if HLMV setup works at all

$modelname "ultrakill_prelude_test/filth_diag2.mdl"
$cdmaterials "models/ultrakill_prelude_test/filth/"
$surfaceprop "flesh"

$body "body" "smd/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle" "smd/anims/Idle.smd" fps 30
