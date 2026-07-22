// DIAG: pod-style minimal QC — single Idle sequence referencing the MESH smd,
// no bodygroups, no hitboxes, no collision model. If THIS is broken too, the
// problem is in the mesh/skeleton data, not the QC features.
$modelname "ultrakill_prelude_test/diag/gutterman_minimal.mdl"
$upaxis Y
$scale 6000.0

$body "body" "gutterman_body.smd"

$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"

$sequence Idle "gutterman_body" fps 1
