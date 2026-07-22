$modelname "ultrakill_prelude_test/virtue_insignia.mdl"
$cdmaterials "models/ultrakill_test/virtue/"
$scale 25.0
$upaxis Y
$origin 0 0 0 90

$bodygroup "warning"
{
    studio "virtue_insignia_ref.smd"
    blank
}

// Preserve critical bones
$definebone "Virtue_Insignia" "" 0 0 0 0 0 0 0 0 0 0 0 0
$definebone "WarningCapsule" "Virtue_Insignia" 0 0 0 0 0 0 0 0 0 0 0 0
$definebone "Capsule" "Virtue_Insignia" 0 0 0 0 0 0 0 0 0 0 0 0

$sequence "Idle" "virtue_insignia_idle.smd" loop fps 30

$surfaceprop "metal"
