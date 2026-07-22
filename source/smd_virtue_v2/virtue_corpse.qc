// Модель ТРУПА Virtue — ТОЛЬКО сфера + ядро-ромб. Геометрии цепей/короны/креста здесь
// НЕТ вообще (virtue_crown-треугольники выброшены) → белых цепей на трупе быть не может
// физически, без всяких материал-трюков.
$modelname "ultrakill_prelude_test/virtue_corpse.mdl"
$cdmaterials "models/ultrakill_test/virtue/"
$scale 25.0
$upaxis Y
$origin 0 0 0 0

$body "corpse" "virtue_corpse_ref.smd"
$sequence "Idle" "virtue_corpse_ref.smd" loop fps 30

$surfaceprop "metal"
$contents "monster"
