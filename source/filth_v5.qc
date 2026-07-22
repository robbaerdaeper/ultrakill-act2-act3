// V5: clean rebuild from FBX with mesh keep-only filter
// bbox: 19.6 x 108.7 x 83.0 (centered at origin, feet at Z=0)
// $nocull 1 in materials, no $origin

$modelname "ultrakill_diag/filth_v5.mdl"
$cdmaterials "models/ultrakill_diag/filth_culltest/"
$surfaceprop "flesh"
$contents "solid"

$body "body" "smd_v5/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle"      { "smd_v5/anims/Idle.smd"          activity "ACT_IDLE" 1 loop fps 30 }
$sequence "Run"       { "smd_v5/anims/Run.smd"           activity "ACT_RUN"  1 loop fps 30 }
$sequence "Bite"      { "smd_v5/anims/Bite.smd"                                   fps 30 }
$sequence "Falling"   { "smd_v5/anims/Falling.smd"                           loop fps 30 }
$sequence "JumpStart" { "smd_v5/anims/JumpStart.smd"                              fps 30 }
$sequence "JumpEnd"   { "smd_v5/anims/JumpEnd.smd"                                fps 30 }
$sequence "Death"     { "smd_v5/anims/ChestExplosion.smd" activity "ACT_DIESIMPLE" 1 fps 30 }
