// Stray — production QC (ULTRAKILL Unity → GMod via v11 coord-fix pipeline).
// Generated 2026-05-05.

$modelname "ultrakill_prelude_test/stray.mdl"
$cdmaterials "models/ultrakill_prelude_test/stray/"
$surfaceprop "flesh"
$contents "solid"

$scale 6.89

$illumposition 0 0 6.5312
$bbox -0.9572 -3.0180 -0.7247  1.6190 3.0316 13.8511

// Hboxes from prelude/stray.mdl decompile, divided by $scale=6.89 (critical: hboxes scale with $scale).
// 17 entries — matches prelude hbox count incl. duplicate Hand.R for projectile spawn area.
$hboxset "default"
$hbox 3 "Hips"   -1.066038 -1.196226 -0.745283  1.066038 1.488679 0.666038
$hbox 2 "Chest"  -1.394340 -0.356604 -0.711321  1.394340 2.124528 1.277358
$hbox 1 "Neck"   -0.471698 0.000000 -0.566038   0.471698 0.754717 0.566038
$hbox 1 "Head"   -0.660377 -0.232075 -0.779245  0.660377 1.277358 0.730189
$hbox 4 "ArmU.L" -0.433962 -0.471698 -0.415094  0.547170 2.169811 0.528302
$hbox 4 "ArmL.L" -0.354717 -0.339623 -0.567925  0.377358 2.445283 0.418868
$hbox 4 "Hand.L" -0.458491 -0.067925 -0.286792  0.484906 1.441509 0.279245
$hbox 5 "ArmU.R" -0.433962 -0.471698 -0.415094  0.547170 2.169811 0.528302
$hbox 5 "ArmL.R" -0.388679 -0.362264 -0.545283  0.366038 2.467925 0.398113
$hbox 5 "Hand.R" -0.443396 -0.030189 -0.249057  0.416981 1.403774 0.239623
$hbox 5 "Hand.R" -1.132075 -0.566038 -2.830189  1.132075 1.698113 -0.188679
$hbox 6 "LegU.L" -0.660377 -0.609434 -0.515094  1.037736 4.294339 0.522642
$hbox 6 "LegL.L" -0.709434 -0.530189 -0.464151  0.518868 3.279245 0.383019
$hbox 6 "Foot.L" -0.496226 -0.207547 -0.698113  0.303774 1.607547 0.318868
$hbox 7 "LegU.R" -1.037736 -0.609434 -0.515094  0.660377 4.294339 0.522642
$hbox 7 "LegL.R" -0.518868 -0.530189 -0.464151  0.709434 3.279245 0.383019
$hbox 7 "Foot.R" -0.303774 -0.207547 -0.698113  0.496226 1.607547 0.318868
$skipboneinbbox

$body "Body" "smd_stray/zombie.smd"

// Reference (rest pose for ragdoll) — using zombie.smd as fallback since no separate Reference.smd was produced.
// fps 30 + snap matches prelude's death-pose convention.
$sequence "Reference" {
    "smd_stray/zombie.smd"
    activity "ACT_DIERAGDOLL" 1
    fadein 0.2
    fadeout 0.2
    snap
    fps 30
    loop
}

$sequence "Idle"            { "smd_stray/anims/Idle.smd"            activity "ACT_IDLE"      1 fps 60 fadein 0.1 fadeout 0.15 loop }
$sequence "Walk"            { "smd_stray/anims/Walk.smd"            activity "ACT_WALK"      1 fps 60 fadein 0.1 fadeout 0.15 loop }
$sequence "Run"             { "smd_stray/anims/Run.smd"             activity "ACT_RUN"       1 fps 60 fadein 0.1 fadeout 0.15 loop }
$sequence "Falling"         { "smd_stray/anims/Falling.smd"         activity "ACT_FALLING"   1 fps 60 fadein 0.1 fadeout 0.15 loop }
$sequence "ThrowProjectile" { "smd_stray/anims/ThrowProjectile.smd" activity "ACT_SHOOT"     1 fps 60 fadein 0   fadeout 0.15 }
// ChestExplosion = glory-kill animation (point-blank shotgun to torso). Not auto-bound to a death activity —
// game plays this only conditionally, default kill is just ragdoll. Available as named sequence for future use.
$sequence "ChestExplosion" { "smd_stray/anims/ChestExplosion.smd" fps 60 fadein 0.1 fadeout 0.15 }

// Attachment 1 = Spine02 (AI-eye), attachment 2 = HandR (projectile spawn — Lua: GetAttachment(2)).
// Offsets divided by $scale 6.89 (attachments scale with $scale; verified in HLMV).
$attachment "Spine02_ATTACH" "Chest"  0 0.3774  0.3774  rotate 0 0 0
$attachment "HandR_ATTACH"   "Hand.R" 0 0       -0.5660 rotate 0 0 0

