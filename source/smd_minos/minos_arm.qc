// The Corpse of King Minos' Arm — canon 2-4 first-encounter miniboss, 1:1.
// Scene: enemy root scale 250 => 1 model unit = 250 m... => $scale = 250*40.
// Pivot raised 19/250 units so the canon floor lands at z=0.
$modelname "ultrakill_prelude_test/minos_arm.mdl"
$upaxis Y
$scale 10000.0

$body "body" "arm_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/minos/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

// canon: weakPoint = Hand, overrideCenter = Middle_001.
// "hand" LAST: ukcoin ricochets target the last attachment (canon weakpoint).
$attachment "center" "Middle_001" 0 0 0
$attachment "hand"   "Hand" 0 0 0

$hboxset "default"
// canon capsules (UpperArm h.3 r.035, ForeArms h.15, Hand box .085x.15x.025)
$hbox 0 "UpperArm" -0.035 -0.025 -0.035 0.035 0.295 0.035
$hbox 0 "ForeArm_001" -0.035 -0.0125 -0.035 0.035 0.1375 0.035
$hbox 0 "ForeArm_002" -0.035 -0.0125 -0.035 0.035 0.1375 0.035
$hbox 1 "Hand" -0.0625 -0.04 -0.045 0.0225 0.11 0.055

$sequence Idle      "arm_idle" loop fps 30
$sequence Intro     "arm_intro" fps 30
$sequence SlamDown  "arm_slamdown" fps 30
$sequence SlamLeft  "arm_slamleft" fps 30
$sequence SlamRight "arm_slamright" fps 30
$sequence Flinch    "arm_flinch" fps 30
$sequence Retreat   "arm_retreat" fps 30

$collisionmodel "arm_phys.smd" {
}
