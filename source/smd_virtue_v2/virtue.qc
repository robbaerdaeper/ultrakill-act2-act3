$modelname "ultrakill_prelude_test/virtue_v2.mdl"
$cdmaterials "models/ultrakill_test/virtue/"
$scale 25.0
$upaxis Y
$origin 0 0 0 0

// 3 материала: virtue_crown (крест/корона/цепи), virtue_sphere (оболочка-шар),
// virtue_core (ромб-ядро — отдельно, чтобы труп красил цепи белым, а ядро/сферу нет).
$body "virtue" "virtue_split_ref.smd"

$sequence "Idle" "virtue_split_ref.smd" loop fps 30

// Атачмент в центре сферы (SMD-центроид сферы = origin кости root) для нативного
// UltrakillBase CreateEnrage/DrawEnraged (иначе GetAttachment→nil-краш). Следует за
// реальным рендером модели → enrage-эффект всегда точно на шаре.
$attachment "enrage" "root" 0 0 0

$surfaceprop "metal"
$contents "monster"
