// DIAG: $nocull 1 + unique $modelname to bypass HLMV cache
// Tests hypothesis: is wireframe = backface culling?
// If solid in HLMV → faces are inverted, fix winding properly.
// If wireframe → it's not culling, look for depth-collapse / shader issue.

$modelname "ultrakill_diag/filth_culltest.mdl"
$cdmaterials "models/ultrakill_diag/filth_culltest/"
$surfaceprop "flesh"
$contents "solid"

$origin 33.347 -286.428 -50.439

$body "body" "smd_new/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle" { "smd_new/anims/Idle.smd" activity "ACT_IDLE" 1 loop fps 30 }
