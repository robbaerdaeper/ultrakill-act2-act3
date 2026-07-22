// Filth model — first compile from ULTRAKILL FBX (path A: kxn4t pose-to-rest + retargeted FBX actions)
// Skeleton: 16 bones (Armature.001, Bone001, Hip/Thigh/Leg/Foot Left+Right, Spine_01/02, Clavicle_Left/Right, Neck, Head)
// Animations: 7 actions extracted from Mecanim AnimatorController via AssetStudioModCLI

$modelname "ultrakill_prelude_test/filth.mdl"
$cdmaterials "models/ultrakill_prelude_test/filth/"
$surfaceprop "flesh"
$contents "solid"

$origin 33.347 -286.428 -50.439

$body "body" "smd_new/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle"      { "smd_new/anims/Idle.smd"          activity "ACT_IDLE" 1 loop fps 30 }
$sequence "Run"       { "smd_new/anims/Run.smd"           activity "ACT_RUN"  1 loop fps 30 }
$sequence "Bite"      { "smd_new/anims/Bite.smd"                                   fps 30 }
$sequence "Falling"   { "smd_new/anims/Falling.smd"                           loop fps 30 }
$sequence "JumpStart" { "smd_new/anims/JumpStart.smd"                              fps 30 }
$sequence "JumpEnd"   { "smd_new/anims/JumpEnd.smd"                                fps 30 }
$sequence "Death"     { "smd_new/anims/ChestExplosion.smd" activity "ACT_DIESIMPLE" 1 fps 30 }

$collisionjoints "smd_new/filth_physics.smd"
{
    $mass 60
    $concave
    $jointmassbias "Bone001"   2
    $jointmassbias "Spine_01"  1.4
    $jointmassbias "Head"      1.5
}
