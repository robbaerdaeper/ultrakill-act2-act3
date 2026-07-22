// V9: minimal — just import from FBX, apply armature mod for reference, export
// 21 bones (kept _End), mesh in Idle pose

$modelname "ultrakill_diag/filth_v9.mdl"
$cdmaterials "models/ultrakill_prelude_test/filth/"
$surfaceprop "flesh"

$body "body" "smd_v9/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle" { "smd_v9/anims/Idle.smd" activity "ACT_IDLE" 1 loop fps 30 }
