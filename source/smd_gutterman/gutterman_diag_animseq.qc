// DIAG: minimal + ONE anim-SMD sequence (idle). Isolates "sequences from
// animation-only SMDs" as the bbox killer vs the minimal mesh-SMD variant.
$modelname "ultrakill_prelude_test/diag/gutterman_animseq.mdl"
$upaxis Y
$scale 6000.0

$body "body" "gutterman_body.smd"

$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"

$sequence Idle "idle" loop fps 30
