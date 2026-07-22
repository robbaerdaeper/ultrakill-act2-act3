// V7: built from stage_after_apply_arm.blend (mesh in Idle pose, valid 674 polys, 336 clusters)
// + native Apply Pose as Rest + bake actions + delete _End + recalc normals
// No centering, no scaling in Blender. $scale here for Source-inch sizing.

$modelname "ultrakill_diag/filth_v7.mdl"
$cdmaterials "models/ultrakill_prelude_test/filth/"
$surfaceprop "flesh"
$contents "solid"

$scale 1.0

$body "body" "smd_v7/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle"      { "smd_v7/anims/Idle.smd"          activity "ACT_IDLE" 1 loop fps 30 }
$sequence "Run"       { "smd_v7/anims/Run.smd"           activity "ACT_RUN"  1 loop fps 30 }
$sequence "Bite"      { "smd_v7/anims/Bite.smd"                                   fps 30 }
$sequence "Falling"   { "smd_v7/anims/Falling.smd"                           loop fps 30 }
$sequence "JumpStart" { "smd_v7/anims/JumpStart.smd"                              fps 30 }
$sequence "JumpEnd"   { "smd_v7/anims/JumpEnd.smd"                                fps 30 }
$sequence "Death"     { "smd_v7/anims/ChestExplosion.smd" activity "ACT_DIESIMPLE" 1 fps 30 }
