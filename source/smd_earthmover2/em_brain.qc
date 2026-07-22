// Earthmover Brain (CentaurBrain) — босс 7-4, канон 1:1.
// Model node CentaurBrain scale 35 => $scale 35*40 = 1400.
// Спинной шнур Bone006..010 — jiggle (канон: KoboldKare jiggle physics).
$modelname "ultrakill_prelude_test/em_brain.mdl"
$upaxis Y
$scale 1400.0

$body "body" "brain_ref.smd"
$bodygroup "glass"
{
    studio "brain_glass.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/earthmover/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

$attachment "center" "CentaurBrain" 0 0.05 0.1

$hboxset "default"
$hbox 0 "CentaurBrain" -0.27 -0.25 -0.2 0.29 0.3 0.44

$jigglebone "Bone006" { is_flexible { length 20 tip_mass 40 pitch_stiffness 50 pitch_damping 6 yaw_stiffness 50 yaw_damping 6 along_stiffness 100 along_damping 0 angle_constraint 20 } }
$jigglebone "Bone008" { is_flexible { length 20 tip_mass 40 pitch_stiffness 40 pitch_damping 5 yaw_stiffness 40 yaw_damping 5 along_stiffness 100 along_damping 0 angle_constraint 25 } }
$jigglebone "Bone010" { is_flexible { length 20 tip_mass 30 pitch_stiffness 30 pitch_damping 4 yaw_stiffness 30 yaw_damping 4 along_stiffness 100 along_damping 0 angle_constraint 30 } }

$sequence idle "brain_ref" loop fps 30

$collisionmodel "brain_phys.smd" {
}
