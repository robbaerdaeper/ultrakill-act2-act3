// V6 — R2 research: SMD in Unity meters, $scale 39.37 in QC
// Unity 1m = 39.3701 inches (Source units)
// Bone↔vertex consistent in SMD; $scale applies to skeleton+mesh+anims together at compile.

$modelname "ultrakill_diag/filth_v6b.mdl"
$cdmaterials "models/ultrakill_prelude_test/filth/"
$surfaceprop "flesh"
$contents "solid"

$scale 5.6

$body "body" "smd_v6/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle"      { "smd_v6/anims/Idle.smd"          activity "ACT_IDLE" 1 loop fps 30 }
$sequence "Run"       { "smd_v6/anims/Run.smd"           activity "ACT_RUN"  1 loop fps 30 }
$sequence "Bite"      { "smd_v6/anims/Bite.smd"                                   fps 30 }
$sequence "Falling"   { "smd_v6/anims/Falling.smd"                           loop fps 30 }
$sequence "JumpStart" { "smd_v6/anims/JumpStart.smd"                              fps 30 }
$sequence "JumpEnd"   { "smd_v6/anims/JumpEnd.smd"                                fps 30 }
$sequence "Death"     { "smd_v6/anims/ChestExplosion.smd" activity "ACT_DIESIMPLE" 1 fps 30 }
