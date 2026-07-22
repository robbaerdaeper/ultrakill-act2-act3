// Cancerous Rodent + Very Cancerous Rodent — shared MDL with skin family.
// Generated 2026-05-06.

$modelname "ultrakill_prelude_test/rodent.mdl"
$cdmaterials "models/ultrakill_prelude_test/rodent/"
$surfaceprop "flesh"
$contents "solid"

$scale 6.89   // same as Stray; recalibrate in T6 if scale wrong
              // axis swap is applied at SMD-generation time via cmd/obj2smd.py --axis-swap unity_to_source

$origin 0 0 -10.33   // mesh is centered on Z; lower origin so geometry sits above floor

$body "Body" "smd_rodent/zombie.smd"

$sequence "Idle" {
    "smd_rodent/zombie.smd"
    activity "ACT_IDLE" 1
    fps 30
    loop
}

$texturegroup "skinfamilies"
{
    { "rodent_body_flat"  }
    { "rodent_body_skull" }
}

$collisionmodel "smd_rodent/zombie.smd" {
    $mass 5
    $concave
    $automass
    $maxconvexpieces 2
}
