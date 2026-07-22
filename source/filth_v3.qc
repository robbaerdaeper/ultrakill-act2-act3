// V3: mesh centered at (0,0,0) in Blender, no $origin needed
// Re-exported smd_v2/ from filth_v3.blend (centered scene)

$modelname "ultrakill_diag/filth_v3.mdl"
$cdmaterials "models/ultrakill_diag/filth_culltest/"
$surfaceprop "flesh"
$contents "solid"

$body "body" "smd_v2/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle"      { "smd_v2/anims/Idle.smd"          activity "ACT_IDLE" 1 loop fps 30 }
$sequence "Run"       { "smd_v2/anims/Run.smd"           activity "ACT_RUN"  1 loop fps 30 }
$sequence "Bite"      { "smd_v2/anims/Bite.smd"                                   fps 30 }
$sequence "Falling"   { "smd_v2/anims/Falling.smd"                           loop fps 30 }
$sequence "JumpStart" { "smd_v2/anims/JumpStart.smd"                              fps 30 }
$sequence "JumpEnd"   { "smd_v2/anims/JumpEnd.smd"                                fps 30 }
$sequence "Death"     { "smd_v2/anims/ChestExplosion.smd" activity "ACT_DIESIMPLE" 1 fps 30 }
