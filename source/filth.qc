// Filth — production QC (ULTRAKILL Unity → GMod via v11 coord-fix pipeline).

$modelname "ultrakill_prelude_test/filth.mdl"
$cdmaterials "models/ultrakill_prelude_test/filth/"
$surfaceprop "flesh"
$contents "solid"

$scale 27

// Hitboxes — adapted from prelude ($scale 1), divided by 27 to match our $scale.
// Groups: 1=HEAD, 2=CHEST, 3=STOMACH, 4=LEFTARM, 5=RIGHTARM, 6=LEFTLEG, 7=RIGHTLEG.
$hboxset "default"
$hbox 6 "Thigh_Left"     -0.142685 -0.166963 -0.139704  0.111593 0.870167 0.139704
$hbox 6 "Leg_Left"       -0.093704 -0.026407 -0.078370  0.088167 0.959611 0.206148
$hbox 6 "Foot_Left"      -0.071130 -0.065167 -0.088167  0.112444 0.335630 0.086889
$hbox 7 "Thigh_Right"    -0.116278 -0.166537 -0.139704  0.138000 0.870593 0.139704
$hbox 7 "Leg_Right"      -0.092426 -0.025981 -0.078370  0.089444 0.959611 0.206148
$hbox 7 "Foot_Right"     -0.112444 -0.064315 -0.083481  0.071130 0.336482 0.091574
$hbox 3 "Spine_01"       -0.185278 -0.115000 -0.161426  0.096685 0.370130 0.161426
$hbox 2 "Spine_02"       -0.251722 0.000000 -0.244907  0.157593 0.581389 0.266204
$hbox 4 "Clavicle_Left"  -0.106481 0.139704 -0.106481  0.106481 0.457019 0.106481
$hbox 5 "Clavicle_Right" -0.127778 0.139704 -0.106481  0.085185 0.457019 0.106481
$hbox 1 "Neck"           -0.091574 0.000000 -0.103926  0.129907 0.179741 0.099241
$hbox 1 "Head"           -0.193796 -0.023000 -0.169093  0.210833 0.360333 0.171648
$skipboneinbbox

$body "body" "smd_v11/Melee_Husk.smd"

$texturegroup "skinfamilies"
{
    { "zombie" }
    { "zombie_closed" }
}

$sequence "Idle" {
    "smd_v11/anims/Idle.smd"
    activity "ACT_IDLE" 1
    fadein 0.1
    fadeout 0.15
    fps 60
    loop
}

$sequence "Run" {
    "smd_v11/anims/Run.smd"
    activity "ACT_RUN" 1
    fadein 0.1
    fadeout 0.15
    fps 60
    loop
}

$sequence "Bite" {
    "smd_v11/anims/Bite.smd"
    activity "ACT_BITE" 1
    fadein 0
    fadeout 0.15
    fps 60
    walkframe 20 LX
    walkframe 21 LX
    walkframe 22 LX
    walkframe 23 LX
    walkframe 24 LX
    walkframe 25 LX
    walkframe 26 LX
    walkframe 27 LX
    walkframe 28 LX
    walkframe 29 LX
    walkframe 30 LX
    walkframe 31 LX
    walkframe 32 LX
    walkframe 33 LX
    walkframe 34 LX
    walkframe 35 LX
    walkframe 36 LX
}

$sequence "Falling" {
    "smd_v11/anims/Falling.smd"
    activity "ACT_FALLING" 1
    fadein 0.1
    fadeout 0.15
    fps 60
    loop
}

$sequence "JumpStart" {
    "smd_v11/anims/JumpStart.smd"
    fadein 0.1
    fadeout 0.15
    fps 60
}

$sequence "JumpEnd" {
    "smd_v11/anims/JumpEnd.smd"
    fadein 0.1
    fadeout 0.15
    fps 60
}

$sequence "Death" {
    "smd_v11/anims/ChestExplosion.smd"
    activity "ACT_DIESIMPLE" 1
    fadein 0.1
    fadeout 0.15
    fps 60
}

$collisionjoints "smd_v11/filth_physics.smd"
{
    $mass 0
    $inertia 10
    $damping 0.01
    $rotdamping 1.5
    $rootbone "Bone001"

    $jointconstrain "Spine_02" x limit -25 25 0
    $jointconstrain "Spine_02" y limit -48 48 0
    $jointconstrain "Spine_02" z limit -25 50 0

    $jointconstrain "Neck" x limit 0 0 0
    $jointconstrain "Neck" y limit 0 0 0
    $jointconstrain "Neck" z limit 0 0 0

    $jointconstrain "Clavicle_Left" x limit -95 84 0
    $jointconstrain "Clavicle_Left" y limit -30 30 0
    $jointconstrain "Clavicle_Left" z limit -86 26 0

    $jointconstrain "Clavicle_Right" x limit -79 95 0
    $jointconstrain "Clavicle_Right" y limit -39 39 0
    $jointconstrain "Clavicle_Right" z limit -93 23 0

    $jointconstrain "Head" x limit -25 25 0
    $jointconstrain "Head" y limit -20 20 0
    $jointconstrain "Head" z limit -13 30 0

    $jointconstrain "Leg_Right" x limit 0 0 0
    $jointconstrain "Leg_Right" y limit 0 0 0
    $jointconstrain "Leg_Right" z limit -12 126 0

    $jointconstrain "Foot_Right" x limit -25 6 0
    $jointconstrain "Foot_Right" y limit 0 0 0
    $jointconstrain "Foot_Right" z limit -15 35 0

    $jointconstrain "Leg_Left" x limit 0 0 0
    $jointconstrain "Leg_Left" y limit 0 0 0
    $jointconstrain "Leg_Left" z limit -8 126 0

    $jointconstrain "Foot_Left" x limit -19 19 0
    $jointconstrain "Foot_Left" y limit 0 0 0
    $jointconstrain "Foot_Left" z limit -15 35 0

    $jointcollide "Thigh_Left" "Thigh_Right"
    $jointcollide "Foot_Right" "Leg_Left"
    $jointcollide "Foot_Left" "Leg_Right"
    $jointcollide "Foot_Left" "Foot_Right"
    $jointcollide "Leg_Right" "Leg_Left"
    $jointcollide "Thigh_Right" "Thigh_Left"
}

$collisiontext
{
    animatedfriction
    {
        "animfrictionmin" "1.000000"
        "animfrictionmax" "400.000000"
        "animfrictiontimein" "0.500000"
        "animfrictiontimeout" "0.300000"
        "animfrictiontimehold" "0.000000"
    }
    editparams
    {
        "rootname" "Bone001"
        "totalmass" "90.000000"
        "jointmerge" "Bone001,Spine_01"
    }
}