$collisionjoints "smd_stray/stray_physics.smd" {
    $mass 0
    $inertia 10
    $damping 0.01
    $rotdamping 1.5
    $rootbone " "

    $jointconstrain "Leg.R" x limit 0 0 0
    $jointconstrain "Leg.R" y limit 0 0 0
    $jointconstrain "Leg.R" z limit 0 0 0

    $jointconstrain "LegU.R" x limit -12 12 0
    $jointconstrain "LegU.R" y limit -8 75 0
    $jointconstrain "LegU.R" z limit -97 32 0

    $jointconstrain "LegL.R" x limit 0 0 0
    $jointconstrain "LegL.R" y limit 0 0 0
    $jointconstrain "LegL.R" z limit -12 126 0

    $jointconstrain "Leg.L" x limit 0 0 0
    $jointconstrain "Leg.L" y limit 0 0 0
    $jointconstrain "Leg.L" z limit 0 0 0

    $jointconstrain "LegU.L" x limit -12 12 0
    $jointconstrain "LegU.L" y limit -73 6 0
    $jointconstrain "LegU.L" z limit -93 30 0

    $jointconstrain "LegL.L" x limit 0 0 0
    $jointconstrain "LegL.L" y limit 0 0 0
    $jointconstrain "LegL.L" z limit -8 126 0

    $jointconstrain "Foot.L" x limit 0 0 0
    $jointconstrain "Foot.L" y limit -19 19 0
    $jointconstrain "Foot.L" z limit -15 35 0

    $jointconstrain "Chest" x limit -48 48 0
    $jointconstrain "Chest" y limit -25 25 0
    $jointconstrain "Chest" z limit -25 50 0

    $jointconstrain "ArmU.R" x limit -39 39 0
    $jointconstrain "ArmU.R" y limit -79 95 0
    $jointconstrain "ArmU.R" z limit -93 23 0

    $jointconstrain "ArmL.R" x limit 0 0 0
    $jointconstrain "ArmL.R" y limit 0 0 0
    $jointconstrain "ArmL.R" z limit -149 4 0

    $jointconstrain "ArmU.L" x limit -30 30 0
    $jointconstrain "ArmU.L" y limit -95 84 0
    $jointconstrain "ArmU.L" z limit -86 26 0

    $jointconstrain "ArmL.L" x limit 0 0 0
    $jointconstrain "ArmL.L" y limit 0 0 0
    $jointconstrain "ArmL.L" z limit -149 4 0

    $jointconstrain "Hand.L" x limit -37 37 0
    $jointconstrain "Hand.L" y limit 0 0 0
    $jointconstrain "Hand.L" z limit -57 59 0

    $jointconstrain "Neck" x limit -20 20 0
    $jointconstrain "Neck" y limit -25 25 0
    $jointconstrain "Neck" z limit -13 30 0

    $jointconstrain "Head" x limit 0 0 0
    $jointconstrain "Head" y limit 0 0 0
    $jointconstrain "Head" z limit 0 0 0

    $jointconstrain "Hand.R" x limit -37 37 0
    $jointconstrain "Hand.R" y limit 0 0 0
    $jointconstrain "Hand.R" z limit -57 59 0

    $jointconstrain "Foot.R" x limit 0 0 0
    $jointconstrain "Foot.R" y limit -25 6 0
    $jointconstrain "Foot.R" z limit -15 35 0

    $jointcollide "ArmL.R" "LegU.R"
    $jointcollide "ArmL.R" "LegU.L"
    $jointcollide "ArmL.L" "LegU.R"
    $jointcollide "ArmL.L" "LegU.L"
    $jointcollide "Foot.R" "LegL.L"
    $jointcollide "Foot.L" "LegL.R"
    $jointcollide "Foot.L" "Foot.R"
    $jointcollide "LegL.R" "LegL.L"
    $jointcollide "LegU.R" "LegU.L"
    $jointcollide "ArmL.R" "Chest"
    $jointcollide "ArmL.L" "Chest"
    $jointcollide "ArmL.R" "Hips"
    $jointcollide "ArmL.L" "Hips"
}

$collisiontext {
    animatedfriction {
        "animfrictionmin" "1.000000"
        "animfrictionmax" "400.000000"
        "animfrictiontimein" "0.500000"
        "animfrictiontimeout" "0.300000"
        "animfrictiontimehold" "0.000000"
    }
    editparams {
        "rootname" "Hips"
        "totalmass" "90.000000"
        "jointmerge" "Hips,Base"
    }
}
