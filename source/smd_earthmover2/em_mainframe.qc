// Earthmover Defense System — Mainframe (сцена 7-4, статик-бейк).
// Юниты сцены = метры => $scale 40 (канон 1:1, ~13.5 м).
// Origin у основания (offset +5.625); глаз на y=12.5 (engine z=500). Щит — bodygroup.
$modelname "ultrakill_prelude_test/em_mainframe.mdl"
$upaxis Y
$scale 40.0

$body "body" "mainframe_ref.smd"
$bodygroup "shield"
{
    studio "mainframe_shield.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/earthmover/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0

$attachment "eye" "static_root" 0 12.5 0

$hboxset "default"
$hbox 0 "static_root" -3.75 0.0 -1.44 3.75 13.5 1.44

$sequence idle "mainframe_ref" loop fps 30

$collisionmodel "mainframe_phys.smd" {
}
