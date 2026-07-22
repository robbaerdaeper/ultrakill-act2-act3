// 1000-THR "Earthmover" (Centaur) — гигантский walker из 7-4.
// Канон: mesh-юниты x50 = метры; высота ~835 м. База компиляции 1:8 канона:
// $scale = 50*40/8 = 250 -> высота модели ~4175 su (~106 м). Полный канон
// достижим через Lua SetModelScale (см. entity), 1:1 в движке нереален.
$modelname "ultrakill_prelude_test/earthmover_giant.mdl"
$upaxis Y
$scale 250.0

$body "body" "giant_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/earthmover/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0

$attachment "head" "Spine_02" 0 0 0
$attachment "body" "Body" 0 0 0

$hboxset "default"
// туловище (bbox тела в юнитах меша, ~ y 6..10, x +-2.5)
$hbox 0 "Body" -2.6 -2.0 -3.5 2.5 4.0 5.7
// шея/голова
$hbox 1 "Spine_02" -1.0 -1.0 -1.0 1.0 5.0 1.0
$hbox 0 "Shoulder_FrontLeft" -1.0 -6.0 -1.0 1.0 1.0 1.0
$hbox 0 "Shoulder_FrontRight" -1.0 -6.0 -1.0 1.0 1.0 1.0
$hbox 0 "Shoulder_BackLeft" -1.0 -6.0 -1.0 1.0 1.0 1.0
$hbox 0 "Shoulder_BackRight" -1.0 -6.0 -1.0 1.0 1.0 1.0

$sequence idle "giant_ref" loop fps 30
$sequence walk "giant_walk" loop fps 30

$collisionmodel "giant_phys.smd" {
}
