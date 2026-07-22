// V11 — r3 coord-fix verified. mesh-bone disconnect resolved.

$modelname "ultrakill_diag/filth_v11.mdl"
$cdmaterials "models/ultrakill_diag/filth_v11/"
$surfaceprop "flesh"
$contents "solid"

$scale 39.37

$body "body" "smd_v11/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle"      { "smd_v11/anims/Idle.smd"          activity "ACT_IDLE" 1 loop fps 30 }
$sequence "Run"       { "smd_v11/anims/Run.smd"           activity "ACT_RUN"  1 loop fps 30 }
$sequence "Bite"      { "smd_v11/anims/Bite.smd"                                   fps 30 }
$sequence "Falling"   { "smd_v11/anims/Falling.smd"                           loop fps 30 }
$sequence "JumpStart" { "smd_v11/anims/JumpStart.smd"                              fps 30 }
$sequence "JumpEnd"   { "smd_v11/anims/JumpEnd.smd"                                fps 30 }
$sequence "Death"     { "smd_v11/anims/ChestExplosion.smd" activity "ACT_DIESIMPLE" 1 fps 30 }
