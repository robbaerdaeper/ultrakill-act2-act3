$modelname "ultrakill_prelude_test/hookpoint.mdl"
$upaxis Y
$scale 40
$cdmaterials "models/ultrakill_prelude_test/hookpoint"

$bodygroup "body"
{
	studio "hp_body.smd"
}
$bodygroup "pyramid"
{
	blank
	studio "hp_pyramid.smd"
}

$texturegroup "skinfamilies"
{
	{ "hp_core_green" "hp_shell_green" "hp_pyr_blue" "hp_ring_metal" }
	{ "hp_core_blue"  "hp_shell_blue"  "hp_pyr_blue" "hp_ring_metal" }
	{ "hp_core_pink"  "hp_shell_blue"  "hp_pyr_pink" "hp_ring_marble" }
}

$surfaceprop "metal"
// explicit hull: the idle SMD is skeleton-only so studiomdl computes no bbox,
// and uk_whiplash derives its reel-stop distance from GetModelRadius().
// $bbox is given in SMD axes (Y up) — $upaxis Y rotates it into game space.
$bbox -81 -49 -81 81 49 81
$sequence "idle" "hp_idle.smd" fps 1
